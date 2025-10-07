"""
Advanced LLM Handlers for Predictive Maintenance and Insights
Handles specialized queries for maintenance, anomalies, and advanced analytics
"""

import pandas as pd
import numpy as np
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass

# Conditional import for DatabaseAdapter
try:
    from database_adapter import DatabaseAdapter
except ImportError:
    DatabaseAdapter = None

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
    room: str = "Unknown"
    component: str = "Unknown"

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
    equipment: str = "Unknown"
    component: str = "Unknown"

@dataclass
class EnergyInsight:
    metric: str
    current_value: float
    trend: str
    benchmark: float
    opportunity: str
    potential_savings: str
    recommendation: str
    room: str = "Unknown"

class AdvancedLLMHandlers:
    """
    Advanced handlers for predictive maintenance, anomaly detection, and insights,
    tailored to the provided database schema.
    """
    
    def __init__(self, prompts_config, database_adapter: Optional['DatabaseAdapter'] = None):
        self.prompts = prompts_config
        self.maintenance_rules = prompts_config.get_all_prompts().get("maintenance_rules", {
            "power_anomaly_threshold": 1.5,
            "temperature_anomaly_range": [18, 27],
            "humidity_anomaly_range": [25, 70],
            "runtime_anomaly_threshold": 12,
            "current_anomaly_range": [0, 5],
            "voltage_anomaly_range": [200, 240],
            "power_anomaly_range": [0, 2000]
        })
        self.insights_config = prompts_config.get_all_prompts().get("insights_config", {
            "default_cost_per_kwh": 0.15
        })
        self.db_adapter = database_adapter
        if self.db_adapter is None:
            logger.warning("No DatabaseAdapter provided - using default cost per kWh and no room-specific billing rates")
    
    def preprocess_data(self, df: pd.DataFrame) -> pd.DataFrame:
        """Preprocess the DataFrame: Remove duplicates and handle missing columns."""
        if df.empty:
            logger.warning("Empty DataFrame provided for preprocessing")
            return df
        
        logger.info(f"Initial DataFrame shape: {df.shape}")
        
        # Handle missing columns with defaults based on core_sensorlog schema
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
            "equipment_usage.computer_on_hours": 0.0,
            "current": 0.0,
            "energy": 0.0,
            "power": 0.0,
            "voltage": 0.0,
            "reset_flag": False,
            "equipment_name": "Unknown",
            "room_name": "Unknown",
            "component_type": "Unknown"
        }
        for col, default in required_columns.items():
            if col not in df.columns:
                logger.warning(f"Missing column '{col}', filling with default value {default}")
                df[col] = default
        
        # Convert timestamp to datetime
        if 'timestamp' in df.columns:
            df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
        
        # Remove duplicates based on key columns
        key_columns = ["timestamp", "equipment_name", "room_name", "component_type"]
        df = df.drop_duplicates(subset=[col for col in key_columns if col in df.columns])
        
        logger.info(f"DataFrame shape after deduplication: {df.shape}")
        
        # Check for zeroed data
        numeric_cols = [col for col in df.columns if col.startswith(("power_consumption_watts", "energy_consumption_kwh", 
                                                                    "environmental_data", "equipment_usage", 
                                                                    "current", "energy", "power", "voltage"))]
        zero_percentage = (df[numeric_cols] == 0).mean().mean() * 100
        if zero_percentage > 50:
            logger.warning(f"High percentage of zero values in numeric columns: {zero_percentage:.1f}% - Possible test data or sensor issues")
        
        return df
    
    def detect_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Detect anomalies in the sensor data."""
        df = self.preprocess_data(df)
        anomalies = []
        
        if df.empty:
            logger.warning("No data available for anomaly detection")
            return anomalies
        
        # Group by room and equipment for context-specific anomaly detection
        grouped = df.groupby(['room_name', 'equipment_name', 'component_type'])
        
        for (room, equipment, component), group in grouped:
            # Power consumption anomalies
            power_anomalies = self._detect_power_anomalies(group, room, equipment, component)
            anomalies.extend(power_anomalies)
            
            # Temperature anomalies
            temp_anomalies = self._detect_temperature_anomalies(group, room, equipment, component)
            anomalies.extend(temp_anomalies)
            
            # Humidity anomalies
            humidity_anomalies = self._detect_humidity_anomalies(group, room, equipment, component)
            anomalies.extend(humidity_anomalies)
            
            # Runtime anomalies
            runtime_anomalies = self._detect_runtime_anomalies(group, room, equipment, component)
            anomalies.extend(runtime_anomalies)
            
            # Electrical anomalies (current, power, voltage)
            electrical_anomalies = self._detect_electrical_anomalies(group, room, equipment, component)
            anomalies.extend(electrical_anomalies)
        
        logger.info(f"Detected {len(anomalies)} anomalies")
        return anomalies
    
    def _detect_power_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect power consumption anomalies."""
        anomalies = []
        threshold = self.maintenance_rules.get("power_anomaly_threshold", 1.5)
        
        if "power_consumption_watts.total" not in df.columns:
            logger.warning(f"Missing 'power_consumption_watts.total' for {equipment} in {room}")
            return anomalies
        
        power_data = df["power_consumption_watts.total"]
        mean_power = power_data.mean()
        std_power = power_data.std()
        
        if std_power == 0:
            logger.warning(f"No variation in power data for {equipment} in {room}")
            return anomalies
        
        for idx, row in df.iterrows():
            power = row["power_consumption_watts.total"]
            z_score = abs((power - mean_power) / std_power)
            
            if z_score > threshold:
                severity = "High" if z_score > 2.5 else "Medium"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Power Consumption",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Power consumption {power:.1f}W is {z_score:.1f} standard deviations from normal",
                    timestamp=str(row['timestamp']),
                    value=power,
                    expected_range=(mean_power - std_power, mean_power + std_power),
                    confidence=min(z_score / 3.0, 1.0),
                    equipment=equipment,
                    component=component
                ))
        
        return anomalies
    
    def _detect_temperature_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect temperature anomalies."""
        anomalies = []
        temp_range = self.maintenance_rules.get("temperature_anomaly_range", [18, 27])
        
        if "environmental_data.temperature_celsius" not in df.columns:
            logger.warning(f"Missing 'environmental_data.temperature_celsius' for {equipment} in {room}")
            return anomalies
        
        for idx, row in df.iterrows():
            temp = row["environmental_data.temperature_celsius"]
            
            if pd.notnull(temp) and (temp < temp_range[0] or temp > temp_range[1]):
                severity = "Critical" if temp < 15 or temp > 32 else "High"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Temperature",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Temperature {temp:.1f}°C is outside normal range {temp_range}",
                    timestamp=str(row['timestamp']),
                    value=temp,
                    expected_range=(temp_range[0], temp_range[1]),
                    confidence=0.9,
                    equipment=equipment,
                    component=component
                ))
        
        return anomalies
    
    def _detect_humidity_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect humidity anomalies."""
        anomalies = []
        humidity_range = self.maintenance_rules.get("humidity_anomaly_range", [25, 70])
        
        if "environmental_data.humidity_percent" not in df.columns:
            logger.warning(f"Missing 'environmental_data.humidity_percent' for {equipment} in {room}")
            return anomalies
        
        for idx, row in df.iterrows():
            humidity = row["environmental_data.humidity_percent"]
            
            if pd.notnull(humidity) and (humidity < humidity_range[0] or humidity > humidity_range[1]):
                severity = "Medium" if 20 <= humidity <= 80 else "High"
                anomalies.append(AnomalyDetection(
                    anomaly_type="Humidity",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Humidity {humidity:.1f}% is outside optimal range {humidity_range}",
                    timestamp=str(row['timestamp']),
                    value=humidity,
                    expected_range=(humidity_range[0], humidity_range[1]),
                    confidence=0.8,
                    equipment=equipment,
                    component=component
                ))
        
        return anomalies
    
    def _detect_electrical_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect anomalies in electrical metrics (current, power, voltage)."""
        anomalies = []
        
        # Define ranges for electrical metrics
        current_range = self.maintenance_rules.get("current_anomaly_range", [0, 5])
        power_range = self.maintenance_rules.get("power_anomaly_range", [0, 2000])
        voltage_range = self.maintenance_rules.get("voltage_anomaly_range", [200, 240])
        
        for idx, row in df.iterrows():
            # Current anomalies
            if "current" in df.columns and pd.notnull(row["current"]):
                current = row["current"]
                if current < current_range[0] or current > current_range[1]:
                    severity = "High" if current > current_range[1] * 1.5 else "Medium"
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Current",
                        severity=severity,
                        location=f"{room} - {equipment} ({component})",
                        description=f"Current {current:.2f}A is outside normal range {current_range}",
                        timestamp=str(row['timestamp']),
                        value=current,
                        expected_range=(current_range[0], current_range[1]),
                        confidence=0.85,
                        equipment=equipment,
                        component=component
                    ))
            
            # Power anomalies
            if "power" in df.columns and pd.notnull(row["power"]):
                power = row["power"]
                if power < power_range[0] or power > power_range[1]:
                    severity = "High" if power > power_range[1] * 1.5 else "Medium"
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Power",
                        severity=severity,
                        location=f"{room} - {equipment} ({component})",
                        description=f"Power {power:.1f}W is outside normal range {power_range}",
                        timestamp=str(row['timestamp']),
                        value=power,
                        expected_range=(power_range[0], power_range[1]),
                        confidence=0.85,
                        equipment=equipment,
                        component=component
                    ))
            
            # Voltage anomalies
            if "voltage" in df.columns and pd.notnull(row["voltage"]):
                voltage = row["voltage"]
                if voltage < voltage_range[0] or voltage > voltage_range[1]:
                    severity = "Critical" if voltage < voltage_range[0] * 0.9 or voltage > voltage_range[1] * 1.1 else "High"
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Voltage",
                        severity=severity,
                        location=f"{room} - {equipment} ({component})",
                        description=f"Voltage {voltage:.1f}V is outside normal range {voltage_range}",
                        timestamp=str(row['timestamp']),
                        value=voltage,
                        expected_range=(voltage_range[0], voltage_range[1]),
                        confidence=0.9,
                        equipment=equipment,
                        component=component
                    ))
        
        return anomalies
    
    def _detect_runtime_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect equipment runtime anomalies."""
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
                logger.warning(f"Missing '{col}' for {equipment} in {room}")
                continue
                
            equipment_type = col.split('.')[-1].replace('_on_hours', '').replace('_', ' ').title()
            
            for idx, row in df.iterrows():
                runtime = row[col]
                
                if pd.notnull(runtime) and runtime > runtime_threshold:
                    severity = "High" if runtime > 16 else "Medium"
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Equipment Runtime",
                        severity=severity,
                        location=f"{room} - {equipment} ({component})",
                        description=f"{equipment_type} runtime {runtime:.1f}h exceeds normal operating hours",
                        timestamp=str(row['timestamp']),
                        value=runtime,
                        expected_range=(0, runtime_threshold),
                        confidence=0.7,
                        equipment=equipment,
                        component=component
                    ))
        
        return anomalies
    
    def generate_maintenance_suggestions(self, df: pd.DataFrame, anomalies: List[AnomalyDetection]) -> List[MaintenanceAlert]:
        """Generate maintenance suggestions based on data analysis."""
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
        """Convert anomaly to maintenance suggestion."""
        urgency_map = {
            "Critical": "critical",
            "High": "high",
            "Medium": "medium",
            "Low": "low"
        }
        
        # Common cost estimates based on data
        cost_estimates = {
            "Power Consumption": "$200-500",
            "Temperature": "$150-800",
            "Humidity": "$100-400",
            "Equipment Runtime": "$100-300",
            "Current": "$150-400",
            "Power": "$200-500",
            "Voltage": "$200-600"
        }
        
        # Common actions based on component type
        actions = {
            "DHT22": "Check sensor calibration and HVAC integration",
            "Motion Sensor": "Inspect motion sensor placement and sensitivity",
            "Photoresistor": "Verify light sensor alignment and cleanliness",
            "PZEM": "Inspect electrical connections and meter accuracy"
        }
        
        # Map anomaly types to equipment
        equipment_map = {
            "Power Consumption": anomaly.equipment,
            "Temperature": "HVAC System",
            "Humidity": "Climate Control",
            "Equipment Runtime": anomaly.equipment,
            "Current": anomaly.equipment,
            "Power": anomaly.equipment,
            "Voltage": anomaly.equipment
        }
        
        urgency = urgency_map.get(anomaly.severity, "medium")
        timeline = "Immediate" if urgency == "critical" else "Within 24 hours" if urgency == "high" else "Within 1 week"
        
        return MaintenanceAlert(
            equipment=equipment_map.get(anomaly.anomaly_type, anomaly.equipment),
            issue=f"{anomaly.anomaly_type} anomaly: {anomaly.description}",
            urgency=urgency,
            confidence=anomaly.confidence,
            timeline=timeline,
            action=actions.get(anomaly.component, f"Inspect {anomaly.equipment} and {anomaly.component}"),
            cost_estimate=cost_estimates.get(anomaly.anomaly_type, "$100-500"),
            risk_level="Equipment failure, increased costs, or environmental issues",
            room=anomaly.location.split(" - ")[0] if " - " in anomaly.location else "Unknown",
            component=anomaly.component
        )
    
    def _analyze_trends_for_maintenance(self, df: pd.DataFrame) -> List[MaintenanceAlert]:
        """Analyze trends to predict maintenance needs."""
        suggestions = []
        
        if len(df) < 3:
            logger.warning("Insufficient data for trend analysis")
            return suggestions
        
        # Group by room and equipment
        grouped = df.groupby(['room_name', 'equipment_name'])
        
        for (room, equipment), group in grouped:
            # Power consumption trends
            if "power_consumption_watts.total" in group.columns:
                power_trend = self._calculate_trend(group["power_consumption_watts.total"])
                if power_trend["slope"] > 50:
                    suggestions.append(MaintenanceAlert(
                        equipment=equipment,
                        issue=f"Power consumption trending upward: +{power_trend['slope']:.1f}W/day",
                        urgency="medium",
                        confidence=power_trend["confidence"],
                        timeline="Within 2 weeks",
                        action="Investigate equipment efficiency degradation",
                        cost_estimate="$300-1000",
                        risk_level="Increased operational costs",
                        room=room,
                        component="Unknown"
                    ))
            
            # Temperature trends
            if "environmental_data.temperature_celsius" in group.columns:
                temp_trend = self._calculate_trend(group["environmental_data.temperature_celsius"])
                if abs(temp_trend["slope"]) > 0.5:
                    direction = "increasing" if temp_trend["slope"] > 0 else "decreasing"
                    suggestions.append(MaintenanceAlert(
                        equipment="HVAC System",
                        issue=f"Temperature trending {direction}: {abs(temp_trend['slope']):.1f}°C/day",
                        urgency="high" if abs(temp_trend["slope"]) > 1.0 else "medium",
                        confidence=temp_trend["confidence"],
                        timeline="Within 48 hours",
                        action="Check HVAC performance and calibration",
                        cost_estimate="$200-600",
                        risk_level="System inefficiency or failure",
                        room=room,
                        component="DHT22"
                    ))
            
            # Voltage trends
            if "voltage" in group.columns:
                voltage_trend = self._calculate_trend(group["voltage"])
                if abs(voltage_trend["slope"]) > 5:
                    direction = "increasing" if voltage_trend["slope"] > 0 else "decreasing"
                    suggestions.append(MaintenanceAlert(
                        equipment=equipment,
                        issue=f"Voltage trending {direction}: {abs(voltage_trend['slope']):.1f}V/day",
                        urgency="high",
                        confidence=voltage_trend["confidence"],
                        timeline="Within 24 hours",
                        action="Inspect electrical supply and connections",
                        cost_estimate="$200-600",
                        risk_level="Electrical system instability",
                        room=room,
                        component="PZEM"
                    ))
        
        return suggestions
    
    def _calculate_trend(self, data: pd.Series) -> Dict[str, float]:
        """Calculate trend slope and confidence."""
        if len(data) < 2 or data.isna().all():
            return {"slope": 0, "confidence": 0}
        
        x = np.arange(len(data))
        y = data.dropna().values
        
        if len(y) < 2:
            return {"slope": 0, "confidence": 0}
        
        slope = np.polyfit(x, y, 1)[0]
        correlation = np.corrcoef(x, y)[0, 1] if len(set(y)) > 1 else 0
        confidence = abs(correlation)
        
        return {"slope": slope, "confidence": min(confidence, 1.0)}
    
    def generate_energy_insights(self, df: pd.DataFrame) -> List[EnergyInsight]:
        """Generate comprehensive energy efficiency insights with detailed analysis."""
        df = self.preprocess_data(df)
        insights = []
        
        if df.empty:
            logger.warning("Empty DataFrame for energy insights")
            # Return a default insight instead of empty list
            insights.append(EnergyInsight(
                metric="Data Availability",
                current_value=0,
                trend="No data",
                benchmark=0,
                opportunity="Collect more sensor data",
                potential_savings="Unknown",
                recommendation="Ensure sensors are properly configured and transmitting data",
                room="All Rooms"
            ))
            return insights
        
        # Calculate overall energy metrics
        total_energy = df["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in df.columns else 0
        total_power = df["power_consumption_watts.total"].sum() if "power_consumption_watts.total" in df.columns else 0
        avg_power = df["power_consumption_watts.total"].mean() if "power_consumption_watts.total" in df.columns else 0
        
        # Calculate cost metrics
        cost_per_kwh = self.insights_config.get("default_cost_per_kwh", 0.15)
        total_cost = total_energy * cost_per_kwh
        
        # Generate overall energy insights
        if total_energy > 0:
            # Insight 1: Total Energy Consumption
            insights.append(EnergyInsight(
                metric="Total Energy Consumption",
                current_value=total_energy,
                trend="Cumulative",
                benchmark=total_energy * 0.9,  # 10% reduction target
                opportunity="Reduce overall consumption by 10%",
                potential_savings=f"${total_cost * 0.1:.2f}",
                recommendation="Implement energy monitoring and optimize equipment schedules",
                room="All Rooms"
            ))
            
            # Insight 2: Average Power Usage
            insights.append(EnergyInsight(
                metric="Average Power Usage",
                current_value=avg_power,
                trend="Operational baseline",
                benchmark=avg_power * 0.85,  # 15% efficiency target
                opportunity="Improve equipment efficiency",
                potential_savings="15-25% power reduction",
                recommendation="Regular maintenance and equipment upgrades",
                room="All Rooms"
            ))
        
        # Analyze by room for specific insights
        if 'room_name' in df.columns:
            grouped = df.groupby('room_name')
            
            for room, group in grouped:
                room_energy = group["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in group.columns else 0
                room_power_avg = group["power_consumption_watts.total"].mean() if "power_consumption_watts.total" in group.columns else 0
                room_occupancy = group["occupancy_count"].mean() if "occupancy_count" in group.columns else 0
                
                if room_energy > 0:
                    # Room-specific energy efficiency
                    insights.append(EnergyInsight(
                        metric=f"Room {room} Energy",
                        current_value=room_energy,
                        trend="Room-specific",
                        benchmark=room_energy * 0.9,
                        opportunity="Room-specific optimization",
                        potential_savings=f"${room_energy * cost_per_kwh * 0.1:.2f}",
                        recommendation=f"Review {room} equipment usage patterns",
                        room=room
                    ))
                
                # Power per occupant insight
                if room_occupancy > 0 and room_power_avg > 0:
                    power_per_person = room_power_avg / room_occupancy
                    insights.append(EnergyInsight(
                        metric=f"Power per Person - {room}",
                        current_value=power_per_person,
                        trend="Efficiency metric",
                        benchmark=150,  # Target watts per person
                        opportunity="Optimize occupancy-based controls",
                        potential_savings="20-30% with smart controls",
                        recommendation=f"Implement occupancy sensors in {room}",
                        room=room
                    ))
        
        # Equipment usage insights
        equipment_columns = [
            "equipment_usage.lights_on_hours",
            "equipment_usage.air_conditioner_on_hours", 
            "equipment_usage.projector_on_hours",
            "equipment_usage.computer_on_hours"
        ]
        
        for eq_col in equipment_columns:
            if eq_col in df.columns:
                avg_hours = df[eq_col].mean()
                equipment_name = eq_col.split('.')[-1].replace('_on_hours', '').replace('_', ' ').title()
                
                if avg_hours > 0:
                    insights.append(EnergyInsight(
                        metric=f"{equipment_name} Usage",
                        current_value=avg_hours,
                        trend="Equipment runtime",
                        benchmark=avg_hours * 0.8,  # 20% reduction target
                        opportunity=f"Optimize {equipment_name.lower()} scheduling",
                        potential_savings=f"Reduce runtime by {avg_hours * 0.2:.1f} hours",
                        recommendation=f"Implement smart controls for {equipment_name.lower()}",
                        room="All Rooms"
                    ))
        
        # Environmental insights
        if "environmental_data.temperature_celsius" in df.columns:
            avg_temp = df["environmental_data.temperature_celsius"].mean()
            temp_std = df["environmental_data.temperature_celsius"].std()
            
            insights.append(EnergyInsight(
                metric="Temperature Stability",
                current_value=temp_std,  # Lower std = more stable
                trend="Environmental control",
                benchmark=2.0,  # Target temperature stability
                opportunity="Improve HVAC efficiency",
                potential_savings="10-15% HVAC energy",
                recommendation="Maintain consistent temperature setpoints",
                room="All Rooms"
            ))
        
        # Peak demand analysis
        if "power_consumption_watts.total" in df.columns:
            peak_power = df["power_consumption_watts.total"].max()
            avg_power = df["power_consumption_watts.total"].mean()
            peak_ratio = peak_power / avg_power if avg_power > 0 else 1
            
            if peak_ratio > 2:
                insights.append(EnergyInsight(
                    metric="Peak Demand Management",
                    current_value=peak_ratio,
                    trend="Load distribution",
                    benchmark=1.5,  # Target peak-to-average ratio
                    opportunity="Reduce peak demand",
                    potential_savings="Lower demand charges",
                    recommendation="Stagger equipment startup times",
                    room="All Rooms"
                ))
        
        # If no insights were generated, provide diagnostic insight
        if not insights:
            insights.append(EnergyInsight(
                metric="Energy Data Analysis",
                current_value=len(df),
                trend="Data quality",
                benchmark=100,  # Minimum records for good analysis
                opportunity="Improve data collection",
                potential_savings="Better insights with more data",
                recommendation="Ensure all sensors are active and transmitting consistently",
                room="All Rooms"
            ))
        
        logger.info(f"Generated {len(insights)} energy insights")
        return insights
    
    def handle_most_used_room_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle 'most used room' type queries."""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for most used room query")
            return {"error": "No data available for room analysis"}
        
        # Group by room to find the most used
        grouped = df.groupby('room_name')
        room_metrics = []
        
        for room, group in grouped:
            occupied_records = group[group["occupancy_count"] > 0]
            total_records = len(group)
            occupancy_rate = (len(occupied_records) / total_records * 100) if total_records > 0 else 0
            total_occupancy_hours = occupied_records["occupancy_count"].sum()
            avg_occupancy = occupied_records["occupancy_count"].mean() if not occupied_records.empty else 0
            
            # Find peak usage time
            peak_time = "No peak usage"
            peak_occupancy = 0
            if not occupied_records.empty:
                peak_record = occupied_records.loc[occupied_records["occupancy_count"].idxmax()]
                peak_time = peak_record["timestamp"]
                peak_occupancy = peak_record["occupancy_count"]
            
            # Energy consumption during occupied periods
            energy_during_occupancy = occupied_records["energy_consumption_kwh"].sum() if not occupied_records.empty else 0
            
            room_metrics.append({
                "room": room,
                "occupancy_rate": occupancy_rate,
                "total_hours": total_occupancy_hours,
                "peak_time": str(peak_time),
                "peak_occupancy": peak_occupancy,
                "energy_usage": energy_during_occupancy,
                "avg_occupancy": avg_occupancy
            })
        
        # Find the most used room
        if room_metrics:
            most_used = max(room_metrics, key=lambda x: x["total_hours"])
            return {
                "answer": (f"Most used room: {most_used['room']} with {most_used['occupancy_rate']:.1f}% occupancy rate, "
                          f"{most_used['total_hours']:.1f} total person-hours. Peak usage: {most_used['peak_occupancy']} "
                          f"people at {most_used['peak_time']}. Energy consumption during occupied periods: "
                          f"{most_used['energy_usage']:.2f} kWh. Average occupancy when in use: {most_used['avg_occupancy']:.1f} people."),
                "metrics": most_used,
                "all_rooms": room_metrics
            }
        else:
            return {"error": "No room data available for analysis"}
    
    def handle_energy_trends_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle energy trends analysis queries."""
        df = self.preprocess_data(df)
        
        if df.empty or "energy_consumption_kwh" not in df.columns:
            logger.warning("No energy data available for trend analysis")
            return {"error": "No energy data available for trend analysis"}
        
        # Group by room for trend analysis
        grouped = df.groupby('room_name')
        room_trends = []
        
        for room, group in grouped:
            energy_data = group["energy_consumption_kwh"]
            total_energy = energy_data.sum()
            avg_daily = energy_data.mean()
            
            # Fetch billing rate
            cost_per_kwh = self.insights_config.get("default_cost_per_kwh", 0.15)
            if self.db_adapter is not None:
                try:
                    room_id = next((r['id'] for r in self.db_adapter.get_rooms_list() if r['name'] == room), None)
                    if room_id:
                        billing_rates = self.db_adapter.get_billing_rates(room_id=room_id, valid_date=datetime.now())
                        cost_per_kwh = billing_rates[0]['rate_per_kwh'] if billing_rates else cost_per_kwh
                except Exception as e:
                    logger.warning(f"Failed to fetch billing rates for {room}: {e}. Using default cost_per_kwh.")
            
            total_cost = total_energy * cost_per_kwh
            
            # Calculate trend
            trend_info = self._calculate_trend(energy_data)
            trend_direction = "Increasing" if trend_info["slope"] > 0.1 else "Decreasing" if trend_info["slope"] < -0.1 else "Stable"
            change_rate = abs(trend_info["slope"] / avg_daily * 100) if avg_daily > 0 else 0
            
            # Find peak consumption
            peak_consumption = energy_data.max()
            peak_time = group.loc[energy_data.idxmax()]["timestamp"] if not energy_data.empty else "No peak"
            
            recommendations = []
            if trend_direction == "Increasing":
                recommendations.append("Investigate equipment efficiency")
                recommendations.append("Consider energy-saving measures")
            elif change_rate > 20:
                recommendations.append("Monitor for equipment issues")
                recommendations.append("Review usage patterns")
            else:
                recommendations.append("Maintain current efficiency practices")
            
            room_trends.append({
                "room": room,
                "trend_direction": trend_direction,
                "change_rate": change_rate,
                "total_energy": total_energy,
                "avg_daily": avg_daily,
                "peak_consumption": peak_consumption,
                "peak_time": str(peak_time),
                "cost_impact": total_cost,
                "recommendations": recommendations
            })
        
        # Aggregate summary
        total_energy_all = df["energy_consumption_kwh"].sum()
        avg_cost_per_kwh = np.mean([t["cost_impact"] / t["total_energy"] for t in room_trends if t["total_energy"] > 0]) if room_trends else self.insights_config.get("default_cost_per_kwh", 0.15)
        total_cost_all = total_energy_all * avg_cost_per_kwh
        
        return {
            "answer": (f"Energy trend analysis across rooms: Total energy {total_energy_all:.2f} kWh, "
                      f"estimated cost ${total_cost_all:.2f}. Detailed room trends available."),
            "metrics": {
                "total_energy": total_energy_all,
                "total_cost": total_cost_all,
                "room_trends": room_trends
            }
        }
    
    def handle_kpi_query(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle key performance indicators query with energy insights."""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for KPI query")
            return {"error": "No data available for KPI analysis"}
        
        # Calculate basic KPIs
        total_energy = df["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in df.columns else 0
        avg_power = df["power_consumption_watts.total"].mean() if "power_consumption_watts.total" in df.columns else 0
        avg_occupancy = df["occupancy_count"].mean() if "occupancy_count" in df.columns else 0
        avg_temperature = df["environmental_data.temperature_celsius"].mean() if "environmental_data.temperature_celsius" in df.columns else 0
        
        # Calculate costs
        cost_per_kwh = self.insights_config.get("default_cost_per_kwh", 0.15)
        total_cost = total_energy * cost_per_kwh
        
        # Generate energy insights
        energy_insights = self.generate_energy_insights(df)
        
        # Energy efficiency metrics
        energy_per_person = total_energy / avg_occupancy if avg_occupancy > 0 else 0
        power_variance = df["power_consumption_watts.total"].std() if "power_consumption_watts.total" in df.columns else 0
        
        # Equipment usage
        equipment_metrics = {}
        for col in ["equipment_usage.lights_on_hours", "equipment_usage.air_conditioner_on_hours"]:
            if col in df.columns:
                eq_name = col.split('.')[-1].replace('_on_hours', '').replace('_', ' ').title()
                equipment_metrics[eq_name] = df[col].mean()
        
        # Format equipment metrics
        equipment_summary = ", ".join([f"{k}: {v:.1f}h" for k, v in equipment_metrics.items()])
        
        # Compile KPI answer with energy insights
        kpi_parts = [
            "**Key Performance Indicators - Energy Management**",
            "",
            "**Core Metrics:**",
            f"• Total Energy: {total_energy:.1f} kWh (${total_cost:.2f})",
            f"• Average Power: {avg_power:.1f} W",
            f"• Average Occupancy: {avg_occupancy:.1f} people",
            f"• Average Temperature: {avg_temperature:.1f}°C",
            "",
            "**Efficiency Metrics:**",
            f"• Energy per Person: {energy_per_person:.3f} kWh/person",
            f"• Power Stability: {power_variance:.1f} W variance",
            f"• Equipment Usage: {equipment_summary}",
            "",
            "**Energy Insights:**"
        ]
        
        # Add top 3 energy insights
        if energy_insights:
            for i, insight in enumerate(energy_insights[:3]):
                kpi_parts.append(f"• {insight.metric}: {insight.current_value:.1f} - {insight.recommendation}")
        else:
            kpi_parts.append("• No specific energy insights available")
        
        answer = "\n".join(kpi_parts)
        
        return {
            "answer": answer,
            "metrics": {
                "total_energy": total_energy,
                "total_cost": total_cost,
                "avg_power": avg_power,
                "avg_occupancy": avg_occupancy,
                "energy_efficiency": energy_per_person,
                "energy_insights_count": len(energy_insights)
            },
            "energy_insights": [
                {
                    "metric": i.metric,
                    "value": i.current_value,
                    "recommendation": i.recommendation,
                    "potential_savings": i.potential_savings
                } for i in energy_insights
            ]
        }
    
    def generate_weekly_summary(self, df: pd.DataFrame) -> Dict[str, Any]:
        """Generate comprehensive weekly summary with proper energy insights."""
        df = self.preprocess_data(df)
        
        if df.empty:
            logger.warning("Empty DataFrame for weekly summary")
            return {"error": "No data available for weekly summary"}
        
        # Calculate basic metrics
        total_energy = df["energy_consumption_kwh"].sum() if "energy_consumption_kwh" in df.columns else 0
        total_power = df["power_consumption_watts.total"].sum() if "power_consumption_watts.total" in df.columns else 0
        avg_occupancy = df["occupancy_count"].mean() if "occupancy_count" in df.columns else 0
        
        # Calculate costs
        cost_per_kwh = self.insights_config.get("default_cost_per_kwh", 0.15)
        total_cost = total_energy * cost_per_kwh
        
        # Generate energy insights
        energy_insights = self.generate_energy_insights(df)
        
        # Format energy insights for the summary
        energy_analysis = "Energy Analysis:\n"
        if energy_insights:
            for i, insight in enumerate(energy_insights[:5]):  # Show top 5 insights
                energy_analysis += f"• {insight.metric}: {insight.current_value:.1f} {insight.trend.lower()} - {insight.recommendation}\n"
        else:
            energy_analysis += "• No specific energy insights available from current data\n"
        
        # Detect anomalies
        anomalies = self.detect_anomalies(df)
        anomaly_summary = f"Anomalies detected: {len(anomalies)}"
        if anomalies:
            critical_anomalies = [a for a in anomalies if a.severity in ["Critical", "High"]]
            anomaly_summary += f" ({len(critical_anomalies)} require attention)"
        
        # Generate maintenance suggestions
        maintenance_alerts = self.generate_maintenance_suggestions(df, anomalies)
        maintenance_summary = f"Maintenance items: {len(maintenance_alerts)}"
        if maintenance_alerts:
            urgent_maintenance = [m for m in maintenance_alerts if m.urgency in ["critical", "high"]]
            maintenance_summary += f" ({len(urgent_maintenance)} urgent)"
        
        # Room-specific analysis
        room_analysis = ""
        if 'room_name' in df.columns:
            room_stats = df.groupby('room_name').agg({
                'energy_consumption_kwh': 'sum',
                'occupancy_count': 'mean',
                'power_consumption_watts.total': 'mean'
            }).round(2)
            
            room_analysis = "\nRoom Breakdown:\n"
            for room, stats in room_stats.iterrows():
                room_cost = stats['energy_consumption_kwh'] * cost_per_kwh
                room_analysis += f"• {room}: {stats['energy_consumption_kwh']:.1f} kWh (${room_cost:.2f}), {stats['occupancy_count']:.1f} avg people\n"
        
        # Compile final summary
        summary_parts = [
            f"📊 Weekly Facility Summary",
            f"Total Energy: {total_energy:.1f} kWh (${total_cost:.2f})",
            f"Average Power: {total_power/len(df) if len(df) > 0 else 0:.1f} W",
            f"Average Occupancy: {avg_occupancy:.1f} people",
            f"Records Analyzed: {len(df)}",
            anomaly_summary,
            maintenance_summary,
            "",
            energy_analysis,
            room_analysis
        ]
        
        answer = "\n".join(summary_parts)
        
        return {
            "answer": answer,
            "summary": {
                "total_energy": total_energy,
                "total_cost": total_cost,
                "avg_occupancy": avg_occupancy,
                "alert_count": len(anomalies),
                "maintenance_count": len(maintenance_alerts),
                "energy_insights_count": len(energy_insights)
            },
            "energy_insights": [
                {
                    "metric": i.metric,
                    "value": i.current_value,
                    "trend": i.trend,
                    "opportunity": i.opportunity,
                    "potential_savings": i.potential_savings,
                    "recommendation": i.recommendation,
                    "room": i.room
                } for i in energy_insights
            ]
        }
    
    def handle_context_aware_query(self, query: str, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle context-aware queries that consider current conditions and trends."""
        df = self.preprocess_data(df)
        current_time = datetime.now()
        
        # Analyze current context
        context = {
            "time_of_day": current_time.hour,
            "day_of_week": current_time.weekday(),
            "season": self._get_season(current_time),
            "data_timespan": self._get_data_timespan(df)
        }
        
        # Get latest conditions by room
        room_contexts = []
        if not df.empty:
            grouped = df.groupby('room_name')
            for room, group in grouped:
                latest_record = group.iloc[-1]
                room_context = {
                    "room": room,
                    "current_occupancy": latest_record.get("occupancy_count", 0),
                    "current_temperature": latest_record.get("environmental_data.temperature_celsius", 0),
                    "current_power": latest_record.get("power_consumption_watts.total", 0),
                    "current_voltage": latest_record.get("voltage", 0)
                }
                room_contexts.append(room_context)
        
        # Detect anomalies
        anomalies = self.detect_anomalies(df)
        
        # Generate context-aware insights
        context_insights = []
        for room_context in room_contexts:
            room = room_context["room"]
            if context["time_of_day"] < 8 or context["time_of_day"] > 18:
                context_insights.append(f"{room}: Outside normal business hours - monitor for unnecessary energy usage")
            
            if context["season"] in ["summer", "winter"]:
                context_insights.append(f"{room}: Peak {context['season']} season - expect higher HVAC usage")
            
            if room_context["current_temperature"] > 26:
                context_insights.append(f"{room}: High temperature ({room_context['current_temperature']:.1f}°C) - cooling system may be under stress")
            elif room_context["current_temperature"] < 18:
                context_insights.append(f"{room}: Low temperature ({room_context['current_temperature']:.1f}°C) - heating system active")
            
            if room_context["current_voltage"] < 200 or room_context["current_voltage"] > 240:
                context_insights.append(f"{room}: Voltage ({room_context['current_voltage']:.1f}V) outside normal range - check electrical system")
        
        return {
            "answer": (f"Context-aware analysis for {current_time.strftime('%Y-%m-%d %H:%M:%S')}: "
                      f"{', '.join(context_insights) if context_insights else 'Normal operating conditions detected'}. "
                      f"{len(anomalies)} anomalies found in recent data."),
            "context": context,
            "room_contexts": room_contexts,
            "insights": context_insights,
            "anomalies": len(anomalies),
            "recommendations": self._get_context_recommendations(context, anomalies)
        }
    
    def _get_season(self, date: datetime) -> str:
        """Determine season based on date."""
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
        """Get timespan of data."""
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
    
    def _get_context_recommendations(self, context: Dict[str, Any], anomalies: List[AnomalyDetection]) -> List[str]:
        """Generate recommendations based on context and anomalies."""
        recommendations = []
        
        if context["time_of_day"] < 8 or context["time_of_day"] > 18:
            recommendations.append("Reduce non-essential equipment usage during off-hours")
        
        if context["season"] in ["summer", "winter"]:
            recommendations.append("Optimize HVAC settings for seasonal efficiency")
        
        for anomaly in anomalies:
            if anomaly.severity in ["High", "Critical"]:
                recommendations.append(f"Urgent: Address {anomaly.anomaly_type} issue in {anomaly.location}")
        
        return recommendations
    
    def handle_query(self, query: str, df: pd.DataFrame) -> Dict[str, Any]:
        """Route queries to appropriate handlers."""
        query = query.lower().strip()
        if any(k in query for k in ["key performance indicators", "kpi", "performance metrics"]):
            return self.handle_kpi_query(df)
        elif "energy trends" in query:
            return self.handle_energy_trends_query(df)
        elif "most used room" in query:
            return self.handle_most_used_room_query(df)
        elif "weekly summary" in query:
            return self.generate_weekly_summary(df)
        elif "current status" in query:
            return self.handle_context_aware_query(query, df)
        else:
            logger.warning(f"No deterministic match for query: '{query}'; falling back to LLM")
            return {"error": "Query not supported, falling back to LLM"}