from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
import pandas as pd
import numpy as np
import logging
from datetime import datetime

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
    impact: str = ""
    recommendation: str = ""

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
            "power_anomaly_threshold": 2.0,  # Increased threshold to reduce false positives
            "temperature_anomaly_range": [18, 27],
            "humidity_anomaly_range": {
                "office": [30, 60],
                "conference": [30, 60],
                "lab": [30, 65],
                "server": [40, 60],
                "default": [25, 70]
            },
            "runtime_anomaly_threshold": 12,
            "current_anomaly_range": [0, 5],
            "voltage_anomaly_range": [200, 240],
            "power_anomaly_range": [0, 2000],
            "energy_spike_threshold": 2.5,  # Increased threshold
            "occupancy_anomaly_threshold": 2.5,  # Increased threshold
            "working_hours": {
                "start": 8,  # 8 AM
                "end": 18,   # 6 PM
                "weekdays": [0, 1, 2, 3, 4]  # Monday to Friday
            },
            "motion_cooldown_minutes": 15,  # Minimum minutes between motion alerts
            "min_confidence_threshold": 0.7  # Minimum confidence to report an anomaly
        })
        self.insights_config = prompts_config.get_all_prompts().get("insights_config", {
            "default_cost_per_kwh": 0.15
        })
        self.db_adapter = database_adapter
        if self.db_adapter is None:
            logger.warning("No DatabaseAdapter provided - using default cost per kWh and no room-specific billing rates")
        else:
            # Build a cache of room name -> id for quick billing lookups
            try:
                self._room_name_to_id = {}
                rooms = self.db_adapter.get_rooms_list()
                for r in rooms:
                    name = r.get('name')
                    rid = r.get('id')
                    if name and rid:
                        self._room_name_to_id[name] = rid
            except Exception as e:
                logger.warning(f"Unable to cache rooms for billing lookup: {e}")
                self._room_name_to_id = {}

        # Simple memo cache for (room_id, day) -> php_rate
        self._billing_rate_cache = {}

    def _get_php_rate_for_time(self, room_name: str, timestamp: Any) -> float:
        """Return PHP rate per kWh for a room at timestamp, with fallbacks."""
        # Default fallback: convert configured USD to PHP
        default_php = self.insights_config.get("default_cost_per_kwh", 0.15) * 56
        if self.db_adapter is None or timestamp is None:
            return default_php

        try:
            ts = pd.to_datetime(timestamp, errors='coerce')
            if pd.isna(ts):
                return default_php
            day_key = ts.strftime('%Y-%m-%d')
            room_id = self._room_name_to_id.get(room_name)
            cache_key = (room_id or 'GLOBAL', day_key)
            if cache_key in self._billing_rate_cache:
                return self._billing_rate_cache[cache_key]

            # Prefer room-specific, else global (room NULL)
            rates_df = self.db_adapter.get_billing_rates_dataframe(room_id=room_id, active_at=ts)
            if rates_df is None or rates_df.empty:
                rates_df = self.db_adapter.get_billing_rates_dataframe(room_id=None, active_at=ts)

            if rates_df is not None and not rates_df.empty:
                # Use latest created rate
                row = rates_df.iloc[0]
                currency = (row.get('currency') or 'PHP').upper()
                rate = float(row.get('rate_per_kwh') or 0)
                php_rate = rate if currency == 'PHP' else rate * 56
                if php_rate <= 0:
                    php_rate = default_php
                self._billing_rate_cache[cache_key] = php_rate
                return php_rate

            return default_php
        except Exception as e:
            logger.warning(f"Billing rate lookup failed, using default: {e}")
            return default_php
    
    def _safe_timestamp_conversion(self, timestamp_value) -> str:
        """Safely convert timestamp to string, handling NaT and None values."""
        if pd.isna(timestamp_value) or timestamp_value is None:
            return "Unknown timestamp"
        
        try:
            if isinstance(timestamp_value, pd.Timestamp):
                return timestamp_value.strftime('%Y-%m-%d %H:%M:%S')
            elif isinstance(timestamp_value, (datetime, np.datetime64)):
                return pd.Timestamp(timestamp_value).strftime('%Y-%m-%d %H:%M:%S')
            else:
                return str(timestamp_value)
        except (ValueError, AttributeError) as e:
            logger.warning(f"Error converting timestamp {timestamp_value}: {e}")
            return "Invalid timestamp"
    
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
        
        # Convert timestamp to datetime with proper error handling
        if 'timestamp' in df.columns:
            try:
                df['timestamp'] = pd.to_datetime(df['timestamp'], errors='coerce')
                # Count NaT values for logging
                nat_count = df['timestamp'].isna().sum()
                if nat_count > 0:
                    logger.warning(f"Found {nat_count} invalid timestamp values that were converted to NaT")
            except Exception as e:
                logger.error(f"Error converting timestamp column: {e}")
                # Create a default timestamp if conversion fails
                df['timestamp'] = pd.Timestamp.now()
        
        # Remove duplicates based on key columns (excluding timestamp if it has NaT values)
        key_columns = ["equipment_name", "room_name", "component_type"]
        valid_timestamps = df['timestamp'].notna() if 'timestamp' in df.columns else pd.Series([True] * len(df))
        
        if valid_timestamps.any():
            # If we have valid timestamps, include them in deduplication
            key_columns_with_timestamp = ["timestamp"] + key_columns
            df_valid = df[valid_timestamps].drop_duplicates(subset=[col for col in key_columns_with_timestamp if col in df.columns])
            df_invalid = df[~valid_timestamps]
            df = pd.concat([df_valid, df_invalid], ignore_index=True)
        else:
            # If all timestamps are invalid, deduplicate without timestamp
            df = df.drop_duplicates(subset=[col for col in key_columns if col in df.columns])
        
        logger.info(f"DataFrame shape after deduplication: {df.shape}")
        
        # Check for zeroed data
        numeric_cols = [col for col in df.columns if col.startswith(("power_consumption_watts", "energy_consumption_kwh", 
                                                                    "environmental_data", "equipment_usage", 
                                                                    "current", "energy", "power", "voltage"))]
        if numeric_cols:
            zero_percentage = (df[numeric_cols] == 0).mean().mean() * 100
            if zero_percentage > 50:
                logger.warning(f"High percentage of zero values in numeric columns: {zero_percentage:.1f}% - Possible test data or sensor issues")
        
        return df
    
    def detect_anomalies(self, df: pd.DataFrame) -> List[AnomalyDetection]:
        """Enhanced anomaly detection in the sensor data with comprehensive analysis."""
        df = self.preprocess_data(df)
        anomalies = []
        
        if df.empty:
            logger.warning("No data available for anomaly detection")
            return anomalies
        
        # Filter out rows with invalid timestamps for time-based analysis
        df_valid_timestamps = df[df['timestamp'].notna()] if 'timestamp' in df.columns else df
        
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
            
            # Energy consumption anomalies
            energy_anomalies = self._detect_energy_anomalies(group, room, equipment, component)
            anomalies.extend(energy_anomalies)
            
            # Occupancy anomalies
            occupancy_anomalies = self._detect_occupancy_anomalies(group, room, equipment, component)
            anomalies.extend(occupancy_anomalies)
            
            # Pattern anomalies (correlation between metrics)
            pattern_anomalies = self._detect_pattern_anomalies(group, room, equipment, component)
            anomalies.extend(pattern_anomalies)
        
        logger.info(f"Detected {len(anomalies)} anomalies")
        return anomalies
    
    def _detect_power_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect power consumption anomalies with enhanced analysis."""
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
                severity = "Critical" if z_score > 3.0 else "High" if z_score > 2.5 else "Medium"
                
                # Determine impact and recommendation
                if power > mean_power:
                    impact = "Increased energy costs, potential equipment stress"
                    recommendation = "Investigate for equipment malfunction, check for simultaneous high-power device usage"
                else:
                    impact = "Possible equipment underperformance or sensor error"
                    recommendation = "Verify equipment operation and sensor calibration"
                
                # Use safe timestamp conversion
                timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                
                anomalies.append(AnomalyDetection(
                    anomaly_type="Power Consumption",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Power consumption {power:.1f}W is {z_score:.1f} standard deviations from normal (mean: {mean_power:.1f}W)",
                    timestamp=timestamp_str,
                    value=power,
                    expected_range=(mean_power - std_power, mean_power + std_power),
                    confidence=min(z_score / 3.0, 1.0),
                    equipment=equipment,
                    component=component,
                    impact=impact,
                    recommendation=recommendation
                ))
        
        return anomalies
    
    def _detect_temperature_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect temperature anomalies with comfort and safety analysis."""
        anomalies = []
        temp_range = self.maintenance_rules.get("temperature_anomaly_range", [18, 27])
        
        if "environmental_data.temperature_celsius" not in df.columns:
            logger.warning(f"Missing 'environmental_data.temperature_celsius' for {equipment} in {room}")
            return anomalies
        
        for idx, row in df.iterrows():
            temp = row["environmental_data.temperature_celsius"]
            
            if pd.notnull(temp):
                if temp < 15 or temp > 32:
                    severity = "Critical"
                    impact = "Risk of equipment damage, health and safety concerns"
                    recommendation = "Immediate HVAC system check and temperature adjustment required"
                elif temp < temp_range[0] or temp > temp_range[1]:
                    severity = "High"
                    impact = "Occupant discomfort, reduced productivity"
                    recommendation = "Adjust HVAC settings to maintain comfortable temperature range"
                else:
                    continue
                
                # Use safe timestamp conversion
                timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                
                anomalies.append(AnomalyDetection(
                    anomaly_type="Temperature",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Temperature {temp:.1f}°C is outside {'safe' if severity == 'Critical' else 'optimal'} range {temp_range}",
                    timestamp=timestamp_str,
                    value=temp,
                    expected_range=(temp_range[0], temp_range[1]),
                    confidence=0.9,
                    equipment=equipment,
                    component=component,
                    impact=impact,
                    recommendation=recommendation
                ))
        
        return anomalies
    
    def _detect_humidity_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect humidity anomalies with mold and comfort analysis."""
        anomalies = []
        humidity_range = self.maintenance_rules.get("humidity_anomaly_range", [25, 70])
        
        if "environmental_data.humidity_percent" not in df.columns:
            logger.warning(f"Missing 'environmental_data.humidity_percent' for {equipment} in {room}")
            return anomalies
        
        for idx, row in df.iterrows():
            humidity = row["environmental_data.humidity_percent"]
            
            if pd.notnull(humidity):
                if humidity > 80:
                    severity = "Critical"
                    impact = "High risk of mold growth, equipment corrosion"
                    recommendation = "Immediate dehumidification required, check for water leaks"
                elif humidity < 20:
                    severity = "High"
                    impact = "Dry air causing discomfort, static electricity risks"
                    recommendation = "Use humidifiers, adjust HVAC settings"
                elif humidity < humidity_range[0] or humidity > humidity_range[1]:
                    severity = "Medium"
                    impact = "Suboptimal comfort levels"
                    recommendation = "Adjust humidity control systems"
                else:
                    continue
                
                # Use safe timestamp conversion
                timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                
                anomalies.append(AnomalyDetection(
                    anomaly_type="Humidity",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Humidity {humidity:.1f}% is outside {'safe' if severity == 'Critical' else 'optimal'} range {humidity_range}",
                    timestamp=timestamp_str,
                    value=humidity,
                    expected_range=(humidity_range[0], humidity_range[1]),
                    confidence=0.8,
                    equipment=equipment,
                    component=component,
                    impact=impact,
                    recommendation=recommendation
                ))
        
        return anomalies
    
    def _detect_energy_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect energy consumption anomalies with cost impact analysis in Philippine Pesos."""
        anomalies = []
        threshold = self.maintenance_rules.get("energy_spike_threshold", 2.0)
        
        if "energy_consumption_kwh" not in df.columns:
            return anomalies
        
        energy_data = df["energy_consumption_kwh"]
        mean_energy = energy_data.mean()
        std_energy = energy_data.std()
        
        if std_energy == 0:
            return anomalies
        
        # Convert cost to Philippine Pesos (approximately 1 USD = 56 PHP)
        # Determine billing rate (PHP) once per group using first valid timestamp
        first_ts = None
        if 'timestamp' in df.columns:
            valid_ts = df['timestamp'].dropna()
            if len(valid_ts) > 0:
                first_ts = valid_ts.iloc[0]
        cost_per_kwh_php = self._get_php_rate_for_time(room, first_ts)
        
        for idx, row in df.iterrows():
            energy = row["energy_consumption_kwh"]
            z_score = abs((energy - mean_energy) / std_energy)
            
            if z_score > threshold:
                severity = "Critical" if z_score > 3.0 else "High" if z_score > 2.0 else "Medium"
                cost_impact_php = energy * cost_per_kwh_php
                
                if energy > mean_energy:
                    impact = f"High energy consumption costing ₱{cost_impact_php:.2f} PHP"
                    recommendation = "Investigate for equipment left running, inefficient operation, or scheduling issues"
                else:
                    impact = "Unusually low energy consumption"
                    recommendation = "Verify equipment functionality and sensor accuracy"
                
                # Use safe timestamp conversion
                timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                
                anomalies.append(AnomalyDetection(
                    anomaly_type="Energy Consumption",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Energy consumption {energy:.2f}kWh is {z_score:.1f} std deviations from normal",
                    timestamp=timestamp_str,
                    value=energy,
                    expected_range=(mean_energy - std_energy, mean_energy + std_energy),
                    confidence=min(z_score / 3.0, 1.0),
                    equipment=equipment,
                    component=component,
                    impact=impact,
                    recommendation=recommendation
                ))
        
        return anomalies
    
    def _detect_occupancy_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect occupancy pattern anomalies."""
        anomalies = []
        threshold = self.maintenance_rules.get("occupancy_anomaly_threshold", 2.0)
        
        if "occupancy_count" not in df.columns:
            return anomalies
        
        occupancy_data = df["occupancy_count"]
        mean_occupancy = occupancy_data.mean()
        std_occupancy = occupancy_data.std()
        
        if std_occupancy == 0:
            return anomalies
        
        # Check energy usage during occupancy anomalies
        energy_data = df["energy_consumption_kwh"] if "energy_consumption_kwh" in df.columns else pd.Series([0] * len(df))
        
        for idx, row in df.iterrows():
            occupancy = row["occupancy_count"]
            energy = energy_data.iloc[idx] if idx < len(energy_data) else 0
            z_score = abs((occupancy - mean_occupancy) / std_occupancy)
            
            if z_score > threshold:
                severity = "High" if z_score > 2.5 else "Medium"
                
                if occupancy > mean_occupancy:
                    impact = "Overcrowding detected, potential comfort and safety issues"
                    recommendation = "Consider room capacity limits and ventilation requirements"
                else:
                    impact = "Low occupancy with potential energy waste"
                    recommendation = "Optimize equipment usage based on actual occupancy"
                
                # Use safe timestamp conversion
                timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                
                anomalies.append(AnomalyDetection(
                    anomaly_type="Occupancy",
                    severity=severity,
                    location=f"{room} - {equipment} ({component})",
                    description=f"Occupancy {occupancy} people is {z_score:.1f} std deviations from normal",
                    timestamp=timestamp_str,
                    value=occupancy,
                    expected_range=(max(0, mean_occupancy - std_occupancy), mean_occupancy + std_occupancy),
                    confidence=min(z_score / 3.0, 1.0),
                    equipment=equipment,
                    component=component,
                    impact=impact,
                    recommendation=recommendation
                ))
        
        return anomalies
    
    def _detect_pattern_anomalies(self, df: pd.DataFrame, room: str, equipment: str, component: str) -> List[AnomalyDetection]:
        """Detect anomalies in patterns and correlations between metrics."""
        anomalies = []
        
        # Check for occupancy-energy mismatch
        if "occupancy_count" in df.columns and "energy_consumption_kwh" in df.columns:
            occupancy = df["occupancy_count"]
            energy = df["energy_consumption_kwh"]
            
            # Calculate energy per occupant
            energy_per_occupant = energy / (occupancy + 1)  # +1 to avoid division by zero
            mean_energy_per_occupant = energy_per_occupant.mean()
            std_energy_per_occupant = energy_per_occupant.std()
            
            for idx, row in df.iterrows():
                epo = energy_per_occupant.iloc[idx]
                occ = occupancy.iloc[idx]
                energy_val = energy.iloc[idx]
                
                # High energy per occupant when room is occupied
                if occ > 0 and epo > mean_energy_per_occupant + 2 * std_energy_per_occupant:
                    # Use safe timestamp conversion
                    timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                    
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Energy Efficiency",
                        severity="Medium",
                        location=f"{room} - {equipment} ({component})",
                        description=f"High energy usage per person: {epo:.2f} kWh/person with {occ} occupants",
                        timestamp=timestamp_str,
                        value=epo,
                        expected_range=(0, mean_energy_per_occupant + std_energy_per_occupant),
                        confidence=0.7,
                        equipment=equipment,
                        component=component,
                        impact="Inefficient energy usage per occupant",
                        recommendation="Optimize equipment usage and implement occupancy-based controls"
                    ))
                
                # Energy usage when room is empty
                if occ == 0 and energy_val > mean_energy_per_occupant:
                    # Use safe timestamp conversion
                    timestamp_str = self._safe_timestamp_conversion(row.get('timestamp'))
                    
                    anomalies.append(AnomalyDetection(
                        anomaly_type="Energy Waste",
                        severity="Medium",
                        location=f"{room} - {equipment} ({component})",
                        description=f"Energy consumption {energy_val:.2f} kWh in unoccupied room",
                        timestamp=timestamp_str,
                        value=energy_val,
                        expected_range=(0, mean_energy_per_occupant),
                        confidence=0.8,
                        equipment=equipment,
                        component=component,
                        impact="Unnecessary energy consumption",
                        recommendation="Check for equipment left running or scheduling issues"
                    ))

        # Motion detection after hours
        if len(df) > 1 and 'timestamp' in df.columns and 'occupancy_count' in df.columns:
            df = df.sort_values('timestamp')
            current_time = df['timestamp'].iloc[-1]
            
            if not self._is_working_hours(current_time):
                # Get motion detections in the last 2 hours
                recent_motion = df[
                    (df['timestamp'] >= current_time - pd.Timedelta(hours=2)) &
                    (df['occupancy_count'] > 0)
                ]
                
                if not recent_motion.empty:
                    # Require more detections to trigger higher severity
                    detection_count = len(recent_motion)
                    confidence = min(0.9, 0.3 + (detection_count * 0.1))  # Lower base confidence
                    min_confidence = self.maintenance_rules.get("min_confidence_threshold", 0.7)
                    
                    # Only create alert if we have enough confidence
                    if confidence >= min_confidence:
                        # Higher threshold for High severity
                        if detection_count >= 5:  # Was 3
                            severity = "High"
                        elif detection_count >= 3:  # New Medium threshold
                            severity = "Medium"
                        else:
                            severity = "Low"
                            
                        anomalies.append(AnomalyDetection(
                            anomaly_type="Motion_After_Hours",
                            severity=severity,
                            location=room,
                            description=f"Motion detected outside working hours at {current_time.strftime('%H:%M')} "
                                      f"({detection_count} detections in 2h window)",
                            timestamp=self._safe_timestamp_conversion(current_time),
                            value=detection_count,
                            expected_range=(0, 0),  # Expect no motion after hours
                            confidence=confidence,
                            equipment=equipment,
                            component=component,
                            impact="Potential security concern or cleaning crew" if severity in ["High", "Medium"] else "Likely normal activity",
                            recommendation=("Verify if this is expected activity (e.g., cleaning, maintenance) "
                                         "or investigate potential security issue" if severity in ["High", "Medium"]
                                         else "No action required - likely normal activity")
                        ))
        
        return anomalies
    
    def generate_anomaly_report(self, anomalies: List[AnomalyDetection]) -> str:
        """Generate a comprehensive anomaly report with actionable insights."""
        if not anomalies:
            return "✅ No anomalies detected. All systems are operating within normal parameters."
        
        # Group by severity
        critical_anomalies = [a for a in anomalies if a.severity == "Critical"]
        high_anomalies = [a for a in anomalies if a.severity == "High"]
        medium_anomalies = [a for a in anomalies if a.severity == "Medium"]
        
        report = [
            "🚨 **ANOMALY DETECTION REPORT**",
            f"Total anomalies detected: {len(anomalies)}",
            ""
        ]
        
        if critical_anomalies:
            report.extend([
                "🔴 **CRITICAL ANOMALIES (Immediate Action Required)**",
                "These issues require immediate attention to prevent equipment damage or safety hazards:",
                ""
            ])
            for anomaly in critical_anomalies:
                report.extend([
                    f"**{anomaly.anomaly_type}** - {anomaly.timestamp}",
                    f"📍 Location: {anomaly.location}",
                    f"📊 Value: {anomaly.value} (Expected: {anomaly.expected_range[0]:.1f}-{anomaly.expected_range[1]:.1f})",
                    f"⚠️ Impact: {anomaly.impact}",
                    f"🔧 Recommendation: {anomaly.recommendation}",
                    ""
                ])
        
        if high_anomalies:
            report.extend([
                "🟠 **HIGH PRIORITY ANOMALIES**",
                "Address these issues within 24 hours to prevent escalation:",
                ""
            ])
            for anomaly in high_anomalies:
                report.extend([
                    f"**{anomaly.anomaly_type}** - {anomaly.timestamp}",
                    f"📍 Location: {anomaly.location}",
                    f"📊 Value: {anomaly.value} (Expected: {anomaly.expected_range[0]:.1f}-{anomaly.expected_range[1]:.1f})",
                    f"⚠️ Impact: {anomaly.impact}",
                    f"🔧 Recommendation: {anomaly.recommendation}",
                    ""
                ])
        
        if medium_anomalies:
            report.extend([
                "🟡 **MEDIUM PRIORITY ANOMALIES**",
                "Monitor these issues and address during next maintenance cycle:",
                ""
            ])
            for anomaly in medium_anomalies:
                report.extend([
                    f"**{anomaly.anomaly_type}** - {anomaly.timestamp}",
                    f"📍 Location: {anomaly.location}",
                    f"📊 Value: {anomaly.value} (Expected: {anomaly.expected_range[0]:.1f}-{anomaly.expected_range[1]:.1f})",
                    f"⚠️ Impact: {anomaly.impact}",
                    f"🔧 Recommendation: {anomaly.recommendation}",
                    ""
                ])
        
        # Summary and recommendations
        report.extend([
            "📋 **SUMMARY & ACTIONS**",
            f"• Critical issues: {len(critical_anomalies)}",
            f"• High priority: {len(high_anomalies)}",
            f"• Medium priority: {len(medium_anomalies)}",
            "",
            "🎯 **RECOMMENDED ACTIONS:**"
        ])
        
        # Generate overall recommendations
        if critical_anomalies:
            report.append("• **IMMEDIATE**: Address critical anomalies to prevent equipment damage and safety hazards")
        if high_anomalies:
            report.append("• **URGENT**: Schedule maintenance for high-priority issues within 24 hours")
        if any("Energy" in a.anomaly_type for a in anomalies):
            report.append("• **EFFICIENCY**: Review energy consumption patterns and optimize equipment usage")
        if any("Temperature" in a.anomaly_type for a in anomalies):
            report.append("• **COMFORT**: Adjust HVAC settings and check system performance")
        
        report.append("")
        report.append("💡 **PROACTIVE MEASURES:**")
        report.append("• Implement regular equipment maintenance schedules")
        report.append("• Consider installing smart controls for energy optimization")
        report.append("• Monitor trends to predict future maintenance needs")
        
        return "\n".join(report)

    def handle_context_aware_query(self, query: str, df: pd.DataFrame) -> Dict[str, Any]:
        """Handle context-aware queries about current room status with dynamic room names."""
        query = query.lower().strip()
        
        if any(k in query for k in ["current status", "room status", "what's the current", "how is the room"]):
            if df.empty:
                return {
                    "answer": "❌ No data available to determine current room status. Since this is incomplete, I'll assume that you meant an unoccupied room."
                }
            
            # Get the most recent data point with valid timestamp
            valid_data = df[df['timestamp'].notna()] if 'timestamp' in df.columns else df
            if valid_data.empty:
                # If no valid timestamps, use the first row
                latest_data = df.iloc[0] if not df.empty else None
            else:
                latest_data = valid_data.iloc[-1]
            
            if latest_data is None:
                return {
                    "answer": "❌ No valid data available. Since this is incomplete, I'll assume that you meant an unoccupied room."
                }
            
            # Extract room name dynamically or use default
            room_name = latest_data.get('room_name', 'Unknown Room')
            if room_name == 'Unknown Room' or room_name == 'Unknown':
                room_name = "the room"
                
            occupancy = latest_data.get('occupancy_count', 0)
            temperature = latest_data.get('environmental_data.temperature_celsius', 0.0)
            power = latest_data.get('power_consumption_watts.total', 0.0)
            
            # Determine occupancy status
            status = "unoccupied" if occupancy == 0 else "occupied"
            
            response = f"🏢 **Room Utilization:**\n\n"
            
            if room_name in ["the room", "Unknown Room", "Unknown"]:
                response += f"Since the room information is incomplete, I'll assume that you meant an unoccupied room.\n\n"
                response += f"The room is currently {status} with {occupancy} occupant(s).\n"
            else:
                response += f"**{room_name}** is currently {status} with {occupancy} occupant(s).\n"
                
            response += f"• Temperature: {temperature}°C\n"
            response += f"• Power Consumption: {power}W\n"
            
            # Add equipment status if available
            if 'equipment_name' in latest_data and latest_data['equipment_name'] != 'Unknown':
                response += f"• Active Equipment: {latest_data['equipment_name']}\n"
            
            return {"answer": response}
        
        return {"error": "Query not supported"}

    # ... (keep all other methods the same - handle_kpi_query, generate_energy_insights, handle_energy_trends_query, etc.)
    # Make sure to use self._safe_timestamp_conversion in any other methods that process timestamps

    def generate_maintenance_suggestions(self, df: pd.DataFrame, anomalies: List[AnomalyDetection]) -> List[MaintenanceAlert]:
        """
        Generate actionable maintenance suggestions based on detected anomalies and sensor data.
        Returns a list of MaintenanceAlert objects with detailed recommendations.
        """
        maintenance_alerts = []
        
        if not anomalies:
            logger.info("No anomalies detected, generating preventive maintenance suggestions")
            # Generate preventive maintenance suggestions even without anomalies
            maintenance_alerts.extend(self._generate_preventive_maintenance(df))
            return maintenance_alerts
        
        # Group anomalies by equipment and room for consolidated recommendations
        anomaly_groups = {}
        for anomaly in anomalies:
            key = (anomaly.room, anomaly.equipment, anomaly.component)
            if key not in anomaly_groups:
                anomaly_groups[key] = []
            anomaly_groups[key].append(anomaly)
        
        # Generate maintenance alerts for each equipment/room combination
        for (room, equipment, component), group_anomalies in anomaly_groups.items():
            # Sort by severity
            critical_anomalies = [a for a in group_anomalies if a.severity == "Critical"]
            high_anomalies = [a for a in group_anomalies if a.severity == "High"]
            medium_anomalies = [a for a in group_anomalies if a.severity == "Medium"]
            
            # Generate alerts based on severity
            if critical_anomalies:
                for anomaly in critical_anomalies:
                    maintenance_alerts.append(MaintenanceAlert(
                        equipment=equipment,
                        issue=f"CRITICAL: {anomaly.anomaly_type} - {anomaly.description}",
                        urgency="Critical",
                        confidence=anomaly.confidence,
                        timeline="Immediate (within 2 hours)",
                        action=anomaly.recommendation,
                        cost_estimate="High priority - immediate action required",
                        risk_level="Critical - Equipment damage or safety risk",
                        room=room,
                        component=component
                    ))
            
            if high_anomalies:
                # Consolidate high priority issues
                issue_types = set([a.anomaly_type for a in high_anomalies])
                issue_description = ", ".join(issue_types)
                primary_anomaly = high_anomalies[0]
                
                maintenance_alerts.append(MaintenanceAlert(
                    equipment=equipment,
                    issue=f"HIGH PRIORITY: {issue_description} detected",
                    urgency="High",
                    confidence=sum([a.confidence for a in high_anomalies]) / len(high_anomalies),
                    timeline="Within 24 hours",
                    action=primary_anomaly.recommendation,
                    cost_estimate="Medium - Schedule maintenance soon",
                    risk_level="High - Performance degradation likely",
                    room=room,
                    component=component
                ))
            
            if medium_anomalies and not critical_anomalies and not high_anomalies:
                # Only create medium alerts if no higher priority issues exist
                issue_types = set([a.anomaly_type for a in medium_anomalies])
                issue_description = ", ".join(issue_types)
                primary_anomaly = medium_anomalies[0]
                
                maintenance_alerts.append(MaintenanceAlert(
                    equipment=equipment,
                    issue=f"MEDIUM: {issue_description} - Monitor and schedule maintenance",
                    urgency="Medium",
                    confidence=sum([a.confidence for a in medium_anomalies]) / len(medium_anomalies),
                    timeline="Within 1 week",
                    action=primary_anomaly.recommendation,
                    cost_estimate="Low - Include in regular maintenance cycle",
                    risk_level="Medium - Monitor for escalation",
                    room=room,
                    component=component
                ))
        
        # Add preventive maintenance suggestions
        maintenance_alerts.extend(self._generate_preventive_maintenance(df))
        
        logger.info(f"Generated {len(maintenance_alerts)} maintenance suggestions")
        return maintenance_alerts
    
    def _generate_preventive_maintenance(self, df: pd.DataFrame) -> List[MaintenanceAlert]:
        """Generate preventive maintenance suggestions based on usage patterns."""
        preventive_alerts = []
        
        if df.empty:
            return preventive_alerts
        
        # Analyze equipment usage patterns
        if 'equipment_name' in df.columns and 'room_name' in df.columns:
            equipment_groups = df.groupby(['room_name', 'equipment_name'])
            
            for (room, equipment), group in equipment_groups:
                # Check for high usage equipment
                if 'equipment_usage.lights_on_hours' in group.columns:
                    avg_light_hours = group['equipment_usage.lights_on_hours'].mean()
                    if avg_light_hours > 10:
                        preventive_alerts.append(MaintenanceAlert(
                            equipment=equipment,
                            issue="High lighting usage detected - Consider LED upgrade or occupancy sensors",
                            urgency="Low",
                            confidence=0.7,
                            timeline="Next maintenance cycle (1-2 weeks)",
                            action="Evaluate lighting efficiency and consider smart controls",
                            cost_estimate="Low - Preventive measure",
                            risk_level="Low - Optimization opportunity",
                            room=room,
                            component="Lighting System"
                        ))
                
                if 'equipment_usage.air_conditioner_on_hours' in group.columns:
                    avg_ac_hours = group['equipment_usage.air_conditioner_on_hours'].mean()
                    if avg_ac_hours > 8:
                        preventive_alerts.append(MaintenanceAlert(
                            equipment=equipment,
                            issue="Extended HVAC operation - Schedule filter cleaning and system check",
                            urgency="Low",
                            confidence=0.6,
                            timeline="Next maintenance cycle (1-2 weeks)",
                            action="Clean/replace filters, check refrigerant levels, inspect coils",
                            cost_estimate="Low - Routine maintenance",
                            risk_level="Low - Preventive care",
                            room=room,
                            component="HVAC System"
                        ))
        
        return preventive_alerts

    def handle_query(self, query: str, df: pd.DataFrame) -> Dict[str, Any]:
        """Route queries to appropriate handlers with enhanced anomaly detection."""
        query = query.lower().strip()
        
        if any(k in query for k in ["detect anomalies", "find anomalies", "check for anomalies", "anomaly detection"]):
            anomalies = self.detect_anomalies(df)
            report = self.generate_anomaly_report(anomalies)
            
            return {
                "answer": report,
                "anomalies": [
                    {
                        "type": a.anomaly_type,
                        "severity": a.severity,
                        "location": a.location,
                        "description": a.description,
                        "timestamp": a.timestamp,
                        "value": a.value,
                        "impact": a.impact,
                        "recommendation": a.recommendation,
                        "confidence": a.confidence
                    } for a in anomalies
                ],
                "summary": {
                    "total_anomalies": len(anomalies),
                    "critical_count": len([a for a in anomalies if a.severity == "Critical"]),
                    "high_count": len([a for a in anomalies if a.severity == "High"]),
                    "medium_count": len([a for a in anomalies if a.severity == "Medium"])
                }
            }
        elif any(k in query for k in ["key performance indicators", "kpi", "performance metrics"]):
            return self.handle_kpi_query(df)
        elif "energy trends" in query:
            return self.handle_energy_trends_query(df)
        elif "most used room" in query:
            return self.handle_most_used_room_query(df)
        elif "weekly summary" in query:
            return self.generate_weekly_summary(df)
        elif any(k in query for k in ["current status", "room status", "what's the current room status"]):
            return self.handle_context_aware_query(query, df)
        elif "maintenance suggestions" in query:
            anomalies = self.detect_anomalies(df)
            maintenance_suggestions = self.generate_maintenance_suggestions(df, anomalies)
            return {
                "answer": "Maintenance suggestions generated",
                "maintenance_suggestions": [
                    {
                        "equipment": s.equipment,
                        "issue": s.issue,
                        "urgency": s.urgency,
                        "confidence": s.confidence,
                        "timeline": s.timeline,
                        "action": s.action,
                        "cost_estimate": s.cost_estimate,
                        "risk_level": s.risk_level,
                        "room": s.room,
                        "component": s.component
                    } for s in maintenance_suggestions
                ]
            }
        else:
            logger.warning(f"No deterministic match for query: '{query}'; falling back to LLM")
            return {"error": "Query not supported, falling back to LLM"}