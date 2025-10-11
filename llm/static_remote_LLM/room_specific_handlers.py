import pandas as pd
import numpy as np
import logging
import re
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from advanced_llm_handlers import AdvancedLLMHandlers, MaintenanceAlert, AnomalyDetection, EnergyInsight

logger = logging.getLogger(__name__)

class RoomSpecificHandlers:
    """
    Handles room-specific queries and analysis with fuzzy matching
    """
    
    def __init__(self, prompts_config, db_adapter):
        self.prompts = prompts_config
        self.db_adapter = db_adapter
        self.advanced_handlers = AdvancedLLMHandlers(prompts_config, self.db_adapter)
        self._available_rooms_cache = None
        self._room_mappings_cache = None
    
    def get_available_rooms(self, refresh: bool = False) -> List[Dict[str, Any]]:
        """Get list of all available rooms with caching"""
        if self._available_rooms_cache is None or refresh:
            try:
                self._available_rooms_cache = self.db_adapter.get_rooms_list()
                # Build room mappings for fuzzy matching
                self._build_room_mappings()
            except Exception as e:
                logger.error(f"Error getting rooms list: {e}")
                self._available_rooms_cache = []
        return self._available_rooms_cache
    
    def _build_room_mappings(self):
        """Build various mappings for room name matching"""
        if not self._available_rooms_cache:
            return
            
        self._room_mappings_cache = {
            'exact_names': [],
            'lower_names': [],
            'normalized_names': [],
            'aliases': {}
        }
        
        for room in self._available_rooms_cache:
            room_name = room.get('name', '')
            self._room_mappings_cache['exact_names'].append(room_name)
            self._room_mappings_cache['lower_names'].append(room_name.lower())
            
            # Normalized name (remove spaces, special chars)
            normalized = re.sub(r'[^a-z0-9]', '', room_name.lower())
            self._room_mappings_cache['normalized_names'].append(normalized)
            
            # Common aliases
            if room_name.lower().startswith('room'):
                room_num = room_name.lower().replace('room', '').strip()
                if room_num.isdigit():
                    self._room_mappings_cache['aliases'][room_num] = room_name
                    self._room_mappings_cache['aliases'][f"r{room_num}"] = room_name
    
    def fuzzy_match_room(self, query_room: str) -> Optional[str]:
        """Fuzzy match room name from query to available rooms using fuzzywuzzy"""
        if not query_room or not self._room_mappings_cache:
            return None
        
        query_lower = query_room.lower().strip()
        query_normalized = re.sub(r'[^a-z0-9]', '', query_lower)
        
        # 1. Exact match (case-insensitive)
        if query_lower in self._room_mappings_cache['lower_names']:
            idx = self._room_mappings_cache['lower_names'].index(query_lower)
            return self._room_mappings_cache['exact_names'][idx]
        
        # 2. Check aliases
        if query_lower in self._room_mappings_cache['aliases']:
            return self._room_mappings_cache['aliases'][query_lower]
        
        # 3. Normalized match
        if query_normalized in self._room_mappings_cache['normalized_names']:
            idx = self._room_mappings_cache['normalized_names'].index(query_normalized)
            return self._room_mappings_cache['exact_names'][idx]
        
        # 4. Partial matches
        for room_name in self._room_mappings_cache['exact_names']:
            room_lower = room_name.lower()
            # Check if query contains room name or vice versa
            if (query_lower in room_lower or room_lower in query_lower) and len(room_lower) > 2:
                return room_name
        
        # 5. Use fuzzywuzzy for advanced fuzzy matching
        try:
            from fuzzywuzzy import process, fuzz
            
            matches = process.extract(
                query_lower, 
                self._room_mappings_cache['lower_names'], 
                limit=3, 
                scorer=fuzz.partial_ratio
            )
            
            for match, score in matches:
                if score > 70:  # Reasonable confidence threshold
                    idx = self._room_mappings_cache['lower_names'].index(match)
                    return self._room_mappings_cache['exact_names'][idx]
                    
        except ImportError:
            logger.warning("fuzzywuzzy not available, using fallback matching")
            # Fallback to simple string similarity
            best_match = None
            best_score = 0
            
            for room_name in self._room_mappings_cache['exact_names']:
                room_lower = room_name.lower()
                score = self._calculate_similarity_score(query_lower, room_lower)
                
                if score > best_score and score > 0.6:
                    best_score = score
                    best_match = room_name
            
            if best_match:
                return best_match
        
        return None
    
    def _calculate_similarity_score(self, s1: str, s2: str) -> float:
        """Calculate similarity score between two strings (0-1)"""
        if not s1 or not s2:
            return 0.0
        
        # Simple Jaccard similarity on word sets
        words1 = set(s1.split())
        words2 = set(s2.split())
        
        if not words1 or not words2:
            return 0.0
        
        intersection = words1.intersection(words2)
        union = words1.union(words2)
        
        return len(intersection) / len(union) if union else 0.0
    
    def parse_room_query(self, query: str) -> Optional[str]:
        """Extract room name from query with fuzzy matching"""
        query_lower = query.lower()
        
        # First, try to extract room name using patterns
        room_patterns = [
            r'room\s+([a-z0-9]+)',  # Room 1, Room A, Room 101
            r'([a-z0-9]+)\s+room',  # 1 Room, A Room
            r'in\s+([a-z0-9\s]+?)(?:\s+room|$)',  # in room 1, in conference room
            r'for\s+([a-z0-9\s]+?)(?:\s+room|$)',  # for room 1, for meeting room
            r'([a-z0-9]+)(?:\'s|\s+)(?:data|status|energy)',  # room1's data, room 2 status
            r'r([0-9]+)',  # r1, r2, r101
            r'room\s+([a-z0-9]+)\'s',  # room 1's temperature
        ]
        
        potential_rooms = []
        
        for pattern in room_patterns:
            matches = re.findall(pattern, query_lower)
            for match in matches:
                if match.strip():  # Skip empty matches
                    potential_rooms.append(match.strip())
        
        # Also look for any words that might be room names
        words = query_lower.split()
        for word in words:
            if len(word) > 2 and word not in ['the', 'and', 'for', 'what', 'how', 'about', 'status', 'data', 'energy']:
                potential_rooms.append(word)
        
        # Try to match each potential room name
        for room_candidate in potential_rooms:
            matched_room = self.fuzzy_match_room(room_candidate)
            if matched_room:
                return matched_room
        
        # If no pattern match, try to match the entire query as a room name
        return self.fuzzy_match_room(query_lower)
    
    def get_room_data(self, room_name: str, limit: int = None) -> pd.DataFrame:
        """Get sensor data for a specific room with better matching"""
        try:
            # First ensure we have room mappings
            self.get_available_rooms()
            
            # Get all data first
            df = self.db_adapter.get_sensor_data_as_dataframe(limit=limit)
            
            if df is None or df.empty:
                logger.warning(f"No sensor data available")
                return pd.DataFrame()
            
            # Check if we have a room_name column
            if 'room_name' not in df.columns:
                logger.warning("No room_name column found in data")
                return pd.DataFrame()
            
            # Try exact match first (case-insensitive)
            room_df = df[df['room_name'].str.lower() == room_name.lower()]
            
            if room_df.empty:
                # Try partial matching within the data
                room_names_in_data = df['room_name'].unique()
                
                # Use fuzzy matching to find the best match in the actual data
                best_match = None
                best_score = 0
                
                for data_room_name in room_names_in_data:
                    if pd.isna(data_room_name):
                        continue
                    try:
                        from fuzzywuzzy import fuzz
                        score = fuzz.partial_ratio(room_name.lower(), str(data_room_name).lower())
                        if score > best_score:
                            best_score = score
                            best_match = data_room_name
                    except ImportError:
                        similarity = self._calculate_similarity_score(room_name.lower(), str(data_room_name).lower())
                        if similarity > best_score:
                            best_score = similarity
                            best_match = data_room_name
                
                if best_match and best_score > 60:
                    room_df = df[df['room_name'] == best_match]
                    logger.info(f"Fuzzy matched '{room_name}' to '{best_match}' in sensor data")
            
            # If still empty, try to see if there are any room-like patterns
            if room_df.empty:
                for data_room_name in df['room_name'].unique():
                    if pd.isna(data_room_name):
                        continue
                        
                    data_room_lower = str(data_room_name).lower()
                    # Check if both contain "room" or other common patterns
                    if ('room' in room_name.lower() and 'room' in data_room_lower) or \
                       ('conference' in room_name.lower() and 'conference' in data_room_lower) or \
                       ('server' in room_name.lower() and 'server' in data_room_lower):
                        room_df = df[df['room_name'] == data_room_name]
                        if not room_df.empty:
                            logger.info(f"Pattern matched '{room_name}' to '{data_room_name}'")
                            break
            
            logger.info(f"Found {len(room_df)} records for room '{room_name}'")
            return room_df
            
        except Exception as e:
            logger.error(f"Error getting room data for '{room_name}': {e}")
            return pd.DataFrame()
    
    def handle_maintenance_analysis(self) -> Dict[str, Any]:
        """Analyze maintenance requests from core_maintenancerequest and provide recommendations"""
        try:
            # Query maintenance requests from the database
            query = """
            SELECT id, issue, status
            FROM core_maintenancerequest
            ORDER BY status, issue
            """
            df = pd.read_sql_query(query, self.db_adapter.connection)
            
            if df is None or df.empty:
                logger.warning("No maintenance requests found")
                return {
                    "analysis_type": "maintenance_analysis",
                    "timestamp": datetime.utcnow().isoformat(),
                    "answer": "No maintenance requests found in the database.",
                    "maintenance_issues": [],
                    "recommendations": []
                }
            
            # Analyze pending and resolved issues
            pending = df[df['status'] == 'pending']
            resolved = df[df['status'] == 'resolved']
            
            pending_counts = pending['issue'].value_counts().to_dict()
            resolved_counts = resolved['issue'].value_counts().to_dict()
            
            # Generate response structure
            response = {
                "analysis_type": "maintenance_analysis",
                "timestamp": datetime.utcnow().isoformat(),
                "maintenance_issues": [],
                "recommendations": []
            }
            
            # Add pending issues
            if not pending.empty:
                response["maintenance_issues"].append({
                    "status": "pending",
                    "issues": [
                        {"issue": issue, "count": count}
                        for issue, count in pending_counts.items()
                    ]
                })
            
            # Add resolved issues
            if not resolved.empty:
                response["maintenance_issues"].append({
                    "status": "resolved",
                    "issues": [
                        {"issue": issue, "count": count}
                        for issue, count in resolved_counts.items()
                    ]
                })
            
            # Generate recommendations based on issues
            if "Sensor malfunction" in pending_counts:
                response["recommendations"].append(
                    f"Prioritize repair of {pending_counts['Sensor malfunction']} sensor malfunctions to ensure accurate data collection."
                )
            if "Temperature sensor error" in pending_counts:
                response["recommendations"].append(
                    f"Investigate and fix {pending_counts['Temperature sensor error']} temperature sensor errors to maintain reliable environmental data."
                )
            if "Motion detector fault" in pending_counts:
                response["recommendations"].append(
                    "Address motion detector fault to ensure accurate occupancy tracking."
                )
            if pending_counts:
                response["recommendations"].append(
                    "Conduct a comprehensive sensor infrastructure audit to identify systemic issues."
                )
            
            if "High energy usage" in resolved_counts:
                response["recommendations"].append(
                    "Verify that energy efficiency measures are sustained for resolved high energy usage issues."
                )
            if "Humidity calibration needed" in resolved_counts:
                response["recommendations"].append(
                    "Schedule regular maintenance to prevent recurrence of humidity calibration issues."
                )
            if "Power supply issue" in resolved_counts:
                response["recommendations"].append(
                    "Monitor power supply stability to ensure the fix is sustained."
                )
            
            response["recommendations"].append(
                "Implement a preventive maintenance schedule for sensors to reduce future issues."
            )
            
            # Generate summary answer
            pending_summary = f"Pending issues: {', '.join([f'{issue} ({count})' for issue, count in pending_counts.items()])}" if pending_counts else "No pending issues"
            resolved_summary = f"Resolved issues: {', '.join([f'{issue} ({count})' for issue, count in resolved_counts.items()])}" if resolved_counts else "No resolved issues"
            response["answer"] = f"Maintenance analysis completed. {pending_summary}. {resolved_summary}. {len(response['recommendations'])} recommendations provided."
            
            logger.info(f"Maintenance analysis completed: {response['answer']}")
            return response
            
        except Exception as e:
            logger.error(f"Error analyzing maintenance requests: {e}")
            return {
                "analysis_type": "maintenance_analysis",
                "timestamp": datetime.utcnow().isoformat(),
                "answer": f"Error analyzing maintenance requests: {str(e)}",
                "maintenance_issues": [],
                "recommendations": [],
                "error": str(e)
            }
    
    def handle_room_specific_query(self, query: str) -> Dict[str, Any]:
        """Handle room-specific queries with better error messages"""
        # First, ensure we have room data
        self.get_available_rooms()
        
        if not self._available_rooms_cache:
            return {
                "error": "No room information available. Please check database connection."
            }
        
        # Check for maintenance-related queries first
        query_lower = query.lower()
        if any(keyword in query_lower for keyword in ["maintenance", "issues", "maintenance requests"]):
            return self.handle_maintenance_analysis()
        
        room_name = self.parse_room_query(query)
        
        if not room_name:
            available_rooms = [room.get('name', 'Unknown') for room in self._available_rooms_cache]
            return {
                "error": f"Could not identify room from query. Available rooms: {', '.join(available_rooms)}. Please specify like 'Room 1 status' or 'What's happening in Conference Room'"
            }
        
        # Get room data
        room_df = self.get_room_data(room_name)
        
        if room_df.empty:
            # Let's debug what rooms are actually in the sensor data
            try:
                df = self.db_adapter.get_sensor_data_as_dataframe(limit=100)
                if df is not None and 'room_name' in df.columns:
                    actual_rooms_in_data = df['room_name'].unique()
                    logger.info(f"Actual rooms found in sensor data: {actual_rooms_in_data}")
                    
                    # Try to find the closest match in the actual data
                    best_data_match = None
                    best_score = 0
                    
                    for data_room in actual_rooms_in_data:
                        if pd.isna(data_room):
                            continue
                        try:
                            from fuzzywuzzy import fuzz
                            score = fuzz.partial_ratio(room_name.lower(), str(data_room).lower())
                            if score > best_score:
                                best_score = score
                                best_data_match = data_room
                        except ImportError:
                            similarity = self._calculate_similarity_score(room_name.lower(), str(data_room).lower())
                            if similarity > best_score:
                                best_score = similarity
                                best_data_match = data_room
                    
                    if best_data_match and best_score > 60:
                        error_msg = f"No data found for '{room_name}'. Did you mean '{best_data_match}'? Available rooms in data: {', '.join([str(r) for r in actual_rooms_in_data if not pd.isna(r)])}"
                    else:
                        error_msg = f"No data found for '{room_name}'. Available rooms in sensor data: {', '.join([str(r) for r in actual_rooms_in_data if not pd.isna(r)])}"
                else:
                    error_msg = f"No data found for '{room_name}'. No room data available in sensor records."
                    
            except Exception as e:
                logger.error(f"Error debugging room data: {e}")
                error_msg = f"No data found for '{room_name}'. Error checking sensor data: {e}"
            
            return {"error": error_msg}
        
        # Determine query type and handle accordingly
        if any(keyword in query_lower for keyword in ["predict", "prediction", "forecast"]):
            return self.handle_room_predictions(room_name, room_df, query)
        
        elif any(keyword in query_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            return self.handle_room_anomalies(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["energy", "consumption", "power", "usage"]):
            return self.handle_room_energy_analysis(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["status", "condition", "current", "overview"]):
            return self.handle_room_status(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["utilization", "occupancy", "usage pattern"]):
            return self.handle_room_utilization(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["highest", "lowest", "max", "min", "average"]):
            return self.handle_room_min_max_avg(query_lower, room_name, room_df)
        
        else:
            # General room analysis
            return self.handle_general_room_analysis(room_name, room_df, query)
    
    def handle_room_predictions(self, room_name: str, room_df: pd.DataFrame, query: str) -> Dict[str, Any]:
        """Handle predictive analysis for a specific room"""
        try:
            # Detect anomalies specific to this room
            anomalies = self.advanced_handlers.detect_anomalies(room_df)
            
            # Generate maintenance suggestions
            maintenance_alerts = self.advanced_handlers.generate_maintenance_suggestions(room_df, anomalies)
            
            # Analyze trends for predictions
            predictions = self._generate_room_predictions(room_name, room_df)
            
            # Create comprehensive response
            response = {
                "room": room_name,
                "analysis_type": "predictive_analysis",
                "timestamp": datetime.utcnow().isoformat(),
                "data_period": f"{len(room_df)} data points analyzed",
                "predictions": predictions,
                "maintenance_alerts": [
                    {
                        "equipment": m.equipment,
                        "issue": m.issue,
                        "urgency": m.urgency,
                        "timeline": m.timeline,
                        "action": m.action,
                        "confidence": m.confidence
                    } for m in maintenance_alerts
                ],
                "anomalies": [
                    {
                        "type": a.anomaly_type,
                        "severity": a.severity,
                        "description": a.description,
                        "confidence": a.confidence
                    } for a in anomalies
                ],
                "summary": self._create_room_prediction_summary(room_name, predictions, maintenance_alerts, anomalies)
            }
            
            return response
            
        except Exception as e:
            logger.error(f"Error in room predictions for {room_name}: {e}")
            return {"error": f"Failed to generate predictions for {room_name}: {str(e)}"}
    
    def _generate_room_predictions(self, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Generate specific predictions for a room"""
        predictions = {
            "energy_forecast": {},
            "equipment_health": {},
            "environmental_trends": {},
            "occupancy_patterns": {},
            "recommendations": []
        }
        
        if room_df.empty:
            return predictions
        
        try:
            # Energy consumption predictions
            if "energy_consumption_kwh" in room_df.columns:
                energy_data = room_df["energy_consumption_kwh"]
                current_avg = energy_data.mean()
                recent_trend = self.advanced_handlers._calculate_trend(energy_data)
                
                predictions["energy_forecast"] = {
                    "current_average_kwh": round(current_avg, 2),
                    "trend_direction": "increasing" if recent_trend["slope"] > 0.1 else "decreasing" if recent_trend["slope"] < -0.1 else "stable",
                    "predicted_next_week": round(current_avg + (recent_trend["slope"] * 7), 2),
                    "confidence": recent_trend["confidence"]
                }
            
            # Equipment health predictions
            if "power_consumption_watts.total" in room_df.columns:
                power_data = room_df["power_consumption_watts.total"]
                power_trend = self.advanced_handlers._calculate_trend(power_data)
                
                predictions["equipment_health"] = {
                    "power_stability": "stable" if abs(power_trend["slope"]) < 10 else "degrading",
                    "efficiency_trend": "improving" if power_trend["slope"] < -5 else "declining" if power_trend["slope"] > 5 else "stable",
                    "maintenance_priority": "high" if abs(power_trend["slope"]) > 20 else "medium" if abs(power_trend["slope"]) > 10 else "low"
                }
            
            # Environmental predictions
            if "environmental_data.temperature_celsius" in room_df.columns:
                temp_data = room_df["environmental_data.temperature_celsius"]
                temp_avg = temp_data.mean()
                temp_std = temp_data.std()
                
                predictions["environmental_trends"] = {
                    "average_temperature": round(temp_avg, 1),
                    "temperature_stability": "stable" if temp_std < 2 else "variable",
                    "hvac_efficiency": "good" if 20 <= temp_avg <= 24 else "needs_adjustment"
                }
            
            # Occupancy pattern predictions
            if "occupancy_count" in room_df.columns:
                occupancy_data = room_df["occupancy_count"]
                occupied_records = room_df[room_df["occupancy_count"] > 0]
                occupancy_rate = len(occupied_records) / len(room_df) * 100
                
                predictions["occupancy_patterns"] = {
                    "utilization_rate": round(occupancy_rate, 1),
                    "peak_occupancy": int(occupancy_data.max()),
                    "average_when_occupied": round(occupied_records["occupancy_count"].mean(), 1) if not occupied_records.empty else 0,
                    "usage_classification": "high" if occupancy_rate > 70 else "medium" if occupancy_rate > 30 else "low"
                }
            
            # Generate recommendations
            predictions["recommendations"] = self._generate_room_recommendations(room_name, predictions)
            
        except Exception as e:
            logger.error(f"Error generating predictions for {room_name}: {e}")
        
        return predictions
    
    def _generate_room_recommendations(self, room_name: str, predictions: Dict) -> List[str]:
        """Generate specific recommendations for a room"""
        recommendations = []
        
        try:
            # Energy recommendations
            energy_forecast = predictions.get("energy_forecast", {})
            if energy_forecast.get("trend_direction") == "increasing":
                recommendations.append(f"Energy consumption in {room_name} is trending upward. Consider energy efficiency audit.")
            
            # Equipment recommendations
            equipment_health = predictions.get("equipment_health", {})
            if equipment_health.get("maintenance_priority") == "high":
                recommendations.append(f"High maintenance priority detected for {room_name} equipment. Schedule inspection within 1 week.")
            
            # Environmental recommendations
            env_trends = predictions.get("environmental_trends", {})
            if env_trends.get("hvac_efficiency") == "needs_adjustment":
                recommendations.append(f"HVAC system in {room_name} may need temperature setpoint adjustment for optimal efficiency.")
            
            # Occupancy recommendations
            occupancy = predictions.get("occupancy_patterns", {})
            if occupancy.get("usage_classification") == "low":
                recommendations.append(f"{room_name} has low utilization. Consider energy-saving measures during unoccupied periods.")
            elif occupancy.get("usage_classification") == "high":
                recommendations.append(f"{room_name} has high utilization. Monitor equipment wear and consider preventive maintenance.")
            
            if not recommendations:
                recommendations.append(f"{room_name} is operating within normal parameters. Continue regular monitoring.")
                
        except Exception as e:
            logger.error(f"Error generating recommendations for {room_name}: {e}")
            recommendations.append("Unable to generate specific recommendations due to data analysis error.")
        
        return recommendations
    
    def _create_room_prediction_summary(self, room_name: str, predictions: Dict, maintenance_alerts: List, anomalies: List) -> str:
        """Create a summary of room predictions"""
        try:
            summary_parts = [f"Predictive analysis for {room_name}:"]
            
            # Energy summary
            energy_forecast = predictions.get("energy_forecast", {})
            if energy_forecast:
                trend = energy_forecast.get("trend_direction", "stable")
                avg_energy = energy_forecast.get("current_average_kwh", 0)
                summary_parts.append(f"Energy consumption is {trend} (avg: {avg_energy} kWh)")
            
            # Equipment health summary
            equipment_health = predictions.get("equipment_health", {})
            if equipment_health:
                priority = equipment_health.get("maintenance_priority", "low")
                summary_parts.append(f"Equipment maintenance priority: {priority}")
            
            # Alerts summary
            if maintenance_alerts:
                urgent_alerts = [a for a in maintenance_alerts if a.urgency in ["critical", "high"]]
                summary_parts.append(f"{len(maintenance_alerts)} maintenance suggestions ({len(urgent_alerts)} urgent)")
            
            if anomalies:
                critical_anomalies = [a for a in anomalies if a.severity == "Critical"]
                summary_parts.append(f"{len(anomalies)} anomalies detected ({len(critical_anomalies)} critical)")
            
            # Recommendations summary
            recommendations = predictions.get("recommendations", [])
            if recommendations:
                summary_parts.append(f"{len(recommendations)} recommendations provided")
            
            return ". ".join(summary_parts) + "."
            
        except Exception as e:
            logger.error(f"Error creating summary for {room_name}: {e}")
            return f"Analysis completed for {room_name} with some data processing limitations."
    
    def handle_room_anomalies(self, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Handle anomaly detection for a specific room"""
        anomalies = self.advanced_handlers.detect_anomalies(room_df)
        
        return {
            "room": room_name,
            "analysis_type": "anomaly_detection",
            "timestamp": datetime.utcnow().isoformat(),
            "anomalies_detected": len(anomalies),
            "anomalies": [
                {
                    "type": a.anomaly_type,
                    "severity": a.severity,
                    "description": a.description,
                    "timestamp": a.timestamp,
                    "confidence": a.confidence
                } for a in anomalies
            ],
            "answer": f"Detected {len(anomalies)} anomalies in {room_name}" if anomalies else f"No anomalies detected in {room_name}"
        }
    
    def handle_room_energy_analysis(self, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Handle energy analysis for a specific room"""
        energy_insights = self.advanced_handlers.generate_energy_insights(room_df)
        
        return {
            "room": room_name,
            "analysis_type": "energy_analysis",
            "timestamp": datetime.utcnow().isoformat(),
            "insights": [
                {
                    "metric": i.metric,
                    "current_value": i.current_value,
                    "trend": i.trend,
                    "opportunity": i.opportunity,
                    "recommendation": i.recommendation
                } for i in energy_insights
            ],
            "answer": f"Generated {len(energy_insights)} energy insights for {room_name}"
        }
    
    def handle_room_status(self, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Handle current status query for a specific room"""
        if room_df.empty:
            return {
                "room": room_name,
                "error": "No current data available"
            }
        
        # Get latest record
        latest_record = room_df.iloc[0]  # Assuming data is sorted by timestamp desc
        
        return {
            "room": room_name,
            "analysis_type": "current_status",
            "timestamp": datetime.utcnow().isoformat(),
            "current_status": {
                "occupancy": latest_record.get("occupancy_status", "unknown"),
                "occupant_count": int(latest_record.get("occupancy_count", 0)),
                "temperature": float(latest_record.get("environmental_data.temperature_celsius", 0)),
                "humidity": float(latest_record.get("environmental_data.humidity_percent", 0)),
                "energy_consumption": float(latest_record.get("energy_consumption_kwh", 0)),
                "total_power": float(latest_record.get("power_consumption_watts.total", 0)),
                "last_updated": str(latest_record.get("timestamp", "unknown"))
            },
            "answer": f"{room_name} is currently {latest_record.get('occupancy_status', 'unknown')} with {int(latest_record.get('occupancy_count', 0))} occupants. Temperature: {latest_record.get('environmental_data.temperature_celsius', 0):.1f}°C, Power: {latest_record.get('power_consumption_watts.total', 0):.0f}W"
        }
    
    def handle_room_utilization(self, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Handle utilization analysis for a specific room"""
        result = self.advanced_handlers.handle_most_used_room_query(room_df)
        
        # Customize for specific room
        result["room"] = room_name
        result["analysis_type"] = "room_utilization"
        
        return result
    
    def handle_room_min_max_avg(self, q_lower: str, room_name: str, room_df: pd.DataFrame) -> Dict[str, Any]:
        """Handle min/max/average queries for a specific room."""
        col_map = {
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "energy": "energy_consumption_kwh",
            "power": "power_consumption_watts.total",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "lighting": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "fan": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "air conditioner": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc",
            "misc": "power_consumption_watts.standby_misc"
        }
        
        op_map = {
            "highest": "max",
            "maximum": "max",
            "max": "max",
            "lowest": "min",
            "minimum": "min",
            "min": "min",
            "average": "mean",
            "mean": "mean",
            "avg": "mean"
        }

        found_op = None
        found_col = None
        for op_word, op_func in op_map.items():
            if op_word in q_lower:
                found_op = op_func
                break
        for col_word, col_name in col_map.items():
            if col_word in q_lower:
                found_col = col_name
                break

        if found_op and found_col and found_col in room_df.columns:
            if found_op == "max":
                value = room_df[found_col].max()
                op_word = "highest"
            elif found_op == "min":
                value = room_df[found_col].min()
                op_word = "lowest"
            elif found_op == "mean":
                value = room_df[found_col].mean()
                op_word = "average"

            matching_rows = room_df[room_df[found_col] == value] if found_op != "mean" else room_df.sample(min(3, len(room_df)))
            timestamps = [str(row["timestamp"]) for _, row in matching_rows.iterrows()]

            answer = f"The {op_word} {col_word} in {room_name} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}."
            sources = [{"page_content": str(row.to_dict()), "metadata": {}} for _, row in matching_rows.iterrows()]

            return {
                "room": room_name,
                "analysis_type": "statistical",
                "answer": answer,
                "sources": sources
            }

        return {"error": "Unable to process min/max/avg query for the specified metric in this room."}
    
    def handle_general_room_analysis(self, room_name: str, room_df: pd.DataFrame, query: str) -> Dict[str, Any]:
        """Handle general room analysis queries"""
        # Generate comprehensive room analysis
        predictions = self._generate_room_predictions(room_name, room_df)
        anomalies = self.advanced_handlers.detect_anomalies(room_df)
        maintenance_alerts = self.advanced_handlers.generate_maintenance_suggestions(room_df, anomalies)
        
        return {
            "room": room_name,
            "analysis_type": "comprehensive_analysis",
            "timestamp": datetime.utcnow().isoformat(),
            "query": query,
            "predictions": predictions,
            "anomalies_count": len(anomalies),
            "maintenance_alerts_count": len(maintenance_alerts),
            "answer": f"Comprehensive analysis for {room_name}: {predictions.get('recommendations', ['Analysis completed'])[0] if predictions.get('recommendations') else 'Analysis completed successfully'}"
        }