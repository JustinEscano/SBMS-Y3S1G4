"""
Room-Specific LLM Handlers
Handles room-specific queries like "What are the predictions for Room 1?"
"""

import pandas as pd
import numpy as np
import logging
from typing import Dict, List, Any, Optional
from datetime import datetime, timedelta
from advanced_llm_handlers import AdvancedLLMHandlers, MaintenanceAlert, AnomalyDetection, EnergyInsight

logger = logging.getLogger(__name__)

class RoomSpecificHandlers:
    """
    Handles room-specific queries and analysis
    """
    
    def __init__(self, prompts_config, db_adapter):
        self.prompts = prompts_config
        self.db_adapter = db_adapter
        self.advanced_handlers = AdvancedLLMHandlers(prompts_config)
    
    def get_available_rooms(self) -> List[Dict[str, Any]]:
        """Get list of all available rooms"""
        try:
            return self.db_adapter.get_rooms_list()
        except Exception as e:
            logger.error(f"Error getting rooms list: {e}")
            return []
    
    def get_room_data(self, room_name: str, limit: int = None) -> pd.DataFrame:
        """Get sensor data for a specific room"""
        try:
            # Get all data first
            df = self.db_adapter.get_sensor_data_as_dataframe(limit=limit)
            
            if df is None or df.empty:
                return pd.DataFrame()
            
            # Filter by room name (case-insensitive)
            if 'room_name' in df.columns:
                room_df = df[df['room_name'].str.lower() == room_name.lower()]
            else:
                # If no room_name column, return empty DataFrame
                logger.warning("No room_name column found in data")
                return pd.DataFrame()
            
            logger.info(f"Found {len(room_df)} records for room '{room_name}'")
            return room_df
            
        except Exception as e:
            logger.error(f"Error getting room data for '{room_name}': {e}")
            return pd.DataFrame()
    
    def parse_room_query(self, query: str) -> Optional[str]:
        """Extract room name from query"""
        query_lower = query.lower()
        
        # Common room name patterns
        room_patterns = [
            r'room\s+(\w+)',
            r'room\s+(\d+)',
            r'(\w+)\s+room',
            r'in\s+(\w+)',
            r'for\s+(\w+)',
        ]
        
        import re
        for pattern in room_patterns:
            match = re.search(pattern, query_lower)
            if match:
                room_name = match.group(1)
                # Convert common variations
                if room_name.isdigit():
                    return f"Room {room_name}"
                elif room_name in ['one', '1']:
                    return "Room 1"
                elif room_name in ['two', '2']:
                    return "Room 2"
                elif room_name in ['three', '3']:
                    return "Room 3"
                else:
                    return room_name.title()
        
        return None
    
    def handle_room_specific_query(self, query: str) -> Dict[str, Any]:
        """Handle room-specific queries"""
        room_name = self.parse_room_query(query)
        
        if not room_name:
            return {
                "error": "Could not identify room from query. Please specify a room name (e.g., 'Room 1', 'Room A', etc.)"
            }
        
        # Get room data
        room_df = self.get_room_data(room_name)
        
        if room_df.empty:
            available_rooms = self.get_available_rooms()
            room_names = [room['name'] for room in available_rooms]
            return {
                "error": f"No data found for '{room_name}'. Available rooms: {', '.join(room_names) if room_names else 'None'}"
            }
        
        # Determine query type and handle accordingly
        query_lower = query.lower()
        
        if any(keyword in query_lower for keyword in ["predict", "prediction", "forecast", "maintenance"]):
            return self.handle_room_predictions(room_name, room_df, query)
        
        elif any(keyword in query_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            return self.handle_room_anomalies(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["energy", "consumption", "power", "usage"]):
            return self.handle_room_energy_analysis(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["status", "condition", "current", "overview"]):
            return self.handle_room_status(room_name, room_df)
        
        elif any(keyword in query_lower for keyword in ["utilization", "occupancy", "usage pattern"]):
            return self.handle_room_utilization(room_name, room_df)
        
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