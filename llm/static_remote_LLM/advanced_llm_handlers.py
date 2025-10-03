"""
Advanced LLM Handlers for Predictive Maintenance and Insights
Handles specialized queries for maintenance, anomalies, and advanced analytics
"""

import pandas as pd
import numpy as np
import json
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
import re

logger = logging.getLogger(__name__)

@dataclass
class MaintenanceAlert:
    equipment: str
    issue: str
    urgency: str
    confidence: float
    timeline: str
    action: str
    cost_estimate: str
    risk_level: str

@dataclass
class AnomalyDetection:
    anomaly_type: str
    severity: str
    location: str
    description: str
    timestamp: str
    value: float
    expected_range: Tuple[float, float]
    confidence: float

@dataclass
class EnergyInsight:
    metric: str
    current_value: float
    trend: str
    benchmark: float
    opportunity: str
    potential_savings: str
    recommendation: str

class AdvancedLLMHandlers:
    """
    Advanced handlers for predictive maintenance, anomaly detection, and insights
    """
    
    def __init__(self, prompts_config):
        self.prompts = prompts_config
        self.maintenance_rules = prompts_config.get_all_prompts().get("maintenance_rules", {})
        self.insights_config = prompts_config.get_all_prompts().get("insights_config", {})
    
    def preprocess_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Preprocess the DataFrame: Remove duplicates and handle missing columns"""
        if df.empty:
            logger.warning("Empty DataFrame provided for preprocessing")
            return df
        
        # Log initial shape
        logger.info(f"Initial DataFrame shape: {df.shape}")
        
        # Handle missing columns with defaults
        required_columns = {
            "timestamp": pd.NaT,
            "occupancy_count": 0,
            "energy_consumption_kwh": 0.0,
            "power_consumption_watts.total": 0.0,
            "environmental_data.temperature_celsius": 0.0,
            "environmental_data.humidity_percent": 0.0,
            "equipment_usage.lights_on_hours": 0.0,
            "equipment_usage.air_conditioner_on_hours": 0.0,
            "equipment_usage.projector_on_hours": 0.0,
            "equipment_usage.computer_on_hours": 0.0
        }
        for col, default in required_columns.items():
            if col not in df.columns:
                logger.warning(f"Missing column '{col}', filling with default value {default}")
                df[col] = default
        
        # Convert timestamp to datetime if not already
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
        
        # Remove duplicates based on key columns
        key_columns = ["timestamp", "occupancy_count", "energy_consumption_kwh"]
        df = df.drop_duplicates(subset=[col for col in key_columns if col in df.columns])
        
        # Log after deduplication
        logger.info(f"DataFrame shape after deduplication: {df.shape}")
        
        # Check for zeroed data
        numeric_cols = [col for col in df.columns if col.startswith(("power_consumption_watts", "energy_consumption_kwh", "environmental_data", "equipment_usage"))]
        zero_percentage = (df[numeric_cols] == 0).mean().mean() * 100
        if zero_percentage > 50:
            logger.warning(f"High percentage of zero values in numeric columns: {zero_percentage:.1f}% - Possible test data or sensor issues")
        
        return df
    
    def detect_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect anomalies in the sensor data"""
        df = self.preprocess_data(df)
        
        anomalies = []
        
        if df.empty:
            logger.warning("No data available for anomaly detection")
            return anomalies
        
        # Power consumption anomalies
        power_anomalies = self._detect_power_anomalies(df)
        anomalies.extend(power_anomalies)
        
        # Temperature anomalies
        temp_anomalies = self._detect_temperature_anomalies(df)
        anomalies.extend(temp_anomalies)
        
        # Humidity anomalies
        humidity_anomalies = self._detect_humidity_anomalies(df)
        anomalies.extend(humidity_anomalies)
        
        # Runtime anomalies
        runtime_anomalies = self._detect_runtime_anomalies(df)
        anomalies.extend(runtime_anomalies)
        
        logger.info(f"Detected {len(anomalies)} anomalies")
        return anomalies
    
    def _detect_power_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect power consumption anomalies"""
        anomalies = []
        threshold = self.maintenance_rules.get("power_anomaly_threshold", 1.5)
        
        if "power_consumption_watts.total" not in df.columns:
            logger.warning("Missing 'power_consumption_watts.total' for power anomaly detection")
            return anomalies
        
        power_data = df["power_consumption_watts.total"]
        mean_power = power_data.mean()
        std_power = power_data.std()
        
        if std_power == 0:
            logger.warning("No variation in power data - skipping anomaly detection")
            return anomalies
        
        for idx, row in df.iterrows():
            power = row["power_consumption_watts.total"]
            z_score = abs((power - mean_power) / std_power)
            
            if z_score > threshold:
                severity = "High" if z_score > 2.5 else "Medium"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Power Consumption",
                    severity=severity,
                    location=f"Room at {row['timestamp']}",
                    description=f"Power consumption {power}W is {z_score:.1f} standard deviations from normal",
                    timestamp=str(row['timestamp']),
                    value=power,
                    expected_range=(mean_power - std_power, mean_power + std_power),
                    confidence=min(z_score / 3.0, 1.0)
                ))
        
        return anomalies
    
    def _detect_temperature_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect temperature anomalies"""
        anomalies = []
        temp_range = self.maintenance_rules.get("temperature_anomaly_range", [18, 28])
        
        if "environmental_data.temperature_celsius" not in df.columns:
            logger.warning("Missing 'environmental_data.temperature_celsius' for temperature anomaly detection")
            return anomalies
        
        for idx, row in df.iterrows():
            temp = row["environmental_data.temperature_celsius"]
            
            if temp < temp_range[0] or temp > temp_range[1]:
                severity = "Critical" if temp < 15 or temp > 32 else "High"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Temperature",
                    severity=severity,
                    location=f"Room at {row['timestamp']}",
                    description=f"Temperature {temp}°C is outside normal range",
                    timestamp=str(row['timestamp']),
                    value=temp,
                    expected_range=(temp_range[0], temp_range[1]),
                    confidence=0.9
                ))
        
        return anomalies
    
    def _detect_humidity_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect humidity anomalies"""
        anomalies = []
        humidity_range = self.maintenance_rules.get("humidity_anomaly_range", [30, 70])
        
        if "environmental_data.humidity_percent" not in df.columns:
            logger.warning("Missing 'environmental_data.humidity_percent' for humidity anomaly detection")
            return anomalies
        
        for idx, row in df.iterrows():
            humidity = row["environmental_data.humidity_percent"]
            
            if humidity < humidity_range[0] or humidity > humidity_range[1]:
                severity = "Medium" if 20 <= humidity <= 80 else "High"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Humidity",
                    severity=severity,
                    location=f"Room at {row['timestamp']}",
                    description=f"Humidity {humidity}% is outside optimal range",
                    timestamp=str(row['timestamp']),
                    value=humidity,
                    expected_range=(humidity_range[0], humidity_range[1]),
                    confidence=0.8
                ))
        
        return anomalies
    
    def _detect_runtime_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect equipment runtime anomalies"""
        anomalies = []
        runtime_threshold = self.maintenance_rules.get("runtime_anomaly_threshold", 12)
        
        runtime_columns = [
            "equipment_usage.lights_on_hours",
            "equipment_usage.air_conditioner_on_hours",
            "equipment_usage.projector_on_hours",
            "equipment_usage.computer_on_hours"
        ]
        
        for col in runtime_columns:
            if col not in df.columns:
                logger.warning(f"Missing '{col}' for runtime anomaly detection")
                continue
                
            equipment_name = col.split('.')[-1].replace('_on_hours', '').replace('_', ' ').title()
            
            for idx, row in df.iterrows():
                runtime = row[col]
                
                if runtime > runtime_threshold:
                    severity = "High" if runtime > 16 else "Medium"
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Equipment Runtime",
                        severity=severity,
                        location=f"Room at {row['timestamp']}",
                        description=f"{equipment_name} runtime {runtime}h exceeds normal operating hours",
                        timestamp=str(row['timestamp']),
                        value=runtime,
                        expected_range=(0, runtime_threshold),
                        confidence=0.7
                    ))
        
        return anomalies
    
    def generate_maintenance_suggestions(self, df: pd.DataFrame, anomalies: List[AnomalyDetection]) -> List[MaintenanceAlert]:
        """Generate maintenance suggestions based on data analysis"""
        suggestions = []
        
        # Analyze anomalies for maintenance needs
        for anomaly in anomalies:
            suggestion = self._anomaly_to_maintenance_suggestion(anomaly)
            if suggestion:
                suggestions.append(suggestion)
        
        # Analyze trends for predictive maintenance
        trend_suggestions = self._analyze_trends_for_maintenance(df)
        suggestions.extend(trend_suggestions)
        
        logger.info(f"Generated {len(suggestions)} maintenance suggestions")
        return suggestions
    
    def _anomaly_to_maintenance_suggestion(self, anomaly: AnomalyDetection) -> Optional[MaintenanceAlert]:
        """Convert anomaly to maintenance suggestion"""
        urgency_map = {
            "Critical": "critical",
            "High": "high", 
            "Medium": "medium",
            "Low": "low"
        }
        
        if anomaly.anomaly_type == "Power Consumption":
            return MaintenanceAlert(
                equipment="Electrical Systems",
                issue=f"Abnormal power consumption detected: {anomaly.value}W",
                urgency=urgency_map.get(anomaly.severity, "medium"),
                confidence=anomaly.confidence,
                timeline="Within 48 hours" if anomaly.severity == "High" else "Within 1 week",
                action="Inspect electrical connections and equipment efficiency",
                cost_estimate="$200-500",
                risk_level="Equipment damage, increased energy costs"
            )
        
        elif anomaly.anomaly_type == "Temperature":
            return MaintenanceAlert(
                equipment="HVAC System",
                issue=f"Temperature outside normal range: {anomaly.value}°C",
                urgency=urgency_map.get(anomaly.severity, "high"),
                confidence=anomaly.confidence,
                timeline="Immediate" if anomaly.severity == "Critical" else "Within 24 hours",
                action="Check HVAC system, filters, and thermostat calibration",
                cost_estimate="$150-800",
                risk_level="Comfort issues, equipment stress, energy waste"
            )
        
        elif anomaly.anomaly_type == "Humidity":
            return MaintenanceAlert(
                equipment="Climate Control",
                issue=f"Humidity outside optimal range: {anomaly.value}%",
                urgency=urgency_map.get(anomaly.severity, "medium"),
                confidence=anomaly.confidence,
                timeline="Within 1 week",
                action="Inspect humidity control systems and ventilation",
                cost_estimate="$100-400",
                risk_level="Air quality issues, potential mold growth"
            )
        
        elif anomaly.anomaly_type == "Equipment Runtime":
            return MaintenanceAlert(
                equipment="Equipment Systems",
                issue=f"Excessive runtime detected: {anomaly.value}h",
                urgency=urgency_map.get(anomaly.severity, "medium"),
                confidence=anomaly.confidence,
                timeline="Within 1 week",
                action="Inspect equipment for efficiency and scheduling issues",
                cost_estimate="$100-300",
                risk_level="Premature wear, increased energy costs"
            )
        
        return None
    
    def _analyze_trends_for_maintenance(self, df: pd.DataFrame) -> List[MaintenanceAlert]:
        """Analyze trends to predict maintenance needs"""
        suggestions = []
        
        if len(df) < 3:  # Need minimum data for trend analysis
            logger.warning("Insufficient data for trend analysis")
            return suggestions
        
        # Analyze power consumption trends
        if "power_consumption_watts.total" in df.columns:
            power_trend = self._calculate_trend(df["power_consumption_watts.total"])
            if power_trend["slope"] > 50:  # Increasing power consumption
                suggestions.append(MaintenanceAlert(
                    equipment="Building Systems",
                    issue=f"Power consumption trending upward: +{power_trend['slope']:.1f}W/day",
                    urgency="medium",
                    confidence=power_trend["confidence"],
                    timeline="Within 2 weeks",
                    action="Investigate equipment efficiency degradation",
                    cost_estimate="$300-1000",
                    risk_level="Increased operational costs"
                ))
        
        # Analyze temperature trends
        if "environmental_data.temperature_celsius" in df.columns:
            temp_trend = self._calculate_trend(df["environmental_data.temperature_celsius"])
            if abs(temp_trend["slope"]) > 0.5:  # Significant temperature change
                direction = "increasing" if temp_trend["slope"] > 0 else "decreasing"
                suggestions.append(MaintenanceAlert(
                    equipment="HVAC System",
                    issue=f"Temperature trending {direction}: {abs(temp_trend['slope']):.1f}°C/day",
                    urgency="high" if abs(temp_trend["slope"]) > 1.0 else "medium",
                    confidence=temp_trend["confidence"],
                    timeline="Within 48 hours",
                    action="Check HVAC performance and calibration",
                    cost_estimate="$200-600",
                    risk_level="System inefficiency or failure"
                ))
        
        return suggestions
    
    def _calculate_trend(self, data: pd.Series) -> Dict[str, float]:
        """Calculate trend slope and confidence"""
        if len(data) < 2:
            return {"slope": 0, "confidence": 0}
        
        x = np.arange(len(data))
        y = data.values
        
        # Simple linear regression
        slope = np.polyfit(x, y, 1)[0]
        correlation = np.corrcoef(x, y)[0, 1] if len(set(y)) > 1 else 0
        confidence = abs(correlation)
        
        return {"slope": slope, "confidence": confidence}
    
    def generate_energy_insights(self, df: pd.DataFrame) -> List[EnergyInsight]:
        """Generate energy efficiency insights"""
        df = self.preprocess_data(df)
        insights = []
        
        if df.empty:
            logger.warning("Empty DataFrame for energy insights")
            return insights
        
        # Energy consumption analysis
        if "energy_consumption_kwh" in df.columns:
            energy_data = df["energy_consumption_kwh"]
            avg_energy = energy_data.mean()
            total_energy = energy_data.sum()
            
            # Cost analysis
            cost_per_kwh = self.insights_config.get("cost_per_kwh", 0.12)
            total_cost = total_energy * cost_per_kwh
            
            insights.append(EnergyInsight(
                metric="Total Energy Consumption",
                current_value=total_energy,
                trend="Stable" if energy_data.std() < avg_energy * 0.1 else "Variable",
                benchmark=avg_energy,
                opportunity="Monitor peak usage periods",
                potential_savings=f"${total_cost * 0.1:.2f}",
                recommendation="Implement energy monitoring and scheduling"
            ))
        
        # Power efficiency analysis
        if "power_consumption_watts.total" in df.columns and "occupancy_count" in df.columns:
            occupied_df = df[df["occupancy_count"] > 0]
            if not occupied_df.empty:
                power_per_person = occupied_df["power_consumption_watts.total"] / occupied_df["occupancy_count"]
                avg_power_per_person = power_per_person.mean()
                
                insights.append(EnergyInsight(
                    metric="Power per Occupant",
                    current_value=avg_power_per_person,
                    trend="Efficiency metric",
                    benchmark=200.0,  # Benchmark watts per person
                    opportunity="Optimize occupancy-based controls",
                    potential_savings="15-25% energy reduction",
                    recommendation="Implement occupancy-based lighting and HVAC controls"
                ))
        
        logger.info(f"Generated {len(insights)} energy insights")
        return insights
    
    def handle_most_used_room_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle 'most used room' type queries"""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for most used room query")
            return {"error": "No data available for room analysis"}
        
        # Since we're analyzing single room data, provide occupancy analysis
        occupied_records = df[df["occupancy_count"] > 0]
        total_records = len(df)
        occupancy_rate = (len(occupied_records) / total_records * 100) if total_records > 0 else 0
        
        total_occupancy_hours = occupied_records["occupancy_count"].sum()
        avg_occupancy = occupied_records["occupancy_count"].mean() if not occupied_records.empty else 0
        
        # Find peak usage time
        if not occupied_records.empty:
            peak_record = occupied_records.loc[occupied_records["occupancy_count"].idxmax()]
            peak_time = peak_record["timestamp"]
            peak_occupancy = peak_record["occupancy_count"]
        else:
            peak_time = "No peak usage"
            peak_occupancy = 0
        
        # Energy consumption during occupied periods
        energy_during_occupancy = occupied_records["energy_consumption_kwh"].sum() if not occupied_records.empty else 0
        
        return {
            "answer": f"Room utilization analysis shows {occupancy_rate:.1f}% occupancy rate with {total_occupancy_hours} total person-hours. Peak usage was {peak_occupancy} people at {peak_time}. Energy consumption during occupied periods: {energy_during_occupancy:.2f} kWh. Average occupancy when in use: {avg_occupancy:.1f} people.",
            "metrics": {
                "occupancy_rate": occupancy_rate,
                "total_hours": total_occupancy_hours,
                "peak_time": str(peak_time),
                "peak_occupancy": peak_occupancy,
                "energy_usage": energy_during_occupancy,
                "avg_occupancy": avg_occupancy
            }
        }
    
    def handle_energy_trends_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle energy trends analysis queries"""
        df = self.preprocess_data(df)
        
        if df.empty or "energy_consumption_kwh" not in df.columns:
            logger.warning("No energy data available for trend analysis")
            return {"error": "No energy data available for trend analysis"}
        
        energy_data = df["energy_consumption_kwh"]
        total_energy = energy_data.sum()
        avg_daily = energy_data.mean()
        
        # Calculate trend
        trend_info = self._calculate_trend(energy_data)
        trend_direction = "Increasing" if trend_info["slope"] > 0.1 else "Decreasing" if trend_info["slope"] < -0.1 else "Stable"
        change_rate = abs(trend_info["slope"] / avg_daily * 100) if avg_daily > 0 else 0
        
        # Find peak consumption
        peak_consumption = energy_data.max()
        peak_record = df.loc[energy_data.idxmax()]
        peak_time = peak_record["timestamp"]
        
        # Cost analysis
        cost_per_kwh = self.insights_config.get("cost_per_kwh", 0.12)
        total_cost = total_energy * cost_per_kwh
        
        recommendations = []
        if trend_direction == "Increasing":
            recommendations.append("Investigate equipment efficiency")
            recommendations.append("Consider energy-saving measures")
        elif change_rate > 20:
            recommendations.append("Monitor for equipment issues")
            recommendations.append("Review usage patterns")
        else:
            recommendations.append("Maintain current efficiency practices")
        
        return {
            "answer": f"Energy trend analysis shows {trend_direction.lower()} consumption with {change_rate:.1f}% change rate. Total energy: {total_energy:.2f} kWh, average daily: {avg_daily:.2f} kWh. Peak consumption: {peak_consumption:.2f} kWh at {peak_time}. Estimated cost: ${total_cost:.2f}. Recommendations: {', '.join(recommendations)}.",
            "metrics": {
                "trend_direction": trend_direction,
                "change_rate": change_rate,
                "total_energy": total_energy,
                "avg_daily": avg_daily,
                "peak_consumption": peak_consumption,
                "peak_time": str(peak_time),
                "cost_impact": total_cost,
                "recommendations": recommendations
            }
        }
    
    def handle_kpi_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle key performance indicators query"""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for KPI query")
            return {"error": "No data available for KPI analysis"}
        
        # Calculate KPIs
        total_energy = df["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in df.columns else 0
        avg_occupancy = df["occupancy_count"].mean() if "occupancy_count" in df.columns else 0
        energy_per_person = total_energy / avg_occupancy if avg_occupancy > 0 else 0
        cost_per_kwh = self.insights_config.get("cost_per_kwh", 0.12)
        total_cost = total_energy * cost_per_kwh
        
        anomalies = self.detect_anomalies(df)
        
        kpis = {
            "energy_efficiency": energy_per_person,
            "total_energy_cost": total_cost,
            "anomaly_count": len(anomalies),
            "avg_occupancy": avg_occupancy
        }
        
        return {
            "answer": f"Key Performance Indicators: Energy Efficiency: {energy_per_person:.2f} kWh/person, Total Cost: ${total_cost:.2f}, Anomalies: {len(anomalies)}, Avg Occupancy: {avg_occupancy:.1f} people.",
            "metrics": kpis
        }
    
    def generate_weekly_summary(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Generate automated weekly summary"""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for weekly summary")
            return {"error": "No data available for weekly summary"}
        
        # Basic metrics
        total_energy = df["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in df.columns else 0
        avg_occupancy = df["occupancy_count"].mean() if "occupancy_count" in df.columns else 0
        
        # Detect anomalies and maintenance needs
        anomalies = self.detect_anomalies(df)
        maintenance_alerts = self.generate_maintenance_suggestions(df, anomalies)
        
        # Energy insights
        energy_insights = self.generate_energy_insights(df)
        
        # Cost analysis
        cost_per_kwh = self.insights_config.get("cost_per_kwh", 0.12)
        total_cost = total_energy * cost_per_kwh
        
        # Generate summary
        summary_parts = [
            f"Weekly facility summary: {total_energy:.1f} kWh consumed",
            f"Average occupancy: {avg_occupancy:.1f} people",
            f"Energy cost: ${total_cost:.2f}",
            f"Anomalies detected: {len(anomalies)}",
            f"Maintenance items: {len(maintenance_alerts)}"
        ]
        
        if maintenance_alerts:
            urgent_alerts = [a for a in maintenance_alerts if a.urgency in ["critical", "high"]]
            if urgent_alerts:
                summary_parts.append(f"Urgent maintenance items: {len(urgent_alerts)}")
        
        return {
            "answer": ". ".join(summary_parts) + ".",
            "summary": {
                "total_energy": total_energy,
                "avg_occupancy": avg_occupancy,
                "alert_count": len(anomalies),
                "maintenance_count": len(maintenance_alerts),
                "cost_impact": total_cost,
                "urgent_maintenance": len([a for a in maintenance_alerts if a.urgency in ["critical", "high"]])
            },
            "anomalies": [
                {
                    "type": a.anomaly_type,
                    "severity": a.severity,
                    "description": a.description,
                    "timestamp": a.timestamp
                } for a in anomalies
            ],
            "maintenance_alerts": [
                {
                    "equipment": m.equipment,
                    "issue": m.issue,
                    "urgency": m.urgency,
                    "timeline": m.timeline,
                    "action": m.action
                } for m in maintenance_alerts
            ],
            "insights": [
                {
                    "metric": i.metric,
                    "value": i.current_value,
                    "opportunity": i.opportunity,
                    "recommendation": i.recommendation
                } for i in energy_insights
            ]
        }
    
    def handle_context_aware_query(self, query: str, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle context-aware queries that consider current conditions and trends"""
        df = self.preprocess_data(df)
        
        current_time = datetime.now()
        
        # Analyze current context
        context = {
            "time_of_day": current_time.hour,
            "day_of_week": current_time.weekday(),
            "season": self._get_season(current_time),
            "data_timespan": self._get_data_timespan(df)
        }
        
        # Get latest conditions
        if not df.empty:
            latest_record = df.iloc[-1]
            context.update({
                "current_occupancy": latest_record.get("occupancy_count", 0),
                "current_temperature": latest_record.get("environmental_data.temperature_celsius", 0),
                "current_power": latest_record.get("power_consumption_watts.total", 0)
            })
        
        # Detect anomalies with context
        anomalies = self.detect_anomalies(df)
        
        # Generate context-aware response
        context_insights = []
        
        # Time-based insights
        if context["time_of_day"] < 8 or context["time_of_day"] > 18:
            context_insights.append("Outside normal business hours - monitor for unnecessary energy usage")
        
        # Seasonal context
        if context["season"] in ["summer", "winter"]:
            context_insights.append(f"Peak {context['season']} season - expect higher HVAC usage")
        
        # Current conditions context
        if context.get("current_temperature", 22) > 26:
            context_insights.append("High temperature detected - cooling system may be under stress")
        elif context.get("current_temperature", 22) < 18:
            context_insights.append("Low temperature detected - heating system active")
        
        return {
            "answer": f"Context-aware analysis considering current conditions: {', '.join(context_insights) if context_insights else 'Normal operating conditions detected'}. {len(anomalies)} anomalies found in recent data.",
            "context": context,
            "insights": context_insights,
            "anomalies": len(anomalies),
            "recommendations": self._get_context_recommendations(context, anomalies)
        }
    
    def _get_season(self, date: datetime) -> str:
        """Determine season based on date"""
        month = date.month
        if month in [12, 1, 2]:
            return "winter"
        elif month in [3, 4, 5]:
            return "spring"
        elif month in [6, 7, 8]:
            return "summer"
        else:
            return "fall"
    
    def _get_data_timespan(self, df: pd.DataFrame) -> str:
        """Get timespan of data"""
        if df.empty:
            return "No data"
        
        try:
            start_time = pd.to_datetime(df["timestamp"].min())
            end_time = pd.to_datetime(df["timestamp"].max())
            duration = end_time - start_time
            
            if duration.days > 7:
                return f"{duration.days} days"
            elif duration.days > 0:
                return f"{duration.days} days, {duration.seconds // 3600} hours"
            else:
                return f"{duration.seconds // 3600} hours"
        except Exception as e:
            logger.warning(f"Error calculating data timespan: {e}")
            return "Unknown timespan"