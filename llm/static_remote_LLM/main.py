import pandas as pd
import os
import hashlib
import time
import json
import shutil
import re
from datetime import datetime, timedelta
from langchain_core.documents import Document
from langchain.chains import RetrievalQA
from langchain_ollama import OllamaEmbeddings
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma
from database_adapter import DatabaseAdapter
from pymongo import MongoClient
from dotenv import load_dotenv
import sys
from pathlib import Path
from typing import Dict, List, Optional, Any, Union
import numpy as np
import logging

# FIXED: Correct path resolution
BASE_DIR = Path(__file__).resolve().parent  # Points to llm/static_remote_LLM/
PROJECT_ROOT = BASE_DIR.parent.parent  # Points to SBMS-Y3S1G4/

# Add SBMS-Y3S1G4/api/ to sys.path
sys.path.append(str(PROJECT_ROOT / 'api'))

# Set DJANGO_SETTINGS_MODULE
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')

# FIXED: Load environment variables from .env in the correct project directory
env_path = PROJECT_ROOT / ".env"
if os.path.exists(env_path):
    load_dotenv(dotenv_path=env_path)
else:
    alternative_paths = [BASE_DIR / ".env", Path.cwd() / ".env"]
    for alt_path in alternative_paths:
        if os.path.exists(alt_path):
            load_dotenv(dotenv_path=alt_path)
            break

class LoggingManager:
    """Enhanced logging manager with MongoDB support"""
    
    def __init__(self, project_root, use_database=True, mongo_uri=None, mongo_db_name=None, mongo_collection_name=None, prompt_logs_db_name=None, prompt_logs_collection_name=None):
        self.project_root = project_root
        self.use_database = use_database
        self.mongo_uri = mongo_uri or os.getenv("MONGO_ATLAS_URI")
        self.mongo_db_name = mongo_db_name or os.getenv("MONGO_DB_NAME", "LLM_logs")
        self.mongo_collection_name = mongo_collection_name or os.getenv("MONGO_COLLECTION_NAME", "logs")
        self.prompt_logs_db_name = prompt_logs_db_name or os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
        self.prompt_logs_collection_name = prompt_logs_collection_name or os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
        
        # Setup logging
        self._setup_logging()
        self.logger = logging.getLogger(__name__)
        
        # MongoDB clients
        self.mongo_client = None
        self.prompt_mongo_client = None
        
    def _setup_logging(self):
        """Setup logging configuration"""
        log_dir = self.project_root / "logs"
        log_dir.mkdir(exist_ok=True)
        
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_dir / "room_analyzer.log"),
                logging.StreamHandler()
            ]
        )
    
    def ensure_mongodb_connection(self, mongo_uri=None, db_name=None, collection_name=None,
                                 prompt_db_name=None, prompt_collection_name=None):
        """Ensure MongoDB connection is established"""
        if not self.use_database:
            return
            
        try:
            mongo_uri = mongo_uri or self.mongo_uri
            if not mongo_uri:
                self.logger.warning("No MongoDB URI provided")
                return
                
            self.mongo_client = MongoClient(mongo_uri)
            self.prompt_mongo_client = MongoClient(mongo_uri)
            
            # Test connection
            self.mongo_client.admin.command('ping')
            self.logger.info("MongoDB connection established successfully")
            
        except Exception as e:
            self.logger.error(f"MongoDB connection failed: {e}")
            self.mongo_client = None
            self.prompt_mongo_client = None
    
    def log_to_mongodb(self, document, processed_hashes=None, save_callback=None):
        """Log document to MongoDB"""
        if not self.use_database or not self.mongo_client:
            return
            
        try:
            db = self.mongo_client[self.mongo_db_name]
            collection = db[self.mongo_collection_name]
            
            # Check for duplicates
            if processed_hashes and document.get('doc_hash') in processed_hashes:
                return
                
            collection.insert_one(document)
            
            if processed_hashes is not None and save_callback is not None:
                processed_hashes.add(document.get('doc_hash'))
                save_callback()
                
        except Exception as e:
            self.logger.error(f"Failed to log to MongoDB: {e}")
    
    def log_prompt_to_mongodb(self, query, response, user_id=None, username=None, session_id=None, client_ip=None, sources=None, 
                             error=None, prompt_type="base_enhancement", document_template="standard"):
        """Log prompt and response to MongoDB"""
        if not self.use_database or not self.prompt_mongo_client:
            return
            
        try:
            db = self.prompt_mongo_client[self.prompt_logs_db_name]
            collection = db[self.prompt_logs_collection_name]
            
            log_entry = {
                "timestamp": datetime.utcnow(),
                "query": query,
                "response": response,
                "user_id": user_id or "anonymous",
                "username": username or "anonymous",
                "session_id": session_id,
                "client_ip": client_ip,
                "prompt_type": prompt_type,
                "document_template": document_template,
                "sources_count": len(sources) if sources else 0,
                "error": error
            }
            
            if sources:
                log_entry["sources_sample"] = sources[:3]  # Store first 3 sources
                
            collection.insert_one(log_entry)
            
        except Exception as e:
            self.logger.error(f"Failed to log prompt to MongoDB: {e}")
    
    def recover_backup_logs(self):
        """Recover logs from backup if needed"""
        # Implementation for backup recovery
        pass

class PromptsConfig:
    """Configuration manager for prompts and templates"""
    
    def __init__(self, config_file=None):
        self.config_file = config_file
        self.default_prompts = {
            "system_prompts": {
                "base_enhancement": """You are an intelligent room management assistant. Analyze the provided room sensor data and maintenance information to answer questions accurately. Focus on:

1. Room occupancy and usage patterns
2. Energy and power consumption analysis  
3. Environmental conditions (temperature, humidity)
4. Maintenance requests and equipment status
5. Efficiency recommendations

Always base your answers on the actual data provided. If specific numbers aren't available, provide general insights. Be concise and helpful.

User Question: {query}""",

                "analytical": """You are a data analyst specializing in building management systems. Provide detailed analysis of:

- Energy consumption trends and patterns
- Room utilization efficiency  
- Equipment performance metrics
- Maintenance optimization opportunities
- Cost-saving recommendations

Support your analysis with specific data points when available. Provide actionable insights.

User Question: {query}""",

                "technical": """You are a technical building operations specialist. Focus on:

- Equipment performance and efficiency
- Power consumption breakdowns
- Environmental control systems
- Maintenance scheduling and prioritization
- Technical specifications and recommendations

Use technical terminology appropriately and provide precise information.

User Question: {query}"""
            },
            
            "document_templates": {
                "standard": """Room: {room_name}
Timestamp: {timestamp}
Occupancy: {occupancy_status} ({occupancy_count} people)
Energy: {energy_consumption_kwh} kWh
Power Breakdown:
- Lighting: {lighting_power}W
- HVAC Fan: {hvac_power}W  
- AC Compressor: {ac_compressor_power}W
- Projector: {projector_power}W
- Computer: {computer_power}W
- Standby: {standby_power}W
- Total: {total_power}W
Equipment Usage:
- Lights: {lights_hours}h
- AC: {ac_hours}h
- Projector: {projector_hours}h
- Computer: {computer_hours}h
Environment: {temperature}°C, {humidity}% humidity""",

                "analytical": """DATA POINT: Room {room_name} at {timestamp}
OCCUPANCY: {occupancy_count} people ({occupancy_status})
ENERGY: {energy_consumption_kwh} kWh consumed
POWER: {total_power}W total ({lighting_power}W lighting, {hvac_power}W HVAC, {ac_compressor_power}W AC)
USAGE: Lights {lights_hours}h, AC {ac_hours}h, Projector {projector_hours}h
ENVIRONMENT: {temperature}°C, {humidity}% humidity""",

                "maintenance": """MAINTENANCE REQUEST: {issue_description}
STATUS: {status}
SCHEDULED: {requested_date}
RESOLVED: {resolved_date}
EQUIPMENT: {equipment_id}
REQUESTED BY: {requested_by}
ASSIGNED TO: {assigned_to}
NOTES: {notes}"""
            },
            
            # ADD THIS SECTION for maintenance rules
            "maintenance_rules": {
                "sensor_malfunction": {
                    "urgency": "high",
                    "timeline": "48 hours",
                    "action": "Replace or calibrate sensor",
                    "impact": "Data accuracy compromised"
                },
                "temperature_sensor_error": {
                    "urgency": "medium", 
                    "timeline": "1 week",
                    "action": "Calibrate or replace temperature sensor",
                    "impact": "Environmental control affected"
                },
                "motion_detector_fault": {
                    "urgency": "medium",
                    "timeline": "1 week", 
                    "action": "Repair or replace motion detector",
                    "impact": "Occupancy tracking inaccurate"
                },
                "high_energy_usage": {
                    "urgency": "medium",
                    "timeline": "2 weeks",
                    "action": "Investigate energy consumption patterns",
                    "impact": "Increased operational costs"
                },
                "humidity_calibration_needed": {
                    "urgency": "low",
                    "timeline": "1 month",
                    "action": "Schedule calibration",
                    "impact": "Minor environmental data inaccuracy"
                },
                "power_supply_issue": {
                    "urgency": "high",
                    "timeline": "24 hours",
                    "action": "Immediate inspection required",
                    "impact": "Potential system failure"
                }
            }
        }
        
        self.prompts = self.default_prompts
        if config_file and os.path.exists(config_file):
            try:
                with open(config_file, 'r') as f:
                    custom_prompts = json.load(f)
                    self.prompts.update(custom_prompts)
            except Exception as e:
                logging.error(f"Error loading custom prompts: {e}")
    
    def get_system_prompt(self, prompt_type="base_enhancement"):
        """Get system prompt by type"""
        return self.prompts["system_prompts"].get(prompt_type, self.prompts["system_prompts"]["base_enhancement"])
    
    def get_document_template(self, template_type="standard"):
        """Get document template by type"""
        return self.prompts["document_templates"].get(template_type, self.prompts["document_templates"]["standard"])
    
    # ADD THIS METHOD to fix the error
    def get_all_prompts(self):
        """Get all prompts configuration - required by advanced_llm_handlers"""
        return self.prompts

class AdvancedLLMHandlers:
    """Advanced query handlers for complex analytical queries"""
    
    def __init__(self, prompts_config, db_adapter):
        self.prompts = prompts_config
        self.db_adapter = db_adapter
        self.logger = logging.getLogger(__name__)
    
    def handle_kpi_query(self, df):
        """Handle Key Performance Indicators queries"""
        try:
            if df.empty:
                return {"error": "No data available for KPI analysis"}
            
            kpis = {}
            
            # Energy KPIs
            if 'energy_consumption_kwh' in df.columns:
                kpis['total_energy'] = df['energy_consumption_kwh'].sum()
                kpis['avg_energy_per_room'] = df.groupby('room_name')['energy_consumption_kwh'].mean().mean()
            
            # Occupancy KPIs
            if 'occupancy_count' in df.columns:
                kpis['total_occupancy'] = df['occupancy_count'].sum()
                kpis['avg_occupancy'] = df['occupancy_count'].mean()
            
            # Power KPIs
            if 'power_consumption_watts.total' in df.columns:
                kpis['avg_power'] = df['power_consumption_watts.total'].mean()
                kpis['peak_power'] = df['power_consumption_watts.total'].max()
            
            # Environmental KPIs
            if 'environmental_data.temperature_celsius' in df.columns:
                kpis['avg_temperature'] = df['environmental_data.temperature_celsius'].mean()
            
            kpi_text = []
            for kpi, value in kpis.items():
                if 'energy' in kpi:
                    kpi_text.append(f"{kpi.replace('_', ' ').title()}: {value:.2f} kWh")
                elif 'power' in kpi:
                    kpi_text.append(f"{kpi.replace('_', ' ').title()}: {value:.2f} W")
                elif 'temperature' in kpi:
                    kpi_text.append(f"{kpi.replace('_', ' ').title()}: {value:.1f}°C")
                else:
                    kpi_text.append(f"{kpi.replace('_', ' ').title()}: {value:.1f}")
            
            answer = "Key Performance Indicators:\n" + "\n".join([f"• {kpi}" for kpi in kpi_text])
            
            return {
                "answer": answer,
                "kpis": kpis
            }
            
        except Exception as e:
            self.logger.error(f"Error in KPI handler: {e}")
            return {"error": f"KPI analysis failed: {str(e)}"}
    
    def handle_energy_trends_query(self, df):
        """Handle energy trend analysis queries with enhanced insights"""
        try:
            if df.empty:
                return {"answer": "🔋 Energy Analysis:\nNo energy consumption data available for analysis. Please ensure sensor data is being collected."}
            
            # Check for required columns
            missing_columns = []
            if 'timestamp' not in df.columns:
                missing_columns.append("timestamp")
            if 'energy_consumption_kwh' not in df.columns:
                missing_columns.append("energy_consumption_kwh")
            
            if missing_columns:
                return {"answer": f"🔋 Energy Analysis:\nMissing required data columns: {', '.join(missing_columns)}. Cannot perform trend analysis."}
            
            # Convert timestamp and group by date
            df['date'] = pd.to_datetime(df['timestamp']).dt.date
            daily_energy = df.groupby('date')['energy_consumption_kwh'].sum()
            
            # Enhanced data assessment
            data_points = len(df)
            unique_days = len(daily_energy)
            time_span = (pd.to_datetime(df['timestamp'].max()) - pd.to_datetime(df['timestamp'].min())).days
            
            if unique_days < 2:
                # Provide partial insights even with limited data
                current_energy = df['energy_consumption_kwh'].mean() if not df.empty else 0
                total_energy = df['energy_consumption_kwh'].sum()
                
                answer = f"""🔋 Energy Analysis:

Insufficient data points for trend analysis.

📊 Available Data:
• Data Points: {data_points}
• Time Span: {time_span} days
• Current Average: {current_energy:.2f} kWh
• Total Energy: {total_energy:.2f} kWh

💡 Recommendations:
• Collect data for at least 7 days for reliable trend analysis
• Ensure continuous data collection without gaps
• Monitor energy consumption patterns over longer periods"""
                
                return {"answer": answer}
            
            # Calculate comprehensive trends
            trend_direction = "increasing" if daily_energy.iloc[-1] > daily_energy.iloc[0] else "decreasing"
            avg_daily = daily_energy.mean()
            max_daily = daily_energy.max()
            min_daily = daily_energy.min()
            trend_percentage = ((daily_energy.iloc[-1] - daily_energy.iloc[0]) / daily_energy.iloc[0] * 100) if daily_energy.iloc[0] > 0 else 0
            
            # Room-wise analysis
            room_energy = df.groupby('room_name')['energy_consumption_kwh'].sum()
            highest_room = room_energy.idxmax() if not room_energy.empty else "N/A"
            highest_consumption = room_energy.max() if not room_energy.empty else 0
            
            # Power breakdown analysis if available
            power_breakdown = ""
            if 'power_consumption_watts.total' in df.columns:
                avg_power = df['power_consumption_watts.total'].mean()
                power_breakdown = f"• Average Power: {avg_power:.0f}W"
            
            # Efficiency metrics
            efficiency_metrics = ""
            if 'occupancy_count' in df.columns:
                avg_occupancy = df['occupancy_count'].mean()
                energy_per_occupant = avg_daily / (avg_occupancy + 1)  # +1 to avoid division by zero
                efficiency_metrics = f"• Energy per Occupant: {energy_per_occupant:.2f} kWh/person"
            
            # Cost analysis
            cost_per_kwh = 0.12  # Standard rate
            daily_cost = avg_daily * cost_per_kwh
            monthly_cost = daily_cost * 30
            annual_cost = daily_cost * 365
            
            answer = f"""🔋 Energy Analysis:

📈 TREND ANALYSIS:
• Overall trend: {trend_direction} ({trend_percentage:+.1f}%)
• Average daily consumption: {avg_daily:.2f} kWh
• Peak daily consumption: {max_daily:.2f} kWh
• Lowest daily consumption: {min_daily:.2f} kWh
• Highest consuming room: {highest_room} ({highest_consumption:.2f} kWh)

📊 EFFICIENCY METRICS:
{efficiency_metrics}
{power_breakdown}

💰 COST ANALYSIS:
• Daily cost: ${daily_cost:.2f}
• Monthly cost: ${monthly_cost:.2f}
• Annual cost: ${annual_cost:.2f}

💡 OPTIMIZATION OPPORTUNITIES:
• Monitor peak consumption periods
• Implement energy-saving measures in {highest_room}
• Consider occupancy-based energy controls
• Regular energy audits for efficiency improvements"""
            
            return {
                "answer": answer,
                "trends": {
                    "direction": trend_direction,
                    "percentage_change": trend_percentage,
                    "average_daily": avg_daily,
                    "peak_daily": max_daily,
                    "lowest_daily": min_daily,
                    "highest_room": highest_room,
                    "data_quality": f"{unique_days} days, {data_points} points"
                }
            }
            
        except Exception as e:
            self.logger.error(f"Error in energy trends handler: {e}")
            return {"answer": f"🔋 Energy Analysis:\nError analyzing energy trends: {str(e)}. Please check data quality and try again."}
    
    def generate_weekly_summary(self, df):
        """Generate weekly summary report"""
        try:
            if df.empty or 'timestamp' not in df.columns:
                return {"error": "No timestamp data available for weekly summary"}
            
            # Get data from the last 7 days
            latest_date = pd.to_datetime(df['timestamp']).max()
            week_ago = latest_date - timedelta(days=7)
            weekly_data = df[pd.to_datetime(df['timestamp']) >= week_ago]
            
            if weekly_data.empty:
                return {"answer": "No data available for the past week"}
            
            summary_parts = ["Weekly Summary Report:"]
            
            # Energy summary
            if 'energy_consumption_kwh' in weekly_data.columns:
                total_energy = weekly_data['energy_consumption_kwh'].sum()
                avg_daily_energy = total_energy / 7
                summary_parts.append(f"• Total Energy: {total_energy:.2f} kWh ({avg_daily_energy:.2f} kWh/day)")
            
            # Occupancy summary
            if 'occupancy_count' in weekly_data.columns:
                total_occupancy = weekly_data['occupancy_count'].sum()
                avg_daily_occupancy = total_occupancy / 7
                summary_parts.append(f"• Total Occupancy: {total_occupancy} people ({avg_daily_occupancy:.1f} people/day)")
            
            # Room utilization
            if 'room_name' in weekly_data.columns:
                room_counts = weekly_data['room_name'].value_counts()
                top_room = room_counts.index[0] if not room_counts.empty else "N/A"
                summary_parts.append(f"• Most Used Room: {top_room}")
            
            # Environmental summary
            if 'environmental_data.temperature_celsius' in weekly_data.columns:
                avg_temp = weekly_data['environmental_data.temperature_celsius'].mean()
                summary_parts.append(f"• Average Temperature: {avg_temp:.1f}°C")
            
            answer = "\n".join(summary_parts)
            
            return {
                "answer": answer,
                "weekly_metrics": {
                    "total_energy": total_energy if 'energy_consumption_kwh' in weekly_data.columns else 0,
                    "total_occupancy": total_occupancy if 'occupancy_count' in weekly_data.columns else 0
                }
            }
            
        except Exception as e:
            self.logger.error(f"Error generating weekly summary: {e}")
            return {"error": f"Weekly summary generation failed: {str(e)}"}
    
    def detect_anomalies(self, df):
        """Detect anomalies in the data"""
        # Simplified anomaly detection - in practice, you'd use more sophisticated methods
        anomalies = []
        
        try:
            # High energy consumption anomaly
            if 'energy_consumption_kwh' in df.columns:
                energy_mean = df['energy_consumption_kwh'].mean()
                energy_std = df['energy_consumption_kwh'].std()
                high_energy = df[df['energy_consumption_kwh'] > energy_mean + 2 * energy_std]
                
                for _, row in high_energy.iterrows():
                    anomalies.append({
                        'type': 'High Energy Consumption',
                        'severity': 'Medium',
                        'description': f"Room {row.get('room_name', 'Unknown')} consumed {row['energy_consumption_kwh']:.2f} kWh"
                    })
            
            # High temperature anomaly
            if 'environmental_data.temperature_celsius' in df.columns:
                high_temp = df[df['environmental_data.temperature_celsius'] > 28]  # Above 28°C
                for _, row in high_temp.iterrows():
                    anomalies.append({
                        'type': 'High Temperature',
                        'severity': 'Low',
                        'description': f"Room {row.get('room_name', 'Unknown')} temperature: {row['environmental_data.temperature_celsius']}°C"
                    })
                    
        except Exception as e:
            self.logger.error(f"Error in anomaly detection: {e}")
            
        return anomalies
    
    def handle_context_aware_query(self, query, df):
        """Handle context-aware queries about current situation"""
        try:
            if df.empty:
                return {"answer": "No current data available"}
            
            # Get latest data point
            latest_data = df.iloc[-1] if not df.empty else None
            
            if latest_data is None:
                return {"answer": "No recent data available"}
            
            context_info = []
            
            if 'room_name' in latest_data:
                context_info.append(f"Latest data from {latest_data['room_name']}")
            
            if 'occupancy_count' in latest_data:
                context_info.append(f"Occupancy: {latest_data['occupancy_count']} people")
            
            if 'environmental_data.temperature_celsius' in latest_data:
                context_info.append(f"Temperature: {latest_data['environmental_data.temperature_celsius']}°C")
            
            if 'power_consumption_watts.total' in latest_data:
                context_info.append(f"Power: {latest_data['power_consumption_watts.total']}W")
            
            answer = "Current situation: " + ", ".join(context_info)
            
            return {
                "answer": answer,
                "current_data": latest_data.to_dict() if hasattr(latest_data, 'to_dict') else dict(latest_data)
            }
            
        except Exception as e:
            self.logger.error(f"Error in context-aware handler: {e}")
            return {"error": f"Context analysis failed: {str(e)}"}

    # === ADDED MISSING METHODS ===
    def generate_energy_insights(self, df):
        """Generate comprehensive energy insights and recommendations"""
        insights = []
        
        try:
            if df.empty:
                return insights
                
            # Enhanced data quality assessment
            data_points = len(df)
            time_span = (pd.to_datetime(df['timestamp'].max()) - pd.to_datetime(df['timestamp'].min())).days if 'timestamp' in df.columns else 0
            
            # Basic energy metrics
            if 'energy_consumption_kwh' in df.columns:
                total_energy = df['energy_consumption_kwh'].sum()
                avg_energy = df['energy_consumption_kwh'].mean()
                peak_energy = df['energy_consumption_kwh'].max()
                min_energy = df['energy_consumption_kwh'].min()
                
                # Energy trends with percentage change
                if 'timestamp' in df.columns and len(df) > 1:
                    df_sorted = df.sort_values('timestamp')
                    first_energy = df_sorted['energy_consumption_kwh'].iloc[0]
                    last_energy = df_sorted['energy_consumption_kwh'].iloc[-1]
                    energy_trend = "increasing" if last_energy > first_energy else "decreasing" if last_energy < first_energy else "stable"
                    trend_percentage = ((last_energy - first_energy) / first_energy * 100) if first_energy > 0 else 0
                else:
                    energy_trend = "unknown"
                    trend_percentage = 0
                
                # Energy intensity calculation
                energy_intensity = total_energy / time_span if time_span > 0 else avg_energy
                
                # Cost analysis
                cost_per_kwh = 0.12  # Standard rate
                daily_cost = avg_energy * cost_per_kwh
                annual_cost = daily_cost * 365
                
                insights.extend([
                    {
                        "metric": "total_energy_consumption",
                        "current_value": f"{total_energy:.2f} kWh",
                        "trend": f"{energy_trend} ({trend_percentage:+.1f}%)",
                        "opportunity": f"Energy intensity: {energy_intensity:.2f} kWh/day",
                        "recommendation": f"Total consumption: {total_energy:.2f} kWh with {trend_percentage:+.1f}% trend"
                    },
                    {
                        "metric": "average_energy_per_reading",
                        "current_value": f"{avg_energy:.2f} kWh (Range: {min_energy:.2f}-{peak_energy:.2f})",
                        "trend": energy_trend,
                        "opportunity": "Optimize usage during peak consumption periods",
                        "recommendation": f"Average: {avg_energy:.2f} kWh per reading"
                    },
                    {
                        "metric": "energy_cost_analysis",
                        "current_value": f"${annual_cost:.2f}/year (${daily_cost:.2f}/day)",
                        "trend": "cost_analysis",
                        "opportunity": f"Potential savings through efficiency measures",
                        "recommendation": f"Current annual cost: ${annual_cost:.2f} at ${cost_per_kwh}/kWh"
                    }
                ])
            
            # Power consumption analysis
            if 'power_consumption_watts.total' in df.columns:
                avg_power = df['power_consumption_watts.total'].mean()
                max_power = df['power_consumption_watts.total'].max()
                power_trend = self._calculate_trend(df['power_consumption_watts.total'])
                
                insights.append({
                    "metric": "power_consumption",
                    "current_value": f"{avg_power:.0f}W (Peak: {max_power:.0f}W)",
                    "trend": "increasing" if power_trend["slope"] > 10 else "decreasing" if power_trend["slope"] < -10 else "stable",
                    "opportunity": "Optimize power usage and reduce peak demand",
                    "recommendation": f"Average power: {avg_power:.0f}W, Peak: {max_power:.0f}W"
                })
            
            # Component-wise analysis
            component_insights = self._analyze_power_components(df)
            insights.extend(component_insights)
            
            # Room-specific insights
            if 'room_name' in df.columns:
                room_energy = df.groupby('room_name')['energy_consumption_kwh'].sum()
                if not room_energy.empty:
                    highest_room = room_energy.idxmax()
                    lowest_room = room_energy.idxmin()
                    highest_consumption = room_energy.max()
                    lowest_consumption = room_energy.min()
                    
                    insights.extend([
                        {
                            "metric": "highest_consumption_room",
                            "current_value": f"{highest_room} ({highest_consumption:.2f} kWh)",
                            "trend": "focus_room",
                            "opportunity": "Target efficiency measures for highest consumption",
                            "recommendation": f"Focus efficiency efforts on {highest_room} - highest consumer"
                        },
                        {
                            "metric": "lowest_consumption_room",
                            "current_value": f"{lowest_room} ({lowest_consumption:.2f} kWh)",
                            "trend": "efficiency_baseline",
                            "opportunity": "Use as efficiency benchmark for other rooms",
                            "recommendation": f"Model efficiency practices from {lowest_room}"
                        }
                    ])
            
            # Energy efficiency per occupant
            if 'energy_consumption_kwh' in df.columns and 'occupancy_count' in df.columns:
                occupied_data = df[df['occupancy_count'] > 0]
                if not occupied_data.empty:
                    total_energy_occupied = occupied_data['energy_consumption_kwh'].sum()
                    total_occupant_hours = occupied_data['occupancy_count'].sum()
                    energy_per_occupant = total_energy_occupied / total_occupant_hours if total_occupant_hours > 0 else 0
                    
                    insights.append({
                        "metric": "energy_efficiency_per_occupant",
                        "current_value": f"{energy_per_occupant:.2f} kWh/person-hour",
                        "trend": "efficiency_metric",
                        "opportunity": "Target: <0.1 kWh/person-hour for optimal efficiency",
                        "recommendation": f"Energy efficiency: {energy_per_occupant:.2f} kWh per occupant-hour"
                    })
            
            # Data quality insight
            if data_points < 100 or time_span < 7:
                insights.append({
                    "metric": "data_quality",
                    "current_value": f"{data_points} points over {time_span} days",
                    "trend": "needs_improvement",
                    "opportunity": "Extend data collection for more reliable analysis",
                    "recommendation": "Collect data for at least 7 days with 100+ points for comprehensive insights"
                })
                
        except Exception as e:
            self.logger.error(f"Error generating energy insights: {e}")
        
        return insights
    
    def _analyze_power_components(self, df):
        """Analyze individual power components for detailed insights"""
        component_insights = []
        
        try:
            power_components = {
                'power_consumption_watts.lighting': 'Lighting',
                'power_consumption_watts.hvac_fan': 'HVAC Fan',
                'power_consumption_watts.air_conditioner_compressor': 'AC Compressor',
                'power_consumption_watts.computer': 'Computers',
                'power_consumption_watts.projector': 'Projector',
                'power_consumption_watts.standby_misc': 'Standby/Misc'
            }
            
            total_power = df['power_consumption_watts.total'].mean() if 'power_consumption_watts.total' in df.columns else 0
            
            for col, component_name in power_components.items():
                if col in df.columns:
                    component_power = df[col].mean()
                    component_percentage = (component_power / total_power * 100) if total_power > 0 else 0
                    
                    # Usage hours analysis
                    usage_col = col.replace('power_consumption_watts.', 'equipment_usage.').replace('_power', '_on_hours')
                    usage_hours = df[usage_col].mean() if usage_col in df.columns else 0
                    
                    component_insights.append({
                        "metric": f"{component_name.lower().replace(' ', '_')}_analysis",
                        "current_value": f"{component_power:.0f}W ({component_percentage:.1f}%)",
                        "trend": "component_analysis",
                        "opportunity": f"Usage: {usage_hours:.1f}h - {'High' if component_percentage > 20 else 'Moderate' if component_percentage > 10 else 'Low'} consumption component",
                        "recommendation": f"{component_name}: {component_power:.0f}W ({component_percentage:.1f}% of total)"
                    })
                    
        except Exception as e:
            self.logger.error(f"Error analyzing power components: {e}")
        
        return component_insights

    def _calculate_trend(self, data):
        """Calculate trend from time series data"""
        try:
            if len(data) < 2:
                return {"slope": 0, "confidence": "low"}
            
            # Simple linear trend calculation
            x = np.arange(len(data))
            y = data.values
            slope = np.polyfit(x, y, 1)[0]
            
            # Basic confidence based on data points
            confidence = "high" if len(data) > 10 else "medium" if len(data) > 5 else "low"
            
            return {"slope": slope, "confidence": confidence}
            
        except Exception as e:
            self.logger.error(f"Error calculating trend: {e}")
            return {"slope": 0, "confidence": "low"}

# ADD THIS IMPORT - Import the comprehensive RoomSpecificHandlers
try:
    from room_specific_handlers import RoomSpecificHandlers
    print("Successfully imported comprehensive RoomSpecificHandlers from room_specific_handlers.py")
except ImportError as e:
    print(f"Failed to import RoomSpecificHandlers from room_specific_handlers.py: {e}")
    print("Falling back to basic RoomSpecificHandlers")
    
    # Fallback to the basic version (keep your existing basic class as backup)
    class RoomSpecificHandlers:
        """Basic fallback handlers for room-specific queries"""
        
        def __init__(self, prompts_config, db_adapter):
            self.prompts = prompts_config
            self.db_adapter = db_adapter
            self.logger = logging.getLogger(__name__)
        
        def handle_room_specific_query(self, query):
            """Handle queries about specific rooms"""
            try:
                # Extract room name from query
                room_pattern = r'(?:room|Room)\s+([A-Za-z0-9\s]+)'
                match = re.search(room_pattern, query)
                
                if not match:
                    return {"error": "No room specified in query"}
                
                room_name = match.group(1).strip()
                self.logger.info(f"Processing query for room: {room_name}")
                
                # This would typically query the database for specific room data
                # For now, return a generic response
                return {
                    "answer": f"Room {room_name} data would be retrieved and analyzed here. Specific room queries are supported.",
                    "sources": []
                }
                
            except Exception as e:
                self.logger.error(f"Error in room-specific handler: {e}")
                return {"error": f"Room-specific query failed: {str(e)}"}

class RoomLogAnalyzer:
    """
    Advanced AI-powered room log analyzer that processes sensor data, 
    maintenance requests, and energy consumption patterns.
    """
    
    def __init__(self, chroma_dir=None, use_database=True,
                 mongo_uri=None, mongo_db_name=None, mongo_collection_name=None,
                 prompt_logs_db_name=None, prompt_logs_collection_name=None,
                 prompts_config_file=None, prompt_type="base_enhancement",
                 document_template="standard"):
        """
        Initialize the Room Log Analyzer.
        """
        # Dynamically set paths
        script_dir = os.path.dirname(os.path.abspath(__file__))
        self.chroma_dir = chroma_dir or os.path.join(script_dir, "chroma_room_logs")
        self.use_database = use_database
        self.vector_store = None
        self.qa_chain = None
        self.processed_hashes = set()
        self.df = None
        self.maintenance_df = None
        self.db_adapter = None

        # Initialize logging manager
        self.logger_manager = LoggingManager(
            project_root=PROJECT_ROOT,
            use_database=use_database,
            mongo_uri=mongo_uri or os.getenv("MONGO_ATLAS_URI"),
            mongo_db_name=mongo_db_name or os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=mongo_collection_name or os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=prompt_logs_db_name or os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs"),
            prompt_logs_collection_name=prompt_logs_collection_name or os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
        )
        self.logger = self.logger_manager.logger

        # Initialize prompts configuration
        config_path = prompts_config_file or os.path.join(script_dir, "custom_prompts.json")
        self.prompts = PromptsConfig(config_path if os.path.exists(config_path) else None)
        self.prompt_type = prompt_type
        self.document_template = document_template
        self.logger.info(f"Using prompt type: {prompt_type}")
        self.logger.info(f"Using document template: {document_template}")

        # Initialize database adapters
        if self.use_database:
            try:
                self.db_adapter = DatabaseAdapter()
                self.logger.info("PostgreSQL database adapter initialized successfully")
            except Exception as e:
                self.logger.error(f"Failed to initialize PostgreSQL adapter: {e}")
                self.db_adapter = None
                self.logger.warning("Continuing without PostgreSQL database connection")

        # Initialize advanced handlers with database adapter
        self.advanced_handlers = AdvancedLLMHandlers(self.prompts, self.db_adapter)
        self.room_handlers = None

        self._load_processed_hashes()

        if self.use_database and self.db_adapter:
            try:
                # USE THE COMPREHENSIVE ROOM HANDLERS
                self.room_handlers = RoomSpecificHandlers(self.prompts, self.db_adapter)
                self.logger.info("Comprehensive RoomSpecificHandlers initialized successfully")
                
                # Test room handlers by getting available rooms
                available_rooms = self.room_handlers.get_available_rooms()
                if available_rooms:
                    room_names = [room.get('name', 'Unknown') for room in available_rooms]
                    self.logger.info(f"Available rooms detected: {', '.join(room_names)}")
                else:
                    self.logger.warning("No rooms found in the system")
                    
            except Exception as e:
                self.logger.error(f"Failed to initialize comprehensive room handlers: {e}")
                self.logger.warning("Falling back to basic room handlers")
                # Fallback to basic handlers
                self.room_handlers = self._create_basic_room_handlers()
        else:
            self.logger.warning("No database adapter available, room-specific handlers not initialized")
            self.room_handlers = self._create_basic_room_handlers()

    def _create_basic_room_handlers(self):
        """Create basic fallback room handlers"""
        class BasicRoomHandlers:
            def __init__(self, prompts_config, db_adapter):
                self.prompts = prompts_config
                self.db_adapter = db_adapter
                self.logger = logging.getLogger(__name__)
            
            def handle_room_specific_query(self, query):
                return {
                    "answer": f"Room-specific queries are supported but comprehensive room analysis is not available. Query: {query}",
                    "sources": []
                }
        
        return BasicRoomHandlers(self.prompts, self.db_adapter)

    def _load_processed_hashes(self):
        """Load hashes of already processed documents to avoid duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        if os.path.exists(hash_file):
            try:
                with open(hash_file, 'r', encoding='utf-8') as f:
                    self.processed_hashes = set(line.strip() for line in f)
                self.logger.info(f"Loaded {len(self.processed_hashes)} existing document hashes")
            except OSError as e:
                self.logger.error(f"Error loading processed hashes: {e}")

    def _save_processed_hashes(self):
        """Save hashes of processed documents to avoid future duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        try:
            os.makedirs(os.path.dirname(hash_file), exist_ok=True)
            with open(hash_file, 'w', encoding='utf-8') as f:
                for h in self.processed_hashes:
                    f.write(h + '\n')
        except OSError as e:
            self.logger.error(f"Error saving processed hashes: {e}")

    def _generate_document_hash(self, row):
        """Generate a unique hash for a document based on all relevant fields"""
        content_parts = [
            str(row.get('timestamp', '')),
            str(row.get('room_name', 'Unknown')),
            str(row.get('occupancy_status', '')),
            str(row.get('occupancy_count', 0)),
            str(row.get('energy_consumption_kwh', 0)),
            str(row.get('power_consumption_watts.lighting', 0)),
            str(row.get('power_consumption_watts.hvac_fan', 0)),
            str(row.get('power_consumption_watts.air_conditioner_compressor', 0)),
            str(row.get('power_consumption_watts.projector', 0)),
            str(row.get('power_consumption_watts.computer', 0)),
            str(row.get('power_consumption_watts.standby_misc', 0)),
            str(row.get('power_consumption_watts.total', 0)),
            str(row.get('equipment_usage.lights_on_hours', 0)),
            str(row.get('equipment_usage.air_conditioner_on_hours', 0)),
            str(row.get('equipment_usage.projector_on_hours', 0)),
            str(row.get('equipment_usage.computer_on_hours', 0)),
            str(row.get('environmental_data.temperature_celsius', 0)),
            str(row.get('environmental_data.humidity_percent', 0))
        ]
        content = "_".join(content_parts)
        return hashlib.md5(content.encode()).hexdigest()

    def load_from_postgresql(self, limit=None):
        """Load data from PostgreSQL and return as a DataFrame"""
        try:
            if self.db_adapter is None:
                self.logger.error("PostgreSQL adapter not initialized; cannot load data")
                return None

            df = self.db_adapter.get_sensor_data_as_dataframe(limit=limit)
            if df is None or df.empty:
                self.logger.warning("PostgreSQL returned no data")
                return None

            # Filter for occupied rooms only
            df = df[df["occupancy_status"] == "occupied"]

            # Convert numeric columns
            numeric_cols = [
                "occupancy_count", "energy_consumption_kwh",
                "power_consumption_watts.lighting", "power_consumption_watts.hvac_fan",
                "power_consumption_watts.air_conditioner_compressor", "power_consumption_watts.projector",
                "power_consumption_watts.computer", "power_consumption_watts.standby_misc",
                "power_consumption_watts.total", "equipment_usage.lights_on_hours",
                "equipment_usage.air_conditioner_on_hours", "equipment_usage.projector_on_hours",
                "equipment_usage.computer_on_hours", "environmental_data.temperature_celsius",
                "environmental_data.humidity_percent"
            ]
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

            self.logger.info(f"Loaded {len(df)} unique occupied room records from PostgreSQL")
            return df
        except Exception as e:
            self.logger.error(f"Error loading from PostgreSQL: {e}")
            return None

    def load_maintenance_data(self, limit=None):
        """Load maintenance data from PostgreSQL"""
        try:
            if self.db_adapter is None:
                self.logger.error("PostgreSQL adapter not initialized; cannot load maintenance data")
                return None

            df = self.db_adapter.get_maintenance_requests_using_django(limit=limit)
            
            if df is None or df.empty:
                self.logger.info("Trying direct SQL for maintenance data")
                df = self.db_adapter.get_maintenance_requests_as_dataframe(limit=limit)

            if df is None or df.empty:
                self.logger.warning("No maintenance data loaded from PostgreSQL")
                return None

            self.logger.info(f"Loaded {len(df)} maintenance requests from PostgreSQL")
            return df
        except Exception as e:
            self.logger.error(f"Error loading maintenance data: {e}")
            return None

    def _create_maintenance_document(self, row):
        """Create a document from maintenance request data"""
        try:
            # Format dates properly
            requested_date = row['requested_date']
            if hasattr(requested_date, 'strftime'):
                requested_date = requested_date.strftime("%Y-%m-%d")
            
            resolved_date = row['resolved_date']
            if resolved_date and hasattr(resolved_date, 'strftime'):
                resolved_date = resolved_date.strftime("%Y-%m-%d")
            else:
                resolved_date = "Not resolved"
                
            created_at = row['created_at']
            if hasattr(created_at, 'strftime'):
                created_at = created_at.strftime("%Y-%m-%d %H:%M:%S")

            template = """
            Maintenance Request: {issue_description}
            Status: {status}
            Scheduled Date: {requested_date}
            Resolved Date: {resolved_date}
            Created At: {created_at}
            Equipment ID: {equipment_id}
            Requested By: {requested_by}
            Assigned To: {assigned_to}
            Notes: {notes}
            """
            
            page_content = template.format(
                issue_description=row['issue_description'],
                status=row['status'],
                requested_date=requested_date,
                resolved_date=resolved_date,
                created_at=created_at,
                equipment_id=row.get('equipment_id', 'No equipment'),
                requested_by=row.get('requested_by_id', 'Unknown'),
                assigned_to=row.get('assigned_to_id', 'Not assigned'),
                notes=row.get('notes') or "No additional notes"
            )

            doc_hash = hashlib.md5(page_content.encode()).hexdigest()
            
            return Document(
                page_content=page_content,
                metadata={
                    "type": "maintenance",
                    "status": row['status'],
                    "requested_date": requested_date,
                    "resolved_date": resolved_date,
                    "equipment_id": row.get('equipment_id'),
                    "doc_hash": doc_hash
                }
            )
        except Exception as e:
            self.logger.error(f"Error creating maintenance document: {e}")
            return None

    def load_and_process_data(self, force_reload=False, limit=None, include_maintenance=True):
        """Load and process both sensor data and maintenance data"""
        if not force_reload and self.df is not None:
            self.logger.info("Using cached DataFrame")
            return self.df

        try:
            if not self.use_database or self.db_adapter is None:
                self.logger.warning("Database not initialized; returning empty DataFrame")
                self.df = pd.DataFrame()
                return self.df

            self.logger.info("Loading sensor data from PostgreSQL")
            sensor_df = self.load_from_postgresql(limit=limit)
            
            maintenance_df = None
            if include_maintenance:
                self.logger.info("Loading maintenance data from PostgreSQL")
                maintenance_df = self.load_maintenance_data(limit=limit)

            self.df = sensor_df if sensor_df is not None else pd.DataFrame()
            self.maintenance_df = maintenance_df

            # Log new sensor records to MongoDB
            if self.use_database and sensor_df is not None and not sensor_df.empty:
                new_docs = []
                for _, row in sensor_df.iterrows():
                    doc_hash = self._generate_document_hash(row)
                    if doc_hash not in self.processed_hashes:
                        mongo_doc = row.to_dict()
                        if 'timestamp' in mongo_doc:
                            try:
                                mongo_doc['timestamp'] = pd.to_datetime(mongo_doc['timestamp'])
                            except ValueError:
                                self.logger.warning(f"Could not convert timestamp: {mongo_doc['timestamp']}")
                        mongo_doc['doc_hash'] = doc_hash
                        mongo_doc['created_at'] = datetime.utcnow()
                        new_docs.append(mongo_doc)
                        self.processed_hashes.add(doc_hash)
                
                if new_docs:
                    for doc in new_docs:
                        self.logger_manager.log_to_mongodb(doc, self.processed_hashes, self._save_processed_hashes)
                    self.logger.info(f"Batch logged {len(new_docs)} new sensor records to MongoDB")
                    self._save_processed_hashes()
                else:
                    self.logger.info("No new sensor records to log to MongoDB (all duplicates)")

            return self.df

        except Exception as e:
            self.logger.error(f"Error loading data: {e}")
            self.df = pd.DataFrame()
            return self.df

    def _create_document_from_row(self, row):
        """Convert DataFrame row into a LangChain Document, including room_name"""
        try:
            timestamp_str = row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        except AttributeError:
            timestamp_str = str(row['timestamp'])

        template = self.prompts.get_document_template(self.document_template)
        page_content = template.format(
            timestamp=timestamp_str,
            room_name=row.get('room_name', 'Unknown'),
            occupancy_status=row['occupancy_status'],
            occupancy_count=row['occupancy_count'],
            energy_consumption_kwh=row['energy_consumption_kwh'],
            lighting_power=row['power_consumption_watts.lighting'],
            hvac_power=row['power_consumption_watts.hvac_fan'],
            ac_compressor_power=row.get('power_consumption_watts.air_conditioner_compressor', 0),
            projector_power=row.get('power_consumption_watts.projector', 0),
            computer_power=row.get('power_consumption_watts.computer', 0),
            standby_power=row['power_consumption_watts.standby_misc'],
            total_power=row['power_consumption_watts.total'],
            lights_hours=row['equipment_usage.lights_on_hours'],
            ac_hours=row['equipment_usage.air_conditioner_on_hours'],
            projector_hours=row['equipment_usage.projector_on_hours'],
            computer_hours=row['equipment_usage.computer_on_hours'],
            temperature=row['environmental_data.temperature_celsius'],
            humidity=row['environmental_data.humidity_percent']
        )

        doc_hash = self._generate_document_hash(row)
        metadata = {
            "timestamp": timestamp_str,
            "room_name": row.get('room_name', 'Unknown'),
            "occupancy_count": int(row["occupancy_count"]),
            "energy_kwh": float(row["energy_consumption_kwh"]),
            "power_total": float(row["power_consumption_watts.total"]),
            "temperature": float(row["environmental_data.temperature_celsius"]),
            "humidity": float(row["environmental_data.humidity_percent"]),
            "doc_hash": doc_hash
        }
        return Document(
            page_content=page_content,
            metadata=metadata
        )

    def create_documents(self, df, include_maintenance=True):
        """Convert DataFrame rows into LangChain Documents with deduplication"""
        documents = []
        new_document_count = 0

        # Process sensor data documents
        for _, row in df.iterrows():
            doc_hash = self._generate_document_hash(row)
            if doc_hash in self.processed_hashes:
                continue

            doc = self._create_document_from_row(row)
            documents.append(doc)
            self.processed_hashes.add(doc_hash)
            new_document_count += 1

        # Process maintenance documents
        if include_maintenance and hasattr(self, 'maintenance_df') and self.maintenance_df is not None:
            for _, row in self.maintenance_df.iterrows():
                doc = self._create_maintenance_document(row)
                if doc and doc.metadata['doc_hash'] not in self.processed_hashes:
                    documents.append(doc)
                    self.processed_hashes.add(doc.metadata['doc_hash'])
                    new_document_count += 1

        self.logger.info(f"Created {new_document_count} new documents")
        return documents

    def initialize_vector_store(self, documents, reset=False):
        """Initialize or load the vector store with documents"""
        try:
            if reset and os.path.exists(self.chroma_dir):
                self.logger.info("Resetting vector store")
                shutil.rmtree(self.chroma_dir)
                self.processed_hashes.clear()
                self._save_processed_hashes()

            if os.path.exists(self.chroma_dir) and os.listdir(self.chroma_dir) and not reset:
                self.logger.info("Loading existing vector store")
                embedding = OllamaEmbeddings(model="nomic-embed-text")
                vector_store = Chroma(
                    persist_directory=self.chroma_dir,
                    embedding_function=embedding,
                    collection_name="room_logs"
                )
                existing_docs = vector_store.get()
                existing_hashes = {doc.get('doc_hash') for doc in existing_docs['metadatas'] if isinstance(doc, dict) and 'doc_hash' in doc}
                new_documents = [doc for doc in documents if doc.metadata['doc_hash'] not in existing_hashes]
                if new_documents:
                    self.logger.info(f"Adding {len(new_documents)} new documents to existing vector store")
                    vector_store.add_documents(new_documents)
                    vector_store.persist()
                else:
                    self.logger.info("No new documents to add to vector store")
            else:
                self.logger.info("Creating new vector store")
                embedding = OllamaEmbeddings(model="nomic-embed-text")
                vector_store = Chroma.from_documents(
                    documents=documents,
                    embedding=embedding,
                    persist_directory=self.chroma_dir,
                    collection_name="room_logs"
                )
                vector_store.persist()

            self.vector_store = vector_store
            self._save_processed_hashes()

        except Exception as e:
            self.logger.error(f"Error initializing vector store: {e}")
            raise

    def initialize_qa_chain(self):
        """Initialize the QA chain with the LLM"""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            llm = OllamaLLM(model="incept5/llama3.1-claude:latest")
            self.qa_chain = RetrievalQA.from_chain_type(
                llm=llm,
                retriever=self.vector_store.as_retriever(),
                chain_type="stuff",
                return_source_documents=True
            )
            self.logger.info("QA chain initialized successfully")
        except ValueError as e:
            self.logger.error(f"Error initializing QA chain: {e}")
            raise

    def _get_source_documents_for_rows(self, rows):
        """Convert DataFrame rows to source documents for response"""
        source_docs = []
        for _, row in rows.iterrows():
            doc = self._create_document_from_row(row)
            source_docs.append({
                "page_content": doc.page_content,
                "metadata": dict(doc.metadata)
            })
        return source_docs

    def _parse_mixed_query(self, q_lower):
        """Parse mixed queries like 'highest temperature and highest energy'"""
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

        operations = []
        parts = re.split(r'\s+and\s+|\s*&\s*|\s*,\s*', q_lower)

        for part in parts:
            part = part.strip()
            if not part:
                continue

            found_op = None
            found_col = None

            for op_word, op_func in op_map.items():
                if op_word in part:
                    found_op = op_func
                    break

            for col_word, col_name in col_map.items():
                if col_word in part:
                    found_col = col_name
                    break

            if found_op and found_col:
                operations.append((found_op, found_col))

        return operations

    def _handle_mixed_query(self, q_lower, df):
        """Handle mixed queries with multiple operations on different columns"""
        operations = self._parse_mixed_query(q_lower)

        if not operations:
            return None

        results = []
        all_sources = []

        for op, col in operations:
            if col not in df.columns:
                continue

            if op == "max":
                value = df[col].max()
                op_word = "highest"
            elif op == "min":
                value = df[col].min()
                op_word = "lowest"
            elif op == "mean":
                value = df[col].mean()
                op_word = "average"
                sample_rows = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_rows)
                all_sources.extend(sources)
                results.append(f"The {op_word} {col.split('.')[-1]} is {value:.2f}")
                continue
            else:
                continue

            matching_rows = df[df[col] == value]
            timestamps = []
            rooms = []
            for _, row in matching_rows.iterrows():
                try:
                    timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                except AttributeError:
                    timestamps.append(str(row["timestamp"]))
                if 'room_name' in row and pd.notna(row['room_name']):
                    rooms.append(row["room_name"])

            sources = self._get_source_documents_for_rows(matching_rows.head(2))
            all_sources.extend(sources)
            col_display = col.split('.')[-1]
            room_str = f" in room(s) {', '.join(set(rooms))}" if rooms else ""
            results.append(f"The {op_word} {col_display} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}{room_str}")

        if results:
            return {
                "answer": ". ".join(results) + ".",
                "sources": all_sources[:6]
            }

        return None

    def _handle_min_max_query(self, q_lower, df, operation):
        """Handle minimum/maximum queries for single columns"""
        col_map = {
            "total": "power_consumption_watts.total",
            "lighting": "power_consumption_watts.lighting",
            "light": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "fan": "power_consumption_watts.hvac_fan",
            "ac": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "air conditioner": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc",
            "misc": "power_consumption_watts.standby_misc",
            "energy": "energy_consumption_kwh",
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "projector": "equipment_usage.projector_on_hours",
            "projectors": "equipment_usage.projector_on_hours"
        }

        for key, col in col_map.items():
            if key in q_lower and col in df.columns:
                if operation == "combined":
                    min_value = df[col].min()
                    max_value = df[col].max()
                    min_rows = df[df[col] == min_value]
                    max_rows = df[df[col] == max_value]
                    min_timestamps = []
                    min_rooms = []
                    max_timestamps = []
                    max_rooms = []
                    for _, row in min_rows.iterrows():
                        try:
                            min_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except AttributeError:
                            min_timestamps.append(str(row["timestamp"]))
                        if 'room_name' in row and pd.notna(row['room_name']):
                            min_rooms.append(row["room_name"])
                    for _, row in max_rows.iterrows():
                        try:
                            max_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except AttributeError:
                            max_timestamps.append(str(row["timestamp"]))
                        if 'room_name' in row and pd.notna(row['room_name']):
                            max_rooms.append(row["room_name"])
                    sources = self._get_source_documents_for_rows(pd.concat([min_rows.head(2), max_rows.head(2)]))
                    min_room_str = f" in room(s) {', '.join(set(min_rooms))}" if min_rooms else ""
                    max_room_str = f" in room(s) {', '.join(set(max_rooms))}" if max_rooms else ""
                    return {
                        "answer": f"The lowest {key} is {min_value} at {', '.join(min_timestamps[:2])}{min_room_str}. "
                                  f"The highest {key} is {max_value} at {', '.join(max_timestamps[:2])}{max_room_str}.",
                        "sources": sources
                    }
                elif operation == "min":
                    value = df[col].min()
                    op_word = "lowest"
                else:
                    value = df[col].max()
                    op_word = "highest"

                matching_rows = df[df[col] == value]
                timestamps = []
                rooms = []
                for _, row in matching_rows.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except AttributeError:
                        timestamps.append(str(row["timestamp"]))
                    if 'room_name' in row and pd.notna(row['room_name']):
                        rooms.append(row["room_name"])
                sources = self._get_source_documents_for_rows(matching_rows.head(3))
                room_str = f" in room(s) {', '.join(set(rooms))}" if rooms else ""
                return {
                    "answer": f"The {op_word} {key} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}{room_str}.",
                    "sources": sources
                }

        return None

    def _handle_avg_query(self, q_lower, df):
        """Handle average queries deterministically"""
        col_map = {
            "power": "power_consumption_watts.total",
            "energy": "energy_consumption_kwh",
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "lighting": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc"
        }

        for key, col in col_map.items():
            if key in q_lower and col in df.columns:
                avg_value = df[col].mean()
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                return {
                    "answer": f"The average {key} is {avg_value:.2f}.",
                    "sources": sources
                }

        return None

    def _handle_maintenance_query(self, query, q_lower, user_id=None, username=None, session_id=None, client_ip=None):
        """Handle maintenance-related queries"""
        try:
            self.logger.info(f"Matched maintenance query: '{query}'")
            
            if not hasattr(self, 'maintenance_df') or self.maintenance_df is None or self.maintenance_df.empty:
                self.load_and_process_data(force_reload=True, include_maintenance=True)
                
            if not hasattr(self, 'maintenance_df') or self.maintenance_df is None or self.maintenance_df.empty:
                return {
                    "answer": "No maintenance data is currently available in the system.",
                    "sources": []
                }

            if "pending" in q_lower or "open" in q_lower:
                pending_issues = self.maintenance_df[self.maintenance_df['status'] == 'pending']
                if not pending_issues.empty:
                    issues_list = []
                    for _, issue in pending_issues.head(5).iterrows():
                        issues_list.append(f"- {issue['issue_description']} (Scheduled: {issue['requested_date']})")
                    answer = f"There are {len(pending_issues)} pending maintenance issues:\n" + "\n".join(issues_list)
                    if len(pending_issues) > 5:
                        answer += f"\n... and {len(pending_issues) - 5} more issues."
                else:
                    answer = "No pending maintenance issues found."
                    
            elif "resolved" in q_lower or "fixed" in q_lower:
                resolved_issues = self.maintenance_df[self.maintenance_df['status'] == 'resolved']
                if not resolved_issues.empty:
                    answer = f"There are {len(resolved_issues)} resolved maintenance issues."
                else:
                    answer = "No resolved maintenance issues found."
                    
            else:
                total_issues = len(self.maintenance_df)
                pending_count = len(self.maintenance_df[self.maintenance_df['status'] == 'pending'])
                resolved_count = len(self.maintenance_df[self.maintenance_df['status'] == 'resolved'])
                
                answer = f"There are {total_issues} maintenance requests: {pending_count} pending and {resolved_count} resolved."
                
                recent_issues = self.maintenance_df.head(3)
                if not recent_issues.empty:
                    answer += "\nRecent issues:"
                    for _, issue in recent_issues.iterrows():
                        status_icon = "⏳" if issue['status'] == 'pending' else ""
                        answer += f"\n{status_icon} {issue['issue_description']}"

            sample_maintenance = self.maintenance_df.head(2)
            sources = []
            for _, row in sample_maintenance.iterrows():
                doc = self._create_maintenance_document(row)
                if doc:
                    sources.append({
                        "page_content": doc.page_content,
                        "metadata": dict(doc.metadata)
                    })

            result = {
                "answer": answer,
                "sources": sources
            }
            
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=result["answer"],
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                sources=result.get("sources", []),
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return result
            
        except Exception as e:
            self.logger.error(f"Error in maintenance handler: {e}")
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                error=f"Maintenance handler failed: {str(e)}",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"error": str(e)}

    def _handle_deterministic_query(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Handle specific queries deterministically to avoid hallucinations"""
        q_lower = query.lower().strip()
        df = self.load_and_process_data(include_maintenance=True)
        if df is None or df.empty:
            self.logger.error("DataFrame is empty or None; cannot process query")
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                error="No data available",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"answer": "No data available to process the query.", "sources": []}

        self.logger.info(f"Processing deterministic query: '{q_lower}'")

        # FIRST: Try comprehensive room handlers for all room-related queries
        if self.room_handlers and any(keyword in q_lower for keyword in [
            "room", "for room", "in room", "conference", "laboratory", "hall", 
            "how many rooms", "occupied rooms", "room capacity", "most used room",
            "room utilization", "highest occupancy", "usage patterns", "temperature in",
            "what's happening in", "show me data for", "people in", "conference room",
            "main hall", "laboratory"
        ]):
            try:
                self.logger.info(f" Delegating to comprehensive room handlers for: '{query}'")
                
                # Use the comprehensive room handlers
                room_result = self.room_handlers.handle_room_specific_query(query)
                
                if room_result and "error" not in room_result:
                    self.logger.info(f"Room handlers successfully processed: '{query}'")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=room_result.get("answer", "No answer"),
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=room_result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return room_result
                elif "error" in room_result:
                    self.logger.warning(f"Room handlers returned error: {room_result['error']}")
                    # Continue to other handlers below
                    
            except Exception as e:
                self.logger.error(f"Error in comprehensive room handlers: {e}")
                # Continue to other handlers below

        # Continue with existing deterministic handlers for other query types
        # ROOM COUNT QUERIES (these will now be handled by the comprehensive handlers above)
        if "how many rooms" in q_lower or "number of rooms" in q_lower:
            try:
                self.logger.info(f"Matched room count query: '{query}'")
                if 'room_name' not in df.columns:
                    self.logger.error("room_name column not found in DataFrame")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="room_name column not found in DataFrame",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"answer": "Room information is not available in the dataset.", "sources": []}
                
                unique_rooms = df['room_name'].dropna().unique()
                room_count = len(unique_rooms)
                sample_df = df.sample(min(3, len(df))) if not df.empty else pd.DataFrame()
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are {room_count} unique rooms in the dataset: {', '.join(unique_rooms[:5])}{'...' if len(unique_rooms) > 5 else ''}.",
                    "sources": sources
                }
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in room count handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Room count handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": f"Failed to count rooms: {str(e)}"}

        # OCCUPIED ROOMS COUNT QUERIES
        if "how many occupied rooms" in q_lower or "number of occupied rooms" in q_lower or "occupied rooms count" in q_lower:
            try:
                self.logger.info(f"Matched occupied room count query: '{query}'")
                if 'room_name' not in df.columns or 'occupancy_status' not in df.columns:
                    self.logger.error("room_name or occupancy_status column not found in DataFrame")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="room_name or occupancy_status column not found in DataFrame",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"answer": "Room or occupancy information is not available in the dataset.", "sources": []}
                
                # Get the most recent timestamp to find current occupied rooms
                if 'timestamp' in df.columns:
                    latest_timestamp = df['timestamp'].max()
                    # Get rooms that were occupied at the most recent timestamp
                    recent_occupied_rooms = df[
                        (df['timestamp'] == latest_timestamp) & 
                        (df['occupancy_status'] == 'occupied')
                    ]['room_name'].dropna().unique()
                    occupied_room_count = len(recent_occupied_rooms)
                    occupied_rooms_list = list(recent_occupied_rooms)
                else:
                    # Fallback: count all unique rooms with any occupied status
                    occupied_rooms = df[df['occupancy_status'] == 'occupied']['room_name'].dropna().unique()
                    occupied_room_count = len(occupied_rooms)
                    occupied_rooms_list = list(occupied_rooms)
                
                # Get sample documents for sources
                if occupied_room_count > 0:
                    sample_rooms = occupied_rooms_list[:3]
                    sample_df = df[df['room_name'].isin(sample_rooms)].head(3)
                else:
                    sample_df = df.head(3) if not df.empty else pd.DataFrame()
                    
                sources = self._get_source_documents_for_rows(sample_df)
                
                if occupied_room_count > 0:
                    room_list = ", ".join(occupied_rooms_list[:5])
                    if len(occupied_rooms_list) > 5:
                        room_list += f" and {len(occupied_rooms_list) - 5} more"
                    
                    result = {
                        "answer": f"There are {occupied_room_count} occupied rooms: {room_list}.",
                        "sources": sources
                    }
                else:
                    result = {
                        "answer": "There are currently no occupied rooms in the system.",
                        "sources": sources
                    }
                    
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
                
            except Exception as e:
                self.logger.error(f"Error in occupied room count handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Occupied room count handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": f"Failed to count occupied rooms: {str(e)}"}

        # MAINTENANCE QUERIES
        if any(keyword in q_lower for keyword in ["maintenance", "repair", "issue", "fault", "broken", "malfunction"]):
            maintenance_result = self._handle_maintenance_query(query, q_lower, user_id, username, session_id, client_ip)
            if maintenance_result:
                return maintenance_result

        # KPI QUERIES
        if any(keyword in q_lower for keyword in ["key performance indicators", "kpi", "performance metrics"]):
            try:
                self.logger.info(f"Matched KPI query: '{query}'")
                result = self.advanced_handlers.handle_kpi_query(df)
                if "error" in result:
                    self.logger.error(f"KPI query failed: {result['error']}")
                    return result
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in KPI handler: {e}")
                return {"error": str(e)}

        # ENERGY TREND QUERIES
        if any(keyword in q_lower for keyword in ["energy trend", "energy pattern", "consumption trend", "analyze energy usage patterns", "energy usage patterns"]):
            try:
                self.logger.info(f"Matched energy trend query: '{query}'")
                result = self.advanced_handlers.handle_energy_trends_query(df)
                if "error" in result:
                    self.logger.error(f"Energy trend query failed: {result['error']}")
                    return result
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in energy trend handler: {e}")
                return {"error": str(e)}

        # WEEKLY SUMMARY QUERIES
        if any(keyword in q_lower for keyword in ["weekly summary", "weekly report", "summary", "show me weekly summary", "generate weekly summary"]):
            try:
                self.logger.info(f"Attempting to generate weekly summary for query: '{query}'")
                result = self.advanced_handlers.generate_weekly_summary(df)
                if "error" in result:
                    self.logger.error(f"Weekly summary generation failed: {result['error']}")
                    return result
                self.logger.info(f"Weekly summary generated: {result['answer'][:100]}...")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in weekly summary handler: {e}")
                return {"error": f"Failed to generate weekly summary: {str(e)}"}

        # ANOMALY DETECTION QUERIES
        if any(keyword in q_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            try:
                self.logger.info(f"Matched anomaly detection query: '{query}'")
                anomalies = self.advanced_handlers.detect_anomalies(df)
                if anomalies:
                    anomaly_descriptions = [f"{a['type']}: {a['description']}" for a in anomalies[:3]]
                    result = {
                        "answer": f"Detected {len(anomalies)} anomalies: {'; '.join(anomaly_descriptions)}",
                        "anomalies": anomalies
                    }
                else:
                    result = {"answer": "No anomalies detected in the current data.", "sources": []}
                
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in anomaly detection handler: {e}")
                return {"error": str(e)}

        # CONTEXT-AWARE QUERIES
        if any(keyword in q_lower for keyword in ["context", "current", "situation", "status"]):
            try:
                self.logger.info(f"Matched context-aware query: '{query}'")
                result = self.advanced_handlers.handle_context_aware_query(query, df)
                if "error" in result:
                    self.logger.error(f"Context-aware query failed: {result['error']}")
                    return result
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in context-aware handler: {e}")
                return {"error": str(e)}

        # ALL READINGS QUERIES
        if any(keyword in q_lower for keyword in ["all readings", "all logs", "all records", "all room_logs"]):
            try:
                self.logger.info(f"Matched all readings query: '{query}'")
                timestamps = []
                for _, row in df.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except AttributeError:
                        timestamps.append(str(row["timestamp"]))
                sources = self._get_source_documents_for_rows(df.sample(min(3, len(df))))
                result = {
                    "answer": f"The room logs contain {len(timestamps)} occupied readings: {', '.join(timestamps[:5])}{'...' if len(timestamps) > 5 else ''}.",
                    "sources": sources
                }
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in all readings handler: {e}")
                return {"error": str(e)}

        # RECORD COUNT QUERIES
        if "how many" in q_lower and any(keyword in q_lower for keyword in ["record", "data", "log"]):
            try:
                self.logger.info(f"Matched record count query: '{query}'")
                count = len(df)
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are {count} occupied room records in the dataset.",
                    "sources": sources
                }
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in record count handler: {e}")
                return {"error": str(e)}

        # PEOPLE COUNT QUERIES
        if "how many" in q_lower and "people" in q_lower:
            try:
                self.logger.info(f"Matched people count query: '{query}'")
                total_people = int(df["occupancy_count"].sum())
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are a total of {total_people} people across all occupied room records.",
                    "sources": sources
                }
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in people count handler: {e}")
                return {"error": str(e)}

        # POWER BREAKDOWN QUERIES
        if "power consumption breakdown" in q_lower or "power breakdown" in q_lower:
            try:
                self.logger.info(f"Matched power breakdown query: '{query}'")
                timestamp_match = re.search(r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}', q_lower)
                if timestamp_match:
                    target_timestamp = timestamp_match.group(0)
                    try:
                        target_dt = pd.to_datetime(target_timestamp)
                        matching_rows = df[df["timestamp"] == target_dt]
                        if not matching_rows.empty:
                            row = matching_rows.iloc[0]
                            breakdown = (
                                f"Lighting: {row['power_consumption_watts.lighting']}W, "
                                f"HVAC Fan: {row['power_consumption_watts.hvac_fan']}W, "
                                f"Air Conditioner Compressor: {row.get('power_consumption_watts.air_conditioner_compressor', 0)}W, "
                                f"Projector: {row.get('power_consumption_watts.projector', 0)}W, "
                                f"Computer: {row.get('power_consumption_watts.computer', 0)}W, "
                                f"Standby Misc: {row['power_consumption_watts.standby_misc']}W, "
                                f"Total: {row['power_consumption_watts.total']}W"
                            )
                            sources = self._get_source_documents_for_rows(matching_rows)
                            result = {
                                "answer": f"At {target_timestamp}, the power consumption breakdown is: {breakdown}.",
                                "sources": sources
                            }
                            self.logger_manager.log_prompt_to_mongodb(
                                query=query,
                                response=result["answer"],
                                user_id=user_id,
                                username=username,
                                session_id=session_id,
                                client_ip=client_ip,
                                sources=sources,
                                prompt_type=self.prompt_type,
                                document_template=self.document_template
                            )
                            return result
                    except ValueError:
                        self.logger.warning(f"Invalid timestamp format in query: {target_timestamp}")
                self.logger.warning("No valid timestamp found for power breakdown query")
                return {"error": "No valid timestamp found for power breakdown query"}
            except Exception as e:
                self.logger.error(f"Error in power breakdown handler: {e}")
                return {"error": str(e)}

        # MIXED QUERIES
        mixed_result = self._handle_mixed_query(q_lower, df)
        if mixed_result:
            try:
                self.logger.info(f"Matched mixed query: '{query}'")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=mixed_result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=mixed_result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return mixed_result
            except Exception as e:
                self.logger.error(f"Error in mixed query handler: {e}")
                return {"error": str(e)}

        # MIN/MAX COMBINED QUERIES
        has_lowest = "lowest" in q_lower or "minimum" in q_lower or "min " in q_lower
        has_highest = "highest" in q_lower or "maximum" in q_lower or "max " in q_lower

        if has_lowest and has_highest:
            try:
                self.logger.info(f"Matched combined min/max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "combined")
                if result:
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    return {"error": "No result for combined min/max query"}
            except Exception as e:
                self.logger.error(f"Error in combined min/max handler: {e}")
                return {"error": str(e)}
        elif has_lowest:
            try:
                self.logger.info(f"Matched min query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "min")
                if result:
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    return {"error": "No result for min query"}
            except Exception as e:
                self.logger.error(f"Error in min handler: {e}")
                return {"error": str(e)}
        elif has_highest:
            try:
                self.logger.info(f"Matched max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "max")
                if result:
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    return {"error": "No result for max query"}
            except Exception as e:
                self.logger.error(f"Error in max handler: {e}")
                return {"error": str(e)}
        elif "average" in q_lower or "mean" in q_lower:
            try:
                self.logger.info(f"Matched average query: '{query}'")
                result = self._handle_avg_query(q_lower, df)
                if result:
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    return {"error": "No result for average query"}
            except Exception as e:
                self.logger.error(f"Error in average handler: {e}")
                return {"error": str(e)}

        self.logger.warning(f"No deterministic match for query: '{q_lower}'; falling back to LLM")
        self.logger_manager.log_prompt_to_mongodb(
            query=query,
            response=None,
            user_id=user_id,
            username=username,
            session_id=session_id,
            client_ip=client_ip,
            error="No deterministic match, falling back to LLM",
            prompt_type=self.prompt_type,
            document_template=self.document_template
        )
        return None

    def _enhance_query_for_llm(self, query):
        """Add context and instructions to reduce hallucinations using configurable prompts"""
        system_prompt = self.prompts.get_system_prompt(self.prompt_type)
        return system_prompt.format(query=query)

    def ask(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Ask a question about the room logs with robust logging"""
        self.logger.info(f"Processing ask request for query: '{query}' with user_id: {user_id}, username: {username}")
        
        if self.use_database:
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
            self.logger_manager.ensure_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name,
                                                          prompt_logs_db_name, prompt_logs_collection_name)
        
        if not self.qa_chain:
            self.logger.error("QA chain not initialized")
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error="QA chain not initialized",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"error": "QA chain not initialized. Please initialize the analyzer."}

        try:
            df = self.load_and_process_data(include_maintenance=True)
            if df is None or df.empty:
                self.logger.warning("No data available for processing query")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id or "anonymous",
                    username=username or "anonymous",
                    session_id=session_id,
                    client_ip=client_ip,
                    error="No data available",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"answer": "No data available to process the query.", "sources": []}

            documents = self.create_documents(df, include_maintenance=True)
            if documents:
                self.logger.info(f"Adding {len(documents)} new documents due to data changes")
                if self.vector_store is None:
                    self.initialize_vector_store(documents)
                else:
                    self.vector_store.add_documents(documents)
                    self.vector_store.persist()
                self._save_processed_hashes()
            else:
                self.logger.info("No new documents to add to vector store - using existing knowledge")

            deterministic_result = self._handle_deterministic_query(query, user_id, username, session_id, client_ip)
            if deterministic_result:
                self.logger.info(f"Used deterministic handler for query: '{query}'")
                return deterministic_result

            enhanced_query = self._enhance_query_for_llm(query)
            result = self.qa_chain({"query": enhanced_query})
            self.logger.info(f"Query: '{query}' - Response generated using LLM")

            llm_answer = result.get("result", "")
            validated_answer = self._validate_llm_response(llm_answer, query)

            seen_hashes = set()
            unique_source_docs = []
            for doc in result.get("source_documents", []):
                doc_hash = doc.metadata.get("doc_hash")
                if doc_hash not in seen_hashes:
                    unique_source_docs.append({
                        "page_content": doc.page_content,
                        "metadata": dict(doc.metadata)
                    })
                    seen_hashes.add(doc_hash)

            response = {
                "answer": validated_answer,
                "sources": unique_source_docs
            }

            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=validated_answer,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                sources=unique_source_docs,
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return response

        except Exception as e:
            self.logger.error(f"Error processing query '{query}': {e}")
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error=f"Query processing failed: {str(e)}",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"error": f"Failed to process query: {str(e)}"}

    def _validate_llm_response(self, response, query):
        """Basic validation to catch obvious hallucinations"""
        if any(word in query.lower() for word in ['power', 'energy', 'watt', 'kwh']):
            numbers = re.findall(r'\d+\.?\d*', response)
            for num in numbers:
                try:
                    num_val = float(num)
                    if num_val > 10000:
                        return "I cannot provide a precise answer based on the available data. The numbers may not be accurate."
                except ValueError:
                    continue
        return response

# Initialize the analyzer globally
analyzer = None

def initialize_analyzer(reset_vector_store=False):
    """Initialize the global analyzer instance"""
    global analyzer
    try:
        logger = logging.getLogger(__name__)
        logger.info("Starting analyzer initialization with MongoDB Atlas")
        
        mongo_uri = os.getenv("MONGO_ATLAS_URI")
        mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
        mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
        prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
        prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
        
        analyzer = RoomLogAnalyzer(
            use_database=True,
            mongo_uri=mongo_uri,
            mongo_db_name=mongo_db_name,
            mongo_collection_name=mongo_collection_name,
            prompt_logs_db_name=prompt_logs_db_name,
            prompt_logs_collection_name=prompt_logs_collection_name
        )
        
        df = analyzer.load_and_process_data(force_reload=True, include_maintenance=True)
        if df is not None and not df.empty:
            documents = analyzer.create_documents(df, include_maintenance=True)
            analyzer.initialize_vector_store(documents, reset=reset_vector_store)
            analyzer.initialize_qa_chain()
            logger.info("Analyzer initialized successfully")
        else:
            logger.warning("No data loaded during analyzer initialization")
        
        return analyzer
    except Exception as e:
        logger.error(f"Failed to initialize analyzer: {e}")
        return None

def ask(query, user_id=None, username=None, session_id=None, client_ip=None):
    """Wrapper function to allow importing ask as a function"""
    global analyzer
    if analyzer is None:
        analyzer = initialize_analyzer()
        if analyzer is None:
            logger = logging.getLogger(__name__)
            logger.error("Failed to initialize analyzer in ask function")
            return {"error": "Failed to initialize analyzer"}
    return analyzer.ask(query, user_id, username, session_id, client_ip)

if __name__ == "__main__":
    analyzer = initialize_analyzer(reset_vector_store=False)
    if analyzer:
        # Example queries that should work correctly
        test_queries = [
            "How many rooms are in the system?",
            "What's the most used room?",
            "Show me the highest temperature recorded",
            "How many maintenance requests are pending?",
            "What's the average energy consumption?",
            "Generate weekly summary",
            "Show me energy trends",
            "What are the key performance indicators?",
            "What's happening in Conference room A right now?",
            "Which room has the highest occupancy?",
            "Temperature in conference room A",
            "Show me data for Conference Room A",
            # Test energy queries
            "Energy consumption in Room 101",
            "Show me energy trends",
            "Power usage analysis",
            "Highest energy consumption room"
        ]
        
        for query in test_queries:
            print(f"\n=== Query: {query} ===")
            result = analyzer.ask(query)
            print(f"Answer: {result.get('answer', 'No answer')}")
            if 'error' in result:
                print(f"Error: {result['error']}")
            if 'insights' in result:
                print(f"Energy Insights: {result['insights']}")
    else:
        print("Failed to initialize analyzer")