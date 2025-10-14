# anomaly_detector.py
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import logging
from typing import Dict, List, Any, Optional

class AdvancedAnomalyDetector:
    """Advanced anomaly detection and predictive analysis using core_alert data"""
    
    def __init__(self, db_adapter):
        self.db_adapter = db_adapter
        self.logger = logging.getLogger(__name__)
        
    def load_alerts_data(self, days_back=30):
        """Load recent alerts data for analysis"""
        try:
            # Get alerts from last N days - use UTC time to match database
            cutoff_date = datetime.utcnow() - timedelta(days=days_back)  # FIXED: Use UTC
            query = """
            SELECT 
                id,
                type as alert_type,
                message,
                severity as severity_level,
                triggered_at as created_at,
                resolved as is_resolved,
                resolved_at,
                equipment_id
            FROM core_alert 
            WHERE triggered_at >= %s
            ORDER BY triggered_at DESC
            """
            
            # Use parameterized query to avoid SQL injection and formatting issues
            df = pd.read_sql_query(query, self.db_adapter.connection, params=[cutoff_date])
            
            # Convert timestamp columns - ensure timezone awareness
            if 'created_at' in df.columns:
                df['created_at'] = pd.to_datetime(df['created_at'], utc=True)  # FIXED: Add utc=True
            if 'resolved_at' in df.columns:
                df['resolved_at'] = pd.to_datetime(df['resolved_at'], utc=True)  # FIXED: Add utc=True
                
            self.logger.info(f"📊 Loaded {len(df)} alerts from core_alert table for analysis")
            return df
        except Exception as e:
            self.logger.error(f"❌ Error loading alerts data: {e}")
            # Return empty DataFrame with expected columns to avoid downstream errors
            return pd.DataFrame(columns=[
                'id', 'alert_type', 'message', 'severity_level', 
                'created_at', 'is_resolved', 'resolved_at', 'equipment_id'
            ])
    
    def analyze_alert_patterns(self, df):
        """Analyze patterns in alert data"""
        if df.empty:
            return {"error": "No alert data available for analysis"}
        
        analysis = {
            "summary": {},
            "trends": {},
            "patterns": {},
            "recommendations": []
        }
        
        # Basic summary statistics
        analysis["summary"]["total_alerts"] = len(df)
        analysis["summary"]["resolved_alerts"] = len(df[df['is_resolved'] == True])
        analysis["summary"]["unresolved_alerts"] = len(df[df['is_resolved'] == False])
        
        # Alert type distribution
        alert_types = df['alert_type'].value_counts()
        analysis["summary"]["alert_type_distribution"] = alert_types.to_dict()
        
        # Severity distribution
        severity_counts = df['severity_level'].value_counts()
        analysis["summary"]["severity_distribution"] = severity_counts.to_dict()
        
        # Time-based analysis
        if 'created_at' in df.columns:
            # Convert to timezone-naive for grouping operations
            df_local = df.copy()
            df_local['created_at_local'] = df_local['created_at'].dt.tz_convert(None)  # FIXED: Remove timezone for grouping
            
            df_local['date'] = df_local['created_at_local'].dt.date
            df_local['hour'] = df_local['created_at_local'].dt.hour
            df_local['day_of_week'] = df_local['created_at_local'].dt.dayofweek
            df_local['week'] = df_local['created_at_local'].dt.isocalendar().week
            
            daily_alerts = df_local.groupby('date').size()
            hourly_alerts = df_local.groupby('hour').size()
            weekly_alerts = df_local.groupby('week').size()
            weekday_alerts = df_local.groupby('day_of_week').size()
            
            analysis["patterns"]["daily_alerts"] = daily_alerts.to_dict()
            analysis["patterns"]["hourly_alerts"] = hourly_alerts.to_dict()
            analysis["patterns"]["weekly_alerts"] = weekly_alerts.to_dict()
            analysis["patterns"]["weekday_alerts"] = weekday_alerts.to_dict()
            
            # Calculate trends
            if len(daily_alerts) > 1:
                trend = (daily_alerts.iloc[-1] - daily_alerts.iloc[0]) / daily_alerts.iloc[0] * 100
                analysis["trends"]["trend_percentage"] = round(trend, 2)
                analysis["trends"]["trend_direction"] = "increasing" if trend > 0 else "decreasing"
            
            analysis["trends"]["alerts_per_day"] = round(daily_alerts.mean(), 2)
            analysis["trends"]["peak_alerts_day"] = daily_alerts.idxmax().isoformat() if not daily_alerts.empty else None
            analysis["trends"]["peak_alerts_count"] = int(daily_alerts.max()) if not daily_alerts.empty else 0
            analysis["trends"]["peak_hour"] = int(hourly_alerts.idxmax()) if not hourly_alerts.empty else None
        
        return analysis
    
    def predict_future_anomalies(self, df):
        """Predict potential future anomalies based on historical patterns"""
        if df.empty:
            return {"error": "No data for predictive analysis"}
        
        predictions = {
            "time_based_predictions": {},
            "alert_type_predictions": {},
            "risk_assessment": {}
        }
        
        # Time-based predictions
        if 'created_at' in df.columns:
            # Use timezone-naive for calculations
            df_local = df.copy()
            df_local['created_at_local'] = df_local['created_at'].dt.tz_convert(None)  # FIXED: Remove timezone
            
            df_local['hour'] = df_local['created_at_local'].dt.hour
            df_local['day_of_week'] = df_local['created_at_local'].dt.dayofweek
            
            # Peak hours analysis
            hourly_pattern = df_local.groupby('hour').size()
            if not hourly_pattern.empty:
                peak_hour = hourly_pattern.idxmax()
                predictions["time_based_predictions"]["peak_alert_hour"] = f"{peak_hour}:00 - {peak_hour+1}:00"
                predictions["time_based_predictions"]["peak_hour_confidence"] = "high"
            
            # Day of week pattern
            daily_pattern = df_local.groupby('day_of_week').size()
            if not daily_pattern.empty:
                peak_day = daily_pattern.idxmax()
                day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
                predictions["time_based_predictions"]["peak_alert_day"] = day_names[peak_day]
                predictions["time_based_predictions"]["peak_day_confidence"] = "medium"
        
        # Alert type predictions
        # FIXED: Use UTC for time comparisons
        recent_alerts = df[df['created_at'] > (datetime.utcnow() - timedelta(days=7))]
        if not recent_alerts.empty:
            frequent_alert_types = recent_alerts['alert_type'].value_counts().head(3)
            predictions["alert_type_predictions"]["most_likely_alerts"] = frequent_alert_types.to_dict()
            predictions["alert_type_predictions"]["prediction_confidence"] = "medium"
        
        # Risk assessment
        unresolved_high = df[(df['severity_level'] == 'high') & (df['is_resolved'] == False)]
        if len(unresolved_high) > 0:
            predictions["risk_assessment"]["overall_risk"] = "high"
            predictions["risk_assessment"]["unresolved_high_severity"] = len(unresolved_high)
        elif len(df[df['is_resolved'] == False]) > 5:
            predictions["risk_assessment"]["overall_risk"] = "medium"
        else:
            predictions["risk_assessment"]["overall_risk"] = "low"
        
        return predictions
    
    def generate_insights(self, df):
        """Generate actionable insights from alert data"""
        insights = []
        
        if df.empty:
            return insights
        
        # High severity unresolved alerts
        high_severity_unresolved = df[(df['severity_level'] == 'high') & (df['is_resolved'] == False)]
        if not high_severity_unresolved.empty:
            insights.append({
                "type": "critical_attention",
                "title": "🚨 High Severity Unresolved Alerts",
                "description": f"{len(high_severity_unresolved)} high severity alerts require immediate attention",
                "priority": "high",
                "action": "Review and resolve these alerts immediately"
            })
        
        # Frequent temperature alerts
        temp_alerts = df[df['alert_type'].str.contains('temperature', na=False)]
        if len(temp_alerts) > 5:
            unresolved_temp = temp_alerts[temp_alerts['is_resolved'] == False]
            insights.append({
                "type": "maintenance_need",
                "title": "🌡️ Temperature Control Issues",
                "description": f"{len(temp_alerts)} temperature alerts ({len(unresolved_temp)} unresolved) indicate potential HVAC system issues",
                "priority": "medium",
                "action": "Schedule HVAC system inspection"
            })
        
        # Energy anomaly patterns
        energy_alerts = df[df['alert_type'].str.contains('energy', na=False)]
        if not energy_alerts.empty:
            unresolved_energy = energy_alerts[energy_alerts['is_resolved'] == False]
            if len(unresolved_energy) > 0:
                insights.append({
                    "type": "energy_efficiency",
                    "title": "⚡ Energy Consumption Issues",
                    "description": f"{len(unresolved_energy)} unresolved energy anomalies may indicate inefficient equipment usage",
                    "priority": "medium",
                    "action": "Conduct energy audit and optimize equipment schedules"
                })
        
        # Motion detection patterns
        motion_alerts = df[df['alert_type'] == 'motion']
        if len(motion_alerts) > 10:
            insights.append({
                "type": "security_pattern",
                "title": "🚶 High Motion Activity",
                "description": f"High frequency of motion alerts ({len(motion_alerts)}) detected",
                "priority": "low",
                "action": "Review security patterns and occupancy schedules"
            })
        
        # Resolution time analysis
        resolved_with_time = df[df['is_resolved'] == True]
        if 'resolved_at' in resolved_with_time.columns and 'created_at' in resolved_with_time.columns:
            resolved_with_time = resolved_with_time.dropna(subset=['resolved_at', 'created_at'])
            if not resolved_with_time.empty:
                # FIXED: Ensure both datetime columns are timezone-aware
                resolved_with_time['resolution_time_hours'] = (
                    resolved_with_time['resolved_at'] - resolved_with_time['created_at']
                ).dt.total_seconds() / 3600
                
                avg_resolution_time = resolved_with_time['resolution_time_hours'].mean()
                if avg_resolution_time > 24:
                    insights.append({
                        "type": "process_improvement",
                        "title": "⏰ Slow Alert Resolution",
                        "description": f"Average resolution time is {avg_resolution_time:.1f} hours",
                        "priority": "medium",
                        "action": "Optimize alert response procedures and staffing"
                    })
        
        return insights
    
    def detect_emerging_patterns(self, df):
        """Detect emerging patterns and correlations"""
        patterns = []
        
        if df.empty:
            return patterns
        
        # Check for increasing frequency of specific alert types
        if 'created_at' in df.columns:
            # FIXED: Use UTC for time comparisons
            df_7days = df[df['created_at'] > (datetime.utcnow() - timedelta(days=7))]
            df_previous_7days = df[
                (df['created_at'] > (datetime.utcnow() - timedelta(days=14))) &
                (df['created_at'] <= (datetime.utcnow() - timedelta(days=7)))
            ]
            
            for alert_type in df['alert_type'].unique():
                current_count = len(df_7days[df_7days['alert_type'] == alert_type])
                previous_count = len(df_previous_7days[df_previous_7days['alert_type'] == alert_type])
                
                if previous_count > 0 and current_count > previous_count * 1.5:  # 50% increase
                    increase_pct = ((current_count - previous_count) / previous_count) * 100
                    patterns.append({
                        "type": "emerging_trend",
                        "alert_type": alert_type,
                        "description": f"{alert_type} alerts increased by {increase_pct:.1f}% in the last 7 days",
                        "current_week": current_count,
                        "previous_week": previous_count
                    })
        
        return patterns

    def detect_data_anomalies(self, df):
        """Detect specific data anomalies in the alert dataset"""
        anomalies = []
        
        if df.empty:
            return anomalies
        
        try:
            # Check for alert frequency anomalies
            if 'created_at' in df.columns and 'alert_type' in df.columns:
                # Check for unusually high frequency of specific alert types
                alert_frequency = df['alert_type'].value_counts()
                total_alerts = len(df)
                
                for alert_type, count in alert_frequency.items():
                    frequency_percentage = (count / total_alerts) * 100
                    
                    # If any alert type makes up more than 40% of total alerts
                    if frequency_percentage > 40:
                        anomalies.append({
                            "type": "high_frequency_alert",
                            "alert_type": alert_type,
                            "description": f"'{alert_type}' alerts make up {frequency_percentage:.1f}% of all alerts (unusually high frequency)",
                            "severity": "high",
                            "recommendation": "Investigate root cause of frequent alerts"
                        })
            
            # Check for unresolved high severity alerts
            if 'severity_level' in df.columns and 'is_resolved' in df.columns:
                unresolved_high = df[(df['severity_level'] == 'high') & (df['is_resolved'] == False)]
                if len(unresolved_high) > 2:
                    anomalies.append({
                        "type": "unresolved_high_severity",
                        "description": f"{len(unresolved_high)} high severity alerts remain unresolved",
                        "severity": "critical",
                        "recommendation": "Immediately address unresolved high severity alerts"
                    })
            
            # Check for time-based anomalies (alerts concentrated in short time periods)
            if 'created_at' in df.columns:
                df_sorted = df.sort_values('created_at')
                time_diffs = df_sorted['created_at'].diff().dt.total_seconds() / 60  # minutes between alerts
                
                # Check for rapid succession of alerts (more than 3 alerts within 10 minutes)
                rapid_alerts = time_diffs[time_diffs < 10]  # alerts within 10 minutes
                if len(rapid_alerts) > 3:
                    anomalies.append({
                        "type": "rapid_alert_sequence",
                        "description": f"Multiple alerts ({len(rapid_alerts) + 1}) occurred in rapid succession",
                        "severity": "medium",
                        "recommendation": "Check for system-wide issues or sensor malfunctions"
                    })
            
            # Check for equipment-specific anomalies
            if 'equipment_id' in df.columns:
                equipment_alerts = df['equipment_id'].value_counts()
                if not equipment_alerts.empty:
                    max_alerts = equipment_alerts.max()
                    problematic_equipment = equipment_alerts[equipment_alerts == max_alerts]
                    
                    if max_alerts > 3:  # If any equipment has more than 3 alerts
                        for equip_id, count in problematic_equipment.items():
                            if pd.notna(equip_id):
                                anomalies.append({
                                    "type": "equipment_anomaly",
                                    "equipment_id": equip_id,
                                    "description": f"Equipment {equip_id} has {count} alerts (unusually high)",
                                    "severity": "medium",
                                    "recommendation": "Inspect equipment for potential issues"
                                })
            
            # Check for severity distribution anomalies
            if 'severity_level' in df.columns:
                severity_dist = df['severity_level'].value_counts(normalize=True)
                if 'high' in severity_dist and severity_dist['high'] > 0.5:  # More than 50% high severity
                    anomalies.append({
                        "type": "severity_distribution",
                        "description": f"High severity alerts make up {severity_dist['high']*100:.1f}% of total (unusually high)",
                        "severity": "high",
                        "recommendation": "Review alert severity thresholds and system stability"
                    })
            
            return anomalies
            
        except Exception as e:
            self.logger.error(f"Error in data anomaly detection: {e}")
            return anomalies
    
    def get_comprehensive_anomaly_report(self, days_back=30):
        """Generate comprehensive anomaly analysis report"""
        df = self.load_alerts_data(days_back=days_back)
        
        if df.empty:
            self.logger.warning("⚠️ No alert data available for analysis")
            return {
                "summary": "No alert data available for analysis",
                "detailed_analysis": {"error": "No data"},
                "predictions": {"error": "No data"},
                "insights": [],
                "emerging_patterns": [],
                "data_anomalies": [],
                "raw_data_sample": []
            }
        
        analysis = self.analyze_alert_patterns(df)
        predictions = self.predict_future_anomalies(df)
        insights = self.generate_insights(df)
        emerging_patterns = self.detect_emerging_patterns(df)
        data_anomalies = self.detect_data_anomalies(df)  # NEW: Add data anomalies
        
        # Generate natural language summary
        summary = self._generate_natural_language_summary(analysis, predictions, insights, emerging_patterns, data_anomalies, df)
        
        return {
            "summary": summary,
            "detailed_analysis": analysis,
            "predictions": predictions,
            "insights": insights,
            "emerging_patterns": emerging_patterns,
            "data_anomalies": data_anomalies,  # NEW: Include data anomalies
            "raw_data_sample": df.head(10).to_dict('records') if not df.empty else []
        }
    
    def _generate_natural_language_summary(self, analysis, predictions, insights, emerging_patterns, data_anomalies, df):
        """Generate natural language summary of anomaly analysis"""
        summary_parts = []
        
        # Header
        summary_parts.append("🔍 **Advanced Anomaly Analysis Report**")
        summary_parts.append("=" * 50)
        
        # Basic stats
        total_alerts = analysis["summary"]["total_alerts"]
        unresolved = analysis["summary"]["unresolved_alerts"]
        
        summary_parts.append(f"\n📊 **Summary Statistics:**")
        summary_parts.append(f"• Total alerts analyzed: {total_alerts}")
        summary_parts.append(f"• Unresolved alerts: {unresolved}")
        summary_parts.append(f"• Resolution rate: {((total_alerts - unresolved) / total_alerts * 100):.1f}%")
        
        # Alert type distribution
        alert_types = analysis["summary"]["alert_type_distribution"]
        if alert_types:
            top_alert = max(alert_types.items(), key=lambda x: x[1])
            summary_parts.append(f"• Most common alert: {top_alert[0]} ({top_alert[1]} occurrences)")
        
        # Data anomalies section
        if data_anomalies:
            summary_parts.append(f"\n🚨 **Detected Data Anomalies:**")
            for anomaly in data_anomalies[:5]:  # Show top 5 anomalies
                severity_icon = "🔴" if anomaly["severity"] in ["critical", "high"] else "🟡" if anomaly["severity"] == "medium" else "🟢"
                summary_parts.append(f"{severity_icon} {anomaly['description']}")
                summary_parts.append(f"   → Action: {anomaly['recommendation']}")
        
        # Trends
        if "trend_direction" in analysis["trends"]:
            trend = analysis["trends"]["trend_direction"]
            percentage = analysis["trends"]["trend_percentage"]
            summary_parts.append(f"• Alert trend: {trend} ({percentage:+.1f}% change)")
        
        # Predictions
        summary_parts.append(f"\n🔮 **Predictive Analysis:**")
        if "time_based_predictions" in predictions:
            if "peak_alert_hour" in predictions["time_based_predictions"]:
                summary_parts.append(f"• Peak alert hour: {predictions['time_based_predictions']['peak_alert_hour']}")
            if "peak_alert_day" in predictions["time_based_predictions"]:
                summary_parts.append(f"• Peak alert day: {predictions['time_based_predictions']['peak_alert_day']}")
        
        if "alert_type_predictions" in predictions and "most_likely_alerts" in predictions["alert_type_predictions"]:
            likely_alerts = list(predictions["alert_type_predictions"]["most_likely_alerts"].keys())
            summary_parts.append(f"• Expected alert types: {', '.join(likely_alerts)}")
        
        # Risk assessment
        if "risk_assessment" in predictions:
            risk_level = predictions["risk_assessment"]["overall_risk"]
            risk_emoji = "🔴" if risk_level == "high" else "🟡" if risk_level == "medium" else "🟢"
            summary_parts.append(f"• Overall risk level: {risk_emoji} {risk_level.upper()}")
        
        # Critical insights
        high_priority_insights = [i for i in insights if i["priority"] == "high"]
        if high_priority_insights:
            summary_parts.append(f"\n🚨 **Critical Issues Requiring Attention:**")
            for insight in high_priority_insights:
                summary_parts.append(f"• {insight['description']}")
                summary_parts.append(f"  → Action: {insight['action']}")
        
        # Medium priority insights
        medium_priority_insights = [i for i in insights if i["priority"] == "medium"]
        if medium_priority_insights:
            summary_parts.append(f"\n⚠️ **Areas for Improvement:**")
            for insight in medium_priority_insights:
                summary_parts.append(f"• {insight['description']}")
                summary_parts.append(f"  → Recommendation: {insight['action']}")
        
        # Emerging patterns
        if emerging_patterns:
            summary_parts.append(f"\n📈 **Emerging Patterns:**")
            for pattern in emerging_patterns[:3]:
                summary_parts.append(f"• {pattern['description']}")
        
        return "\n".join(summary_parts)

    def get_alert_statistics(self):
        """Get quick alert statistics for dashboard display"""
        df = self.load_alerts_data(days_back=7)  # Last 7 days
        
        if df.empty:
            self.logger.info("ℹ️ No alert data found for statistics")
            return {
                "total_alerts": 0,
                "unresolved_alerts": 0,
                "high_severity_alerts": 0,
                "most_common_alert": "No data",
                "resolution_rate": "0%"
            }
        
        stats = {
            "total_alerts": len(df),
            "unresolved_alerts": len(df[df['is_resolved'] == False]),
            "high_severity_alerts": len(df[df['severity_level'] == 'high']),
            "most_common_alert": df['alert_type'].value_counts().index[0] if not df.empty else "No data",
            "resolution_rate": f"{((len(df) - len(df[df['is_resolved'] == False])) / len(df) * 100):.1f}%" if len(df) > 0 else "0%"
        }
        
        self.logger.info(f"📈 Alert statistics: {stats}")
        return stats