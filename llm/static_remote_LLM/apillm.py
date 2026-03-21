#!/usr/bin/env python3
"""
Advanced LLM API for Building Management System
Enhanced with robust error handling, comprehensive data analysis, and fallback mechanisms
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timezone
import logging
import os
import sys
from pathlib import Path
import traceback
import numpy as np
import pandas as pd
from typing import Dict, List, Any
import json
import re

# ── Helper: strip control characters from LLM output before JSON serialization ──
# The LLM can return stray null bytes, escape sequences, or lone surrogates that
# cause JSON.parse() to fail on the frontend even though Python's json.dumps is fine.
def sanitize_llm_output(text: str) -> str:
    """Remove control characters, markdown code fences, and normalize line endings from LLM responses."""
    if not text:
        return ""
    # Strip control chars (keep \n and \t which are valid in JSON strings)
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]', '', text)
    # Normalize line endings
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    # Strip markdown code fences (```json ... ``` or ``` ... ```) that LLMs sometimes emit
    text = re.sub(r'```[\w]*\n?', '', text)
    return text.strip()


def _s(value, fallback: str = '') -> str:
    """Sanitize a raw database string value for safe JSON embedding."""
    return sanitize_llm_output(str(value) if value is not None else fallback)
from pymongo import MongoClient, DESCENDING
from dotenv import load_dotenv
from langchain_ollama import OllamaLLM

# Load environment variables
load_dotenv()

# ---------------------------------------------------------------------------
# Module-level LLM singleton — shared by all route handlers in this file.
# Using qwen2.5:3b: ~3× faster than incept5/llama3.1-claude, same accuracy
# for structured analytical queries. temperature=0.1 keeps answers factual.
# ---------------------------------------------------------------------------
_llm = OllamaLLM(model="qwen2.5:3b", temperature=0.1)

# Set DJANGO_SETTINGS_MODULE
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')

# Add SBMS-Y3S1G4/api/ to sys.path
BASE_DIR = Path(__file__).resolve().parent.parent.parent  # Points to SBMS-Y3S1G4/
sys.path.append(str(BASE_DIR / 'api'))

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from main import RoomLogAnalyzer, ask
except ImportError as e:
    print(f"⚠️ Import warning: {e}")
    # Create fallback classes if imports fail
    class RoomLogAnalyzer:
        def __init__(self, *args, **kwargs):
            pass
        def load_and_process_data(self):
            return pd.DataFrame()

# Setup logging with UTF-8 encoding
log_file = 'apillm_enhanced.log'
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler(stream=sys.stdout)
    ],
    force=True
)

# Configure console handler to use UTF-8
for handler in logging.root.handlers:
    if isinstance(handler, logging.StreamHandler):
        handler.stream.reconfigure(encoding='utf-8', errors='replace')

logger = logging.getLogger(__name__)

app = Flask(__name__)

# Custom JSON encoder for numpy/pandas types
class EnhancedJSONEncoder(json.JSONEncoder):
    def default(self, obj):
        if hasattr(obj, 'item'):
            return obj.item()
        elif isinstance(obj, (np.integer, np.int64, np.int32)):
            return int(obj)
        elif isinstance(obj, (np.floating, np.float64, np.float32)):
            return float(obj)
        elif isinstance(obj, np.ndarray):
            return obj.tolist()
        elif isinstance(obj, pd.Timestamp):
            return obj.isoformat()
        elif pd.isna(obj):
            return None
        return super().default(obj)

app.json_encoder = EnhancedJSONEncoder

# Enhanced CORS configuration
CORS(app, resources={r"/*": {
    "origins": ["http://localhost:3000", "http://127.0.0.1:3000", "http://localhost:5173", "*"],
    "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    "allow_headers": ["Content-Type", "X-User-Role", "Authorization", "X-Requested-With"],
    "supports_credentials": True
}})

# Global instances with health tracking
analyzer = None
system_health = {
    "status": "initializing",
    "last_check": None,
    "error_count": 0,
    "data_quality": "unknown"
}

class DataAnalyzer:
    """Enhanced data analysis utilities"""
    
    @staticmethod
    def analyze_dataset_quality(df: pd.DataFrame) -> Dict[str, Any]:
        """Comprehensive dataset quality analysis"""
        if df.empty:
            return {"status": "empty", "message": "Dataset is empty"}
        
        analysis = {
            "total_records": len(df),
            "total_columns": len(df.columns),
            "missing_values": int(df.isnull().sum().sum()),
            "completeness_score": float(1 - (df.isnull().sum().sum() / (len(df) * len(df.columns)))),
            "column_types": {
                "numeric": len(df.select_dtypes(include=[np.number]).columns),
                "categorical": len(df.select_dtypes(include=['object']).columns),
                "datetime": len(df.select_dtypes(include=['datetime']).columns)
            },
            "data_quality": "good"
        }
        
        # Quality assessment
        if analysis["completeness_score"] < 0.7:
            analysis["data_quality"] = "poor"
        elif analysis["completeness_score"] < 0.9:
            analysis["data_quality"] = "fair"
        
        return analysis
    
    @staticmethod
    def detect_energy_patterns(df: pd.DataFrame) -> List[Dict[str, Any]]:
        """Enhanced energy pattern detection"""
        patterns = []
        energy_columns = [col for col in df.columns if any(keyword in col.lower() for keyword in 
                         ['energy', 'power', 'kwh', 'consumption', 'watt', 'voltage', 'current'])]
        
        for col in energy_columns:
            if pd.api.types.is_numeric_dtype(df[col]):
                energy_data = df[col].dropna()
                if len(energy_data) > 0:
                    pattern = {
                        "column": col,
                        "samples": len(energy_data),
                        "average": float(energy_data.mean()),
                        "maximum": float(energy_data.max()),
                        "minimum": float(energy_data.min()),
                        "std_dev": float(energy_data.std()),
                        "trend": "stable"
                    }
                    
                    # Basic trend analysis
                    if len(energy_data) > 10:
                        first_half = energy_data[:len(energy_data)//2].mean()
                        second_half = energy_data[len(energy_data)//2:].mean()
                        if second_half > first_half * 1.1:
                            pattern["trend"] = "increasing"
                        elif second_half < first_half * 0.9:
                            pattern["trend"] = "decreasing"
                    
                    patterns.append(pattern)
        
        return patterns
    
    @staticmethod
    def analyze_room_utilization(df: pd.DataFrame) -> Dict[str, Any]:
        """Comprehensive room utilization analysis"""
        room_columns = ['room_id', 'room', 'room_name', 'location', 'sensor_location', 
                       'device_location', 'space', 'area', 'zone', 'building', 'floor']
        
        room_column = None
        for col in room_columns:
            if col in df.columns:
                room_column = col
                break
        
        if not room_column or df[room_column].isna().all():
            return {"status": "no_room_data", "available_columns": df.columns.tolist()}
        
        room_data = df[room_column].dropna()
        room_usage = room_data.value_counts()
        
        # Calculate thresholds for usage levels
        mean_usage = room_usage.mean()
        std_usage = room_usage.std()
        high_threshold = mean_usage + std_usage
        low_threshold = mean_usage - std_usage
        
        # Build detailed room breakdown
        room_details = []
        total_events = len(room_data)
        for room_name, count in room_usage.items():
            # Determine usage level
            if count > high_threshold:
                usage_level = "high"
            elif count < low_threshold:
                usage_level = "low"
            else:
                usage_level = "medium"
            
            room_details.append({
                "room_name": str(room_name),
                "event_count": int(count),
                "percentage": float((count / total_events) * 100),
                "usage_level": usage_level
            })
        
        analysis = {
            "status": "success",
            "room_column": room_column,
            "total_events": total_events,
            "unique_rooms": len(room_usage),
            "most_used_room": str(room_usage.index[0]) if len(room_usage) > 0 else "Unknown",
            "most_used_count": int(room_usage.iloc[0]) if len(room_usage) > 0 else 0,
            "utilization_distribution": {
                "high_usage": len([x for x in room_usage if x > high_threshold]),
                "medium_usage": len([x for x in room_usage if low_threshold <= x <= high_threshold]),
                "low_usage": len([x for x in room_usage if x < low_threshold])
            },
            "top_rooms": {str(room): int(count) for room, count in room_usage.head(10).items()},
            "room_details": room_details
        }
        
        if len(room_usage) > 0:
            analysis["usage_percentage"] = float((room_usage.iloc[0] / total_events) * 100)
            analysis["avg_events_per_room"] = float(total_events / len(room_usage))
        
        return analysis

def initialize_system() -> bool:
    """Enhanced system initialization with comprehensive error handling"""
    global analyzer, system_health
    
    try:
        logger.info("🔄 Initializing Advanced LLM System...")
        
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="chat_assistant",
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        # Load and analyze data quality
        df = analyzer.load_and_process_data()
        data_quality = DataAnalyzer.analyze_dataset_quality(df)
        
        if not df.empty:
            documents = analyzer.create_documents(df)
            analyzer.initialize_vector_store(documents)
            analyzer.initialize_qa_chain()
            
            system_health.update({
                "status": "healthy",
                "last_check": datetime.now(timezone.utc),
                "data_quality": data_quality["data_quality"],
                "records_loaded": len(df),
                "data_analysis": data_quality
            })
            
            logger.info(f"System initialized successfully. Loaded {len(df)} records.")
            print(f"DEBUG: System initialized with {len(df)} records. Data quality: {data_quality['data_quality']}")
            return True
        else:
            system_health.update({
                "status": "degraded",
                "last_check": datetime.now(timezone.utc),
                "data_quality": "empty",
                "records_loaded": 0
            })
            logger.warning("⚠️ System initialized but no data loaded")
            return True  # Still return True as system is operational
            
    except Exception as e:
        logger.error(f"❌ System initialization failed: {e}\n{traceback.format_exc()}")
        system_health.update({
            "status": "unhealthy",
            "last_check": datetime.now(timezone.utc),
            "error": str(e)
        })
        return False

def safe_analyzer_operation(operation_name: str, fallback_response: Dict[str, Any]):
    """Decorator for safe analyzer operations with fallbacks"""
    def decorator(func):
        def wrapper(*args, **kwargs):
            try:
                if analyzer is None:
                    initialize_system()
                return func(*args, **kwargs)
            except Exception as e:
                logger.error(f"Error in {operation_name}: {e}\n{traceback.format_exc()}")
                system_health["error_count"] += 1
                return fallback_response
        return wrapper
    return decorator

# MongoDB Connection for Chat History
mongo_client = None
chat_db = None
chat_collection = None

def initialize_mongodb():
    """Initialize MongoDB connection for chat history"""
    global mongo_client, chat_db, chat_collection
    try:
        # Get MongoDB connection from .env file
        mongo_uri = os.getenv('MONGO_ATLAS_URI', 'mongodb://localhost:27017/')
        db_name = os.getenv('MONGO_DB_NAME', 'LLM_logs')
        
        mongo_client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        
        # Test connection
        mongo_client.server_info()
        
        # Select database and collection from .env
        chat_db = mongo_client[db_name]
        chat_collection = chat_db['chat_history']
        
        # Create indexes for better query performance
        chat_collection.create_index([("user_id", 1), ("timestamp", DESCENDING)])
        chat_collection.create_index([("session_id", 1)])
        
        logger.info("✅ MongoDB connected successfully for chat history")
        return True
    except Exception as e:
        logger.warning(f"⚠️ MongoDB connection failed: {e}. Chat history will not be saved.")
        return False

@app.route('/health', methods=['GET', 'OPTIONS'])
def health_check():
    """Enhanced health check endpoint with detailed system status"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        # Force reinitialization if system is unhealthy
        if system_health["status"] in ["unhealthy", "initializing"]:
            initialize_system()
        
        health_data = {
            "status": system_health["status"],
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "capabilities": [
                "predictive_maintenance",
                "anomaly_detection", 
                "energy_insights",
                "room_utilization",
                "weekly_summaries",
                "context_aware_analysis",
                "data_quality_assessment"
            ],
            "system_info": {
                "last_health_check": system_health.get("last_check"),
                "error_count": system_health.get("error_count", 0),
                "data_quality": system_health.get("data_quality", "unknown"),
                "records_loaded": system_health.get("records_loaded", 0)
            }
        }
        
        # Add detailed data analysis if available
        if "data_analysis" in system_health:
            health_data["data_analysis"] = system_health["data_analysis"]
        
        return jsonify(health_data)
        
    except Exception as e:
        logger.error(f"Health check error: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/energy/report', methods=['POST', 'OPTIONS'])
def energy_report():
    """
    Generate energy report with LLM analysis for daily/weekly/monthly periods
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        period = data.get('period', 'weekly').lower()  # daily, weekly, monthly, yearly
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Energy report request ({period}) from {username}")
        
        # Initialize analyzer first
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="energy_insights",
            document_template="energy_report"
        )
        
        # Get recent data of this period type
        # Limit based on period to get appropriate amount of recent data
        limit_map = {
            'daily': 7,      # Last 7 days
            'weekly': 4,     # Last 4 weeks
            'monthly': 3,    # Last 3 months
            'yearly': 2      # Last 2 years
        }
        data_limit = limit_map.get(period, 10)
        
        all_data = analyzer.db_adapter.get_energy_summary_data(
            period_type=period,
            limit=data_limit
        )
        
        if all_data is None or all_data.empty:
            return jsonify({
                "status": "success",
                "answer": f"No {period} energy data available yet. Start collecting data to see insights.",
                "period": period,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Sort by date to ensure we have the most recent data
        all_data = all_data.sort_values('period_start', ascending=False)
        
        # Get actual date range from available data
        actual_start = all_data['period_start'].min()
        actual_end = all_data['period_end'].max()
        
        logger.info(f"Found {len(all_data)} {period} records from {actual_start.date()} to {actual_end.date()}")
        
        # Use the actual data we already fetched
        energy_df = all_data
        
        if energy_df is None or energy_df.empty:
            return jsonify({
                "status": "success",
                "answer": f"No {period} energy data available yet. Start collecting data to see insights.",
                "period": period,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Calculate statistics with timestamps
        total_energy = energy_df['total_energy'].sum()
        avg_energy = energy_df['total_energy'].mean()
        
        # Get peak and lowest with their timestamps
        peak_row = energy_df.loc[energy_df['total_energy'].idxmax()]
        lowest_row = energy_df.loc[energy_df['total_energy'].idxmin()]
        
        max_energy = peak_row['total_energy']
        min_energy = lowest_row['total_energy']
        peak_time = peak_row['period_start'] if pd.notna(peak_row['period_start']) else None
        lowest_time = lowest_row['period_start'] if pd.notna(lowest_row['period_start']) else None
        
        # Get period range
        period_start = energy_df['period_start'].min() if 'period_start' in energy_df.columns else None
        period_end = energy_df['period_end'].max() if 'period_end' in energy_df.columns else None
        
        # Get top consuming rooms
        room_totals = {}
        for _, row in energy_df.iterrows():
            room = row.get('room_name', 'Unknown')
            energy = row.get('total_energy', 0)
            room_totals[room] = room_totals.get(room, 0) + energy
        
        top_rooms = sorted(room_totals.items(), key=lambda x: x[1], reverse=True)[:3]
        
        # Format dates for better readability
        start_date_str = period_start.strftime('%B %d, %Y') if period_start and pd.notna(period_start) else 'Unknown'
        end_date_str = period_end.strftime('%B %d, %Y') if period_end and pd.notna(period_end) else 'Unknown'
        peak_time_str = peak_time.strftime('%B %d, %Y at %I:%M %p') if peak_time and pd.notna(peak_time) else 'Unknown'
        current_time = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        
        # Calculate additional insights
        energy_variance = energy_df['total_energy'].std() if len(energy_df) > 1 else 0
        efficiency_score = (min_energy / avg_energy * 100) if avg_energy > 0 else 0
        
        # Prepare enhanced LLM context with timestamps and deeper analysis
        llm_context = f"""You are an expert energy analyst with deep knowledge of building efficiency and sustainability. Analyze this {period} energy data and provide actionable, data-driven recommendations.

📅 REPORTING PERIOD: {start_date_str} to {end_date_str}
📊 Report Generated: {current_time}

COMPREHENSIVE ENERGY DATA:
- Period: {period.upper()}
- Total consumption: {total_energy:.2f} kWh
- Average: {avg_energy:.2f} kWh per period
- Peak: {max_energy:.2f} kWh (occurred on {peak_time_str})
- Lowest: {min_energy:.2f} kWh
- Variance: {energy_variance:.2f} kWh (consistency indicator)
- Efficiency Score: {efficiency_score:.1f}% (lower is better)
- Data points analyzed: {len(energy_df)}

TOP CONSUMING ROOMS (with percentage breakdown):
"""
        for i, (room, energy) in enumerate(top_rooms, 1):
            percentage = (energy / total_energy * 100) if total_energy > 0 else 0
            llm_context += f"{i}. {room}: {energy:.2f} kWh ({percentage:.1f}% of total)\n"
        
        llm_context += f"""\n\nProvide 3 DETAILED, ACTIONABLE recommendations using this format:

**1. CONSUMPTION PATTERN ANALYSIS ({period.upper()} - {start_date_str} to {end_date_str}):**
Analyze the energy consumption patterns during this period. Consider:
- Peak vs. average consumption (is the {max_energy:.2f} kWh peak concerning?)
- Room distribution (why is {top_rooms[0][0]} using {(top_rooms[0][1]/total_energy*100):.1f}%?)
- Variance patterns (is {energy_variance:.2f} kWh variance normal?)
- Time-based trends (what happened on {peak_time_str}?)

**2. COST OPTIMIZATION STRATEGIES:**
Provide specific, implementable cost-saving strategies:
- Target the high-consumption rooms (especially {top_rooms[0][0]})
- Suggest equipment upgrades or behavioral changes
- Estimate potential savings (e.g., "reducing peak by 20% could save X kWh")
- Consider efficiency improvements

**3. IMMEDIATE ACTION ITEMS FOR NEXT {period.upper()}:**
List 3-4 concrete actions with expected impact:
- Specific rooms to monitor or optimize
- Equipment to inspect or upgrade
- Behavioral changes to implement
- Measurable goals (e.g., "reduce {top_rooms[0][0]} consumption by 15%")

Be specific, use the actual data provided, and make recommendations actionable with clear expected outcomes. Each section should be 3-4 sentences with concrete numbers and examples."""        
        # Call LLM directly
        try:
            llm_analysis = sanitize_llm_output(_llm.invoke(llm_context))
            logger.info(f"LLM energy analysis generated for {username} ({period})")
        except Exception as llm_error:
            logger.warning(f"LLM call failed: {llm_error}")
            llm_analysis = f"""**1. CONSUMPTION ANALYSIS:**
Total {period} consumption is {total_energy:.2f} kWh with {top_rooms[0][0]} being the highest consumer.

**2. COST OPTIMIZATION:**
Focus on reducing consumption in {top_rooms[0][0]} which accounts for the majority of usage.

**3. ACTION ITEMS:**
Monitor peak usage times and implement energy-saving measures in high-consumption areas."""
        
        response = {
            "status": "success",
            "answer": llm_analysis,
            "period": period,
            "date_range": {
                "start": actual_start.isoformat(),
                "end": actual_end.isoformat(),
                "description": f"{start_date_str} to {end_date_str}"
            },
            "energy_data": {
                "total_kwh": float(total_energy),
                "average_kwh": float(avg_energy),
                "peak_kwh": float(max_energy),
                "peak_time": peak_time.isoformat() if peak_time and pd.notna(peak_time) else None,
                "lowest_kwh": float(min_energy),
                "lowest_time": lowest_time.isoformat() if lowest_time and pd.notna(lowest_time) else None,
                "period_start": period_start.isoformat() if period_start and pd.notna(period_start) else None,
                "period_end": period_end.isoformat() if period_end and pd.notna(period_end) else None,
                "data_points": len(energy_df),
                "variance": float(energy_variance),
                "efficiency_score": float(efficiency_score)
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Energy report error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Energy report failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

# Removed: /ask and /insights/energy endpoints (replaced by specific endpoints)

@app.route('/llmquery', methods=['POST', 'OPTIONS'])
def llm_query():
    """Enhanced general LLM chat with conversation history and smart routing"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        query = data.get('query', '').strip()
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        session_id = data.get('session_id', f"session_{datetime.now().timestamp()}")
        
        if not query:
            return jsonify({
                "status": "error",
                "error": "Query is required",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }), 400
        
        logger.info(f"💬 Chat query from {username}: {query[:100]}...")
        
        # Smart query routing - detect if user wants specific analysis
        query_lower = query.lower()
        
        # Check for room queries first
        room_keywords = ['show me rooms', 'list rooms', 'all rooms', 'room list', 'what rooms', 'available rooms', 'room directory']
        if any(keyword in query_lower for keyword in room_keywords):
            # Route to rooms endpoint
            try:
                rooms_response = list_rooms()
                rooms_data = rooms_response.get_json()
                
                if rooms_data.get('status') == 'success':
                    return jsonify({
                        "status": "success",
                        "query": query,
                        "answer": rooms_data.get('summary_text', 'Rooms retrieved successfully'),
                        "rooms": rooms_data.get('rooms', []),
                        "total_rooms": rooms_data.get('total_rooms', 0),
                        "detected_intent": "rooms",
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    })
            except Exception as e:
                logger.error(f"Room routing error: {e}")
        
        route_keywords = {
            'energy': ['energy', 'power', 'consumption', 'kwh', 'electricity', 'usage'],
            'maintenance': ['maintenance', 'repair', 'broken', 'issue', 'problem', 'fix'],
            'anomaly': ['anomaly', 'unusual', 'strange', 'abnormal', 'weird', 'unexpected'],
            'billing': ['billing', 'cost', 'rate', 'price', 'expense', 'payment']
        }
        
        detected_intent = None
        for intent, keywords in route_keywords.items():
            if any(keyword in query_lower for keyword in keywords):
                detected_intent = intent
                break
        
        # Get conversation history from MongoDB (last 5 messages)
        conversation_history = []
        try:
            if mongo_chat_collection is not None:
                history_docs = mongo_chat_collection.find(
                    {'session_id': session_id}
                ).sort('timestamp', -1).limit(5)
                
                conversation_history = list(reversed([
                    f"{doc.get('role', 'user')}: {doc.get('content', '')}"
                    for doc in history_docs
                ]))
        except Exception as e:
            logger.warning(f"Could not fetch conversation history: {e}")
        
        # Build context from history
        history_context = "\n".join(conversation_history) if conversation_history else "No previous conversation"
        
        # Get building status for context
        building_context = ""
        try:
            if analyzer and analyzer.df is not None and not analyzer.df.empty:
                df = analyzer.df
                total_rooms = df['room_name'].nunique() if 'room_name' in df.columns else 0
                avg_energy = df['energy_consumption_kwh'].mean() if 'energy_consumption_kwh' in df.columns else 0
                building_context = f"""
Current Building Status:
- Active Rooms: {total_rooms}
- Average Energy: {avg_energy:.2f} kWh/day
- Data Points: {len(df)}
"""
        except Exception as e:
            logger.warning(f"Could not get building context: {e}")
        
        # Enhanced system prompt with conversation awareness and better general responses
        current_time = datetime.now().strftime('%B %d, %Y at %I:%M %p')
        system_prompt = f"""You are an intelligent building management assistant with deep expertise in energy, maintenance, and facility operations. You have access to real-time building data and can provide specific, actionable insights.

Current Time: {current_time}

{building_context}

Previous Conversation:
{history_context}

YOUR CORE CAPABILITIES:
1. **Energy Analysis**: Analyze consumption patterns, identify inefficiencies, generate detailed reports (daily/weekly/monthly/yearly)
2. **Maintenance Management**: Predict equipment failures, track maintenance requests (can show 1-50 requests), prioritize repairs
3. **Room Utilization**: Monitor occupancy, optimize space allocation, track usage patterns across all rooms
4. **Cost Optimization**: Analyze billing rates, suggest energy-saving measures, estimate cost reductions
5. **Anomaly Detection**: Identify unusual patterns in energy, occupancy, or equipment behavior
6. **Conversational Help**: Answer questions about building data, provide insights, offer recommendations

RESPONSE GUIDELINES:
1. **Be Specific**: Always use actual building data (room names, numbers, equipment) in your responses
2. **Be Actionable**: Provide concrete next steps, not vague suggestions
3. **Be Engaging**: Use a friendly, conversational tone - you're a helpful expert, not a robot
4. **Be Contextual**: Reference previous conversation naturally
5. **Be Comprehensive**: For "what can you do" questions, give 4-5 specific examples with real data
6. **Be Concise**: Keep responses to 2-3 paragraphs, but make them information-dense
7. **Be Proactive**: Always end with a helpful question or suggestion for next steps

WHEN ASKED "WHAT CAN YOU DO" OR SIMILAR:
Provide 4-5 SPECIFIC examples using ACTUAL building data:
- Example 1: Energy analysis with specific room names and consumption numbers
- Example 2: Maintenance tracking with actual request counts
- Example 3: Cost optimization with potential savings estimates
- Example 4: Anomaly detection with specific patterns
- Example 5: Custom analysis offer

Format like this:
"Great question! I'm currently monitoring [X] rooms with [Y] kWh average consumption. Here's what I can help with:

1. **Energy Insights**: I can analyze which rooms consume the most (like [Room Name] using [X]% of total) and suggest optimization strategies. I can generate daily, weekly, monthly, or yearly reports with detailed breakdowns.

2. **Maintenance Tracking**: I'm monitoring [X] maintenance requests right now. I can show you 1, 5, 10, or all requests, prioritize them by urgency, and predict potential equipment failures before they happen.

3. **Cost Analysis**: I can review your billing rates, identify peak usage times, and estimate potential savings. For example, reducing [Room Name]'s consumption by 20% could save approximately [X] kWh per month.

4. **Smart Monitoring**: I can detect unusual patterns - like sudden spikes in energy usage or equipment anomalies - and alert you before they become problems.

Would you like me to dive into any of these areas? I can also generate a comprehensive report or analyze specific rooms!"

WHEN ASKED ABOUT ROOMS OR BUILDING FEATURES:
- List specific rooms from the building context with actual numbers
- Explain what data we track for each room (energy, occupancy, equipment, maintenance)
- Offer to analyze specific rooms in detail
- Provide actionable insights based on current data
- Suggest optimizations or improvements

IMPORTANT: Always use the building context data to make your responses specific and relevant. Never give generic responses - always include actual room names, numbers, and equipment from the context.

User Query: {query}


Assistant:"""
        
        # Direct LLM call (bypass vector store for speed)
        try:
            response = sanitize_llm_output(_llm.invoke(system_prompt))
            
            # Add suggestion if specific intent detected
            if detected_intent:
                suggestions = {
                    'energy': '\n\n💡 Tip: Use `/energy/report` for detailed energy analysis.',
                    'maintenance': '\n\n💡 Tip: Use `/maintenance/predict` for AI-powered maintenance predictions.',
                    'anomaly': '\n\n💡 Tip: Use `/anomalies/detect` for comprehensive anomaly detection.',
                    'billing': '\n\n💡 Tip: Use `/billing/rates` for detailed billing analysis.'
                }
                response += suggestions.get(detected_intent, '')
            
            # Save to conversation history
            try:
                if mongo_chat_collection is not None:
                    mongo_chat_collection.insert_one({
                        'session_id': session_id,
                        'role': 'user',
                        'content': query,
                        'timestamp': datetime.now(timezone.utc)
                    })
                    mongo_chat_collection.insert_one({
                        'session_id': session_id,
                        'role': 'assistant',
                        'content': response,
                        'timestamp': datetime.now(timezone.utc)
                    })
            except Exception as e:
                logger.warning(f"Could not save to conversation history: {e}")
            
            return jsonify({
                "status": "success",
                "query": query,
                "answer": response,
                "detected_intent": detected_intent,
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
            
        except Exception as llm_error:
            logger.error(f"LLM invocation failed: {llm_error}")
            # Fallback to basic response
            return jsonify({
                "status": "success",
                "query": query,
                "answer": f"I'm here to help with building management. You asked: '{query}'. How can I assist you further?",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
    except Exception as e:
        logger.error(f"LLM query error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Query failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

# Legacy endpoint redirects for frontend compatibility
@app.route('/ask', methods=['POST', 'OPTIONS'])
def ask_legacy():
    """Legacy /ask endpoint - redirects to /llmquery"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    # Forward to /llmquery
    return llm_query()

@app.route('/reports/weekly', methods=['POST', 'OPTIONS'])
def weekly_report_legacy():
    """Legacy /reports/weekly endpoint - redirects to /energy/report with weekly period"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        # Override period to weekly
        data['period'] = 'weekly'
        
        # Forward to energy_report with modified data
        request._cached_json = (data, data)
        return energy_report()
        
    except Exception as e:
        logger.error(f"Weekly report error: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/maintenance/predict', methods=['POST', 'OPTIONS'])
def predict_maintenance():
    """
    Enhanced predictive maintenance with user tracking and actionable suggestions
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        query = data.get('query', 'Analyze equipment and suggest maintenance')
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Maintenance prediction request from {username} (ID: {user_id})")
        
        maintenance_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="predictive_maintenance",
            document_template="maintenance_analysis",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = maintenance_analyzer.load_and_process_data()
        
        # Extract number from query (e.g., "provide 3 maintenance requests", "give me 5 issues")
        import re
        limit = 50  # default
        
        # Check for specific numbers
        number_match = re.search(r'\b(\d+)\b', query.lower())
        if number_match:
            limit = int(number_match.group(1))
            limit = min(limit, 50)  # Cap at 50 for safety
        elif 'one' in query.lower() or 'single' in query.lower():
            limit = 1
        elif 'two' in query.lower():
            limit = 2
        elif 'three' in query.lower():
            limit = 3
        elif 'five' in query.lower():
            limit = 5
        elif 'ten' in query.lower():
            limit = 10
        
        # Fetch actual maintenance requests from database
        maintenance_requests_df = maintenance_analyzer.db_adapter.get_maintenance_requests_as_dataframe(limit=limit)
        
        # Try advanced analysis first, fallback to basic if needed
        try:
            anomalies = maintenance_analyzer.advanced_handlers.detect_anomalies(df)
            maintenance_alerts = maintenance_analyzer.advanced_handlers.generate_maintenance_suggestions(df, anomalies)
        except Exception as e:
            logger.warning(f"Advanced maintenance analysis failed, using basic: {e}")
            anomalies = []
            maintenance_alerts = []
        
        # Basic equipment analysis fallback
        equipment_columns = [col for col in df.columns if any(keyword in col.lower() for keyword in 
                          ['equipment', 'device', 'sensor', 'machine', 'unit'])]
        
        equipment_analysis = {}
        if equipment_columns:
            for col in equipment_columns[:3]:  # Analyze first 3 equipment columns
                if col in df.columns and not df[col].isna().all():
                    equipment_counts = df[col].value_counts()
                    equipment_analysis[col] = {
                        "total_equipment": len(equipment_counts),
                        "most_common": str(equipment_counts.index[0]) if len(equipment_counts) > 0 else "Unknown",
                        "maintenance_suggestion": "Regular inspection recommended" if len(equipment_counts) > 10 else "Normal operation"
                    }
        
        # Format AI-generated maintenance suggestions with user context
        formatted_suggestions = []
        for m in maintenance_alerts:
            suggestion = {
                "equipment": getattr(m, 'equipment', 'General'),
                "room": getattr(m, 'room', 'Unknown'),
                "component": getattr(m, 'component', 'Unknown'),
                "issue": getattr(m, 'issue', 'Maintenance check needed'),
                "urgency": getattr(m, 'urgency', 'Medium'),
                "action": getattr(m, 'action', 'Inspect and maintain'),
                "timeline": getattr(m, 'timeline', 'Schedule soon'),
                "confidence": getattr(m, 'confidence', 0.5),
                "cost_estimate": getattr(m, 'cost_estimate', 'To be determined'),
                "risk_level": getattr(m, 'risk_level', 'Medium'),
                "requested_by": username,
                "user_id": user_id,
                "suggested_at": datetime.now(timezone.utc).isoformat(),
                "source": "AI_PREDICTION"
            }
            formatted_suggestions.append(suggestion)
        
        # Add actual maintenance requests from database
        actual_requests = []
        if maintenance_requests_df is not None and not maintenance_requests_df.empty:
            for _, req in maintenance_requests_df.iterrows():
                # Map status to urgency
                status = req.get('status', 'pending')
                urgency_map = {
                    'pending': 'High',
                    'in_progress': 'Medium',
                    'resolved': 'Low'
                }
                
                actual_request = {
                    "equipment": _s(req.get('equipment_name'), 'Unknown Equipment'),
                    "room": _s(req.get('room_name'), 'Unknown Room'),
                    "component": _s(req.get('equipment_type'), 'Unknown'),
                    "issue": _s(req.get('issue_description'), 'No description'),
                    "urgency": urgency_map.get(status, 'Medium'),
                    "action": _s(req.get('notes'), 'Review and address'),
                    "timeline": f"Scheduled: {req.get('requested_date')}" if pd.notna(req.get('requested_date')) else "Not scheduled",
                    "confidence": 1.0,  # Actual requests have 100% confidence
                    "cost_estimate": "To be determined",
                    "risk_level": urgency_map.get(status, 'Medium'),
                    "requested_by": _s(req.get('requested_by_username'), 'Unknown User'),
                    "user_id": str(req.get('requested_by_id', 'unknown')),
                    "requested_by_email": _s(req.get('requested_by_email')),
                    "requested_by_role": _s(req.get('requested_by_role')),
                    "assigned_to": _s(req.get('assigned_to_username'), 'Unassigned'),
                    "status": status,
                    "created_at": req.get('created_at').isoformat() if pd.notna(req.get('created_at')) else None,
                    "resolved_at": req.get('resolved_date').isoformat() if pd.notna(req.get('resolved_date')) else None,
                    "source": "USER_REQUEST"
                }
                actual_requests.append(actual_request)
                formatted_suggestions.append(actual_request)
        
        # Generate human-readable summary
        summary_text = f"🔧 **MAINTENANCE REQUESTS**\n\n"
        
        # Count by source
        ai_predictions = len(maintenance_alerts)
        user_requests = len(actual_requests)
        total_items = len(formatted_suggestions)
        
        # Count by urgency from all suggestions
        all_urgencies = [s.get('urgency', 'Medium') for s in formatted_suggestions]
        critical_count = all_urgencies.count('Critical')
        high_count = all_urgencies.count('High')
        medium_count = all_urgencies.count('Medium')
        low_count = all_urgencies.count('Low')
        
        # Count by status
        pending_requests = [r for r in actual_requests if r.get('status') == 'pending']
        in_progress_requests = [r for r in actual_requests if r.get('status') == 'in_progress']
        resolved_requests = [r for r in actual_requests if r.get('status') == 'resolved']
        
        # Use LLM to generate intelligent maintenance insights
        llm_analysis = ""
        try:
            # Prepare maintenance data for LLM
            pending_count = len([r for r in actual_requests if r.get('status') == 'pending'])
            in_progress_count = len([r for r in actual_requests if r.get('status') == 'in_progress'])
            
            # Analyze patterns in the data
            room_issues = {}
            equipment_issues = {}
            for s in formatted_suggestions:
                room = s.get('room', 'Unknown')
                equipment = s.get('equipment', 'Unknown')
                if s.get('status') == 'pending':
                    room_issues[room] = room_issues.get(room, 0) + 1
                    equipment_issues[equipment] = equipment_issues.get(equipment, 0) + 1
            
            most_problematic_room = max(room_issues.items(), key=lambda x: x[1])[0] if room_issues else 'None'
            most_problematic_equipment = max(equipment_issues.items(), key=lambda x: x[1])[0] if equipment_issues else 'None'
            
            maintenance_context = f"""You are a maintenance manager. {pending_count} maintenance requests are pending. {most_problematic_room} has {room_issues.get(most_problematic_room, 0)} issues. {most_problematic_equipment} appears {equipment_issues.get(most_problematic_equipment, 0)} times.

Provide 3 recommendations using this exact format:

**1. PRIORITY RECOMMENDATION:**
Which room should we fix first and why?

**2. RESOURCE ESTIMATE:**
How many technicians needed for {pending_count} requests (2-3 hours each)?

**3. PATTERN ANALYSIS:**
Should we replace {most_problematic_equipment} instead of repairing it again?

Use the exact headers shown above. Be concise (2-3 sentences each)."""            
            # Call LLM directly for better analysis (bypass vector store)
            try:
                llm_analysis = sanitize_llm_output(_llm.invoke(maintenance_context))
                logger.info(f"LLM maintenance analysis generated for {username} (direct call)")
            except Exception as llm_error:
                logger.warning(f"Direct LLM call failed: {llm_error}, trying ask()")
                llm_result = ask(
                    query=maintenance_context,
                    user_id=user_id,
                    username=username,
                    session_id=f"maintenance_{datetime.now().timestamp()}",
                    client_ip=request.remote_addr
                )
                llm_analysis = sanitize_llm_output(llm_result.get('answer', ''))
                logger.info(f"LLM maintenance analysis generated for {username} (fallback)")
        except Exception as e:
            logger.warning(f"LLM analysis failed, using fallback: {e}")
            llm_analysis = f"""**PRIORITY ACTIONS**:
• Address {critical_count + high_count} high-priority items first
• Review pending requests: {len([r for r in actual_requests if r.get('status') == 'pending'])} items

**RESOURCE ALLOCATION**:
• Assign technicians to critical issues immediately
• Schedule maintenance windows for medium-priority items

**PREVENTIVE MEASURES**:
• Implement regular inspection schedules
• Monitor equipment performance trends
• Keep maintenance logs updated
"""
        
        if user_requests > 0:
            summary_text += f"📋 **Status Overview:**\n"
            summary_text += f"• Total Requests: **{user_requests}**\n"
            summary_text += f"• ⏳ Pending: **{len(pending_requests)}**\n"
            summary_text += f"• 🔄 In Progress: **{len(in_progress_requests)}**\n"
            summary_text += f"• ✅ Resolved: **{len(resolved_requests)}**\n\n"
            
            if pending_requests:
                summary_text += f"🔴 **Pending Issues ({len(pending_requests)}):**\n\n"
                for idx, req in enumerate(pending_requests[:10], 1):  # Show first 10 pending
                    issue = req.get('issue', 'No description provided')
                    room = req.get('room', 'Unknown Room')
                    equipment = req.get('equipment', 'Unknown Equipment')
                    requested_by = req.get('requested_by', 'Unknown')
                    created_at = req.get('created_at')
                    
                    # Format timestamp
                    if created_at:
                        try:
                            from datetime import datetime as dt_class
                            if isinstance(created_at, str):
                                dt = dt_class.fromisoformat(created_at.replace('Z', '+00:00'))
                            else:
                                dt = created_at
                            timestamp = dt.strftime("%b %d, %Y %I:%M %p")
                        except:
                            timestamp = str(created_at)[:19]
                    else:
                        timestamp = "No date"
                    
                    summary_text += f"**{idx}. {equipment}** - {room}\n"
                    summary_text += f"   📝 Issue: {issue}\n"
                    summary_text += f"   👤 Requested by: {requested_by}\n"
                    summary_text += f"   🕐 Created: {timestamp}\n\n"
                
                if len(pending_requests) > 10:
                    summary_text += f"_...and {len(pending_requests) - 10} more pending requests_\n\n"
            
            if resolved_requests:
                summary_text += f"✅ **Recently Resolved ({len(resolved_requests)}):**\n\n"
                for idx, req in enumerate(resolved_requests[:5], 1):  # Show first 5 resolved
                    issue = req.get('issue', 'No description')
                    equipment = req.get('equipment', 'Unknown Equipment')
                    resolved_at = req.get('resolved_at')
                    
                    if resolved_at:
                        try:
                            from datetime import datetime as dt_class
                            if isinstance(resolved_at, str):
                                dt = dt_class.fromisoformat(resolved_at.replace('Z', '+00:00'))
                            else:
                                dt = resolved_at
                            timestamp = dt.strftime("%b %d, %Y %I:%M %p")
                        except:
                            timestamp = str(resolved_at)[:19]
                    else:
                        timestamp = "No date"
                    
                    summary_text += f"**{idx}. {equipment}**: {issue}\n"
                    summary_text += f"   🕐 Resolved: {timestamp}\n\n"
        
        # Only show "no issues" message if there are truly no requests
        if not formatted_suggestions:
            summary_text += "\n✅ No maintenance issues detected.\n"
            summary_text += "All equipment is operating within normal parameters.\n\n"
            # Use LLM for preventive recommendations even when no issues
            try:
                preventive_query = f"""No maintenance issues detected. Provide preventive maintenance recommendations for a building management system.

Provide:
1. **PREVENTIVE SCHEDULE**: What to check regularly
2. **MONITORING TIPS**: Key metrics to track
3. **BEST PRACTICES**: Maintenance optimization

Be specific and actionable."""
                llm_result = ask(
                    query=preventive_query,
                    user_id=user_id,
                    username=username,
                    session_id=f"maintenance_preventive_{datetime.now().timestamp()}",
                    client_ip=request.remote_addr
                )
                llm_analysis = sanitize_llm_output(llm_result.get('answer', ''))
            except:
                llm_analysis = """**PREVENTIVE SCHEDULE**:
• Weekly: Visual inspections
• Monthly: Performance checks
• Quarterly: Deep maintenance

**MONITORING TIPS**:
• Track energy consumption patterns
• Monitor equipment runtime hours
• Log all maintenance activities

**BEST PRACTICES**:
• Maintain detailed records
• Train staff on early warning signs
• Keep spare parts inventory updated
"""
        
        response = {
            "status": "success",
            "analysis_type": "predictive_maintenance",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "requested_by": {
                "user_id": user_id,
                "username": username
            },
            "summary": {
                "anomalies_detected": len(anomalies),
                "ai_predictions": ai_predictions,
                "user_requests": user_requests,
                "total_maintenance_items": total_items,
                "equipment_analyzed": len(equipment_analysis),
                "data_points": len(df),
                "critical_count": critical_count,
                "high_count": high_count,
                "medium_count": medium_count,
                "low_count": low_count,
                "pending_requests": len([r for r in actual_requests if r.get('status') == 'pending']),
                "in_progress_requests": len([r for r in actual_requests if r.get('status') == 'in_progress']),
                "resolved_requests": len([r for r in actual_requests if r.get('status') == 'resolved'])
            },
            "summary_text": sanitize_llm_output(summary_text),
            "llm_analysis": sanitize_llm_output(llm_analysis),
            "anomalies": [
                {
                    "type": getattr(a, 'anomaly_type', 'Unknown'),
                    "severity": getattr(a, 'severity', 'Medium'),
                    "description": getattr(a, 'description', 'Anomaly detected'),
                    "confidence": getattr(a, 'confidence', 0.5),
                    "location": getattr(a, 'location', 'Unknown'),
                    "impact": getattr(a, 'impact', ''),
                    "recommendation": getattr(a, 'recommendation', '')
                } for a in anomalies
            ] if anomalies else [],
            "maintenance_suggestions": formatted_suggestions,
            "equipment_analysis": equipment_analysis,
            "recommendations": [
                "Schedule regular preventive maintenance",
                "Monitor equipment performance metrics",
                "Keep maintenance logs updated",
                "Review high-priority items within their timelines"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Maintenance prediction error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Maintenance analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/rooms/list', methods=['GET', 'POST', 'OPTIONS'])
def list_rooms():
    """
    Get list of all rooms with detailed information
    Accepts optional 'query' parameter to customize LLM response
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        # Get optional query parameter to customize response
        user_query = None
        if request.method == 'POST':
            data = request.get_json() or {}
            user_query = data.get('query', '').lower()
        else:
            user_query = request.args.get('query', '').lower()
        
        from database_adapter import DatabaseAdapter
        db_adapter = DatabaseAdapter()
        
        # Get detailed room information
        rooms_df = db_adapter.get_rooms_detailed()
        
        if rooms_df is None or rooms_df.empty:
            logger.warning("No rooms found in database")
            fallback_summary = "🏢 **ROOM DIRECTORY**\n\n❌ No rooms found in the system.\n\nPlease ensure:\n• Rooms are configured in the database\n• Database connection is working\n• Room data has been populated"
            return jsonify({
                "status": "success",
                "rooms": [],
                "total_rooms": 0,
                "summary_text": fallback_summary,
                "llm_analysis": "No rooms available for analysis.",
                "message": "No rooms found in the system",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Format rooms data
        rooms_list = []
        for _, room in rooms_df.iterrows():
            room_data = {
                "id": str(room['id']),
                "name": room['name'],
                "floor": int(room['floor']) if pd.notna(room['floor']) else 0,
                "capacity": int(room['capacity']) if pd.notna(room['capacity']) else 0,
                "type": room['type'],
                "occupancy_pattern": room.get('occupancy_pattern', 'Not specified'),
                "typical_energy_usage": float(room['typical_energy_usage']) if pd.notna(room.get('typical_energy_usage')) else 0.0,
                "equipment_count": int(room['equipment_count']) if pd.notna(room['equipment_count']) else 0,
                "sensor_reading_count": int(room['sensor_reading_count']) if pd.notna(room['sensor_reading_count']) else 0,
                "avg_temperature": round(float(room['avg_temperature']), 1) if pd.notna(room.get('avg_temperature')) else None,
                "avg_humidity": round(float(room['avg_humidity']), 1) if pd.notna(room.get('avg_humidity')) else None,
                "avg_energy_usage": round(float(room['avg_energy_usage']), 2) if pd.notna(room.get('avg_energy_usage')) else None,
                "last_reading": room['last_reading'].isoformat() if pd.notna(room.get('last_reading')) else None,
                "created_at": room['created_at'].isoformat() if pd.notna(room.get('created_at')) else None
            }
            rooms_list.append(room_data)
        
        # Generate summary text for LLM display
        summary_text = f"🏢 **ROOM DIRECTORY**\n\n"
        summary_text += f"📊 **Total Rooms**: {len(rooms_list)}\n\n"
        
        # Group by floor
        floors = {}
        for room in rooms_list:
            floor = room['floor']
            if floor not in floors:
                floors[floor] = []
            floors[floor].append(room)
        
        for floor in sorted(floors.keys()):
            summary_text += f"**Floor {floor}:**\n"
            for room in floors[floor]:
                summary_text += f"\n📍 **{room['name']}**\n"
                summary_text += f"   • Type: {room['type'].title()}\n"
                summary_text += f"   • Capacity: {room['capacity']} people\n"
                summary_text += f"   • Equipment: {room['equipment_count']} devices\n"
                
                if room['avg_temperature']:
                    summary_text += f"   • Current Temp: {room['avg_temperature']}°C\n"
                if room['avg_humidity']:
                    summary_text += f"   • Humidity: {room['avg_humidity']}%\n"
                if room['avg_energy_usage']:
                    summary_text += f"   • Avg Energy: {room['avg_energy_usage']} kWh\n"
                
                summary_text += f"   • Pattern: {room['occupancy_pattern']}\n"
            summary_text += "\n"
        
        # Generate LLM analysis for room utilization insights
        llm_analysis = ""
        try:
            # Calculate statistics for LLM context
            total_equipment = sum(r['equipment_count'] for r in rooms_list)
            avg_temp = sum(r['avg_temperature'] for r in rooms_list if r['avg_temperature']) / len([r for r in rooms_list if r['avg_temperature']]) if any(r['avg_temperature'] for r in rooms_list) else 0
            total_energy = sum(r['avg_energy_usage'] for r in rooms_list if r['avg_energy_usage'])
            
            # Find highest and lowest energy consumers
            energy_rooms = [(r['name'], r['avg_energy_usage']) for r in rooms_list if r['avg_energy_usage']]
            if energy_rooms:
                energy_rooms.sort(key=lambda x: x[1], reverse=True)
                highest_energy = energy_rooms[0]
                lowest_energy = energy_rooms[-1]
            else:
                highest_energy = ("Unknown", 0)
                lowest_energy = ("Unknown", 0)
            
            # Determine query intent and customize LLM prompt
            is_availability_query = user_query and any(word in user_query for word in ['available', 'list', 'show', 'what rooms'])
            
            if is_availability_query:
                # For "what rooms are available" - focus on room listing
                llm_context = f"""User asked about available rooms. Provide a brief summary of the {len(rooms_list)} rooms.

ROOMS ({len(rooms_list)} total across {len(floors)} floors):
{chr(10).join([f"• {r['name']} (Floor {r['floor']}, {r['type']}, {r['capacity']} capacity)" for r in rooms_list])}

Give ONE sentence summary (max 20 words) highlighting room variety and availability."""
            else:
                # For general queries - provide optimization recommendations
                llm_context = f"""Building management AI. Analyze room data. Give 3 SHORT recommendations (max 15 words each).

DATA:
• {len(rooms_list)} rooms, {len(floors)} floors, {total_equipment} devices
• Highest energy: {highest_energy[0]} ({highest_energy[1]:.2f} kWh)
• Lowest energy: {lowest_energy[0]} ({lowest_energy[1]:.2f} kWh)

TOP 5 ROOMS:
{chr(10).join([f"• {r['name']} (F{r['floor']}): {(r['avg_energy_usage'] if r['avg_energy_usage'] is not None else 0.0):.2f} kWh" for r in rooms_list[:5]])}

Format (MAX 15 WORDS PER RECOMMENDATION):

**1. ENERGY OPTIMIZATION:**
[Target room + one action, max 15 words]

**2. SPACE UTILIZATION:**
[One specific improvement, max 15 words]

**3. EQUIPMENT MANAGEMENT:**
[One priority, max 15 words]

RULES: Use room names. Be specific. Stay under 15 words each."""

            # Call LLM directly
            logger.info("Calling Ollama LLM for room analysis...")
            llm_analysis = sanitize_llm_output(_llm.invoke(llm_context))
            logger.info(f"✅ LLM room analysis generated successfully")
            
        except Exception as llm_error:
            logger.error(f"❌ LLM analysis failed: {type(llm_error).__name__}: {llm_error}")
            import traceback
            logger.error(f"Traceback: {traceback.format_exc()}")
            llm_analysis = f"""**1. ENERGY OPTIMIZATION:**
Target {highest_energy[0]} ({highest_energy[1]:.2f} kWh) - install occupancy sensors and LED lighting.

**2. SPACE UTILIZATION:**
Implement hot-desking across {len(floors)} floors to maximize {len(rooms_list)} room utilization.

**3. EQUIPMENT MANAGEMENT:**
Schedule quarterly maintenance for {total_equipment} devices, prioritize high-energy rooms."""
        
        # Add LLM analysis to summary
        summary_text += f"\n🤖 **AI RECOMMENDATIONS**\n\n{llm_analysis}\n"
        
        db_adapter.close_connection()
        
        return jsonify({
            "status": "success",
            "rooms": rooms_list,
            "total_rooms": len(rooms_list),
            "summary_text": summary_text,
            "llm_analysis": llm_analysis,
            "floors": list(sorted(floors.keys())),
            "statistics": {
                "total_equipment": total_equipment,
                "avg_temperature": round(avg_temp, 1) if avg_temp else None,
                "total_energy": round(total_energy, 2),
                "highest_energy_room": highest_energy[0],
                "lowest_energy_room": lowest_energy[0]
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        
    except Exception as e:
        logger.error(f"Room list error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Failed to retrieve rooms: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/anomalies/detect', methods=['POST', 'OPTIONS'])
def detect_anomalies():
    """
    Anomaly detection with LLM-powered analysis
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Anomaly detection request from {username}")
        
        # Get alerts from database using DatabaseAdapter (no date restriction)
        from database_adapter import DatabaseAdapter
        db_adapter = DatabaseAdapter()
        alerts_df = db_adapter.get_alerts_with_equipment_info(days_back=365)  # Get all alerts (1 year)
        
        logger.info(f"Alerts DataFrame: {alerts_df.shape if alerts_df is not None else 'None'}")
        logger.info(f"Alerts columns: {alerts_df.columns.tolist() if alerts_df is not None and not alerts_df.empty else 'Empty'}")
        
        if alerts_df is None or alerts_df.empty:
            return jsonify({
                "status": "success",
                "answer": "No anomalies detected in the past 7 days. All systems operating normally.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Calculate statistics
        total_alerts = len(alerts_df)
        unresolved = alerts_df[alerts_df['is_resolved'] == False] if 'is_resolved' in alerts_df.columns else alerts_df
        unresolved_count = len(unresolved)
        
        # Group by severity
        severity_counts = alerts_df['severity_level'].value_counts().to_dict() if 'severity_level' in alerts_df.columns else {}
        
        # Group by type
        type_counts = alerts_df['alert_type'].value_counts().to_dict() if 'alert_type' in alerts_df.columns else {}
        
        # Prepare LLM context
        llm_context = f"""You are a system anomaly analyst. Analyze these alerts and provide recommendations.

ANOMALY DATA:
- Total Alerts (7 days): {total_alerts}
- Unresolved: {unresolved_count}
- By Severity: {severity_counts}
- By Type: {type_counts}

TOP ALERT TYPES:
"""
        for alert_type, count in list(type_counts.items())[:5]:
            llm_context += f"• {alert_type}: {count} occurrences\n"
        
        llm_context += f"""\n\nProvide 3 recommendations using this format:

**1. CRITICAL ISSUES:**
What anomalies need immediate attention?

**2. PATTERN ANALYSIS:**
What patterns do you see in the alerts?

**3. PREVENTIVE ACTIONS:**
What can we do to prevent these anomalies?

Be concise (2-3 sentences each)."""
        
        # Call LLM
        try:
            llm_analysis = sanitize_llm_output(_llm.invoke(llm_context))
            logger.info(f"LLM anomaly analysis generated for {username}")
        except Exception as llm_error:
            logger.warning(f"LLM call failed: {llm_error}")
            llm_analysis = f"""**1. CRITICAL ISSUES:**
{unresolved_count} unresolved alerts need attention.

**2. PATTERN ANALYSIS:**
Most common: {list(type_counts.keys())[0] if type_counts else 'No pattern'} with {list(type_counts.values())[0] if type_counts else 0} occurrences.

**3. PREVENTIVE ACTIONS:**
Monitor alert trends and address root causes proactively."""
        
        # Prepare alert list
        alerts_list = []
        try:
            if alerts_df is not None and not alerts_df.empty:
                # Normalize types
                if 'created_at' in alerts_df.columns:
                    alerts_df['created_at'] = pd.to_datetime(alerts_df['created_at'], errors='coerce')
                if 'resolved_at' in alerts_df.columns:
                    alerts_df['resolved_at'] = pd.to_datetime(alerts_df['resolved_at'], errors='coerce')

                for _, row in alerts_df.head(10).iterrows():
                    alerts_list.append({
                        "type": row.get('alert_type'),
                        "message": row.get('message'),
                        "severity": row.get('severity_level'),
                        "timestamp": row['created_at'].isoformat() if pd.notna(row.get('created_at')) else None,
                        "is_resolved": bool(row.get('is_resolved')),
                        "equipment": row.get('equipment_name')
                    })
        except Exception as e:
            logger.warning(f"Failed to process alerts: {e}")
        
        # Build formatted response with actual alerts
        summary_text = f"⚠️ **SYSTEM ALERTS**\n\n"
        summary_text += f"📊 **Alert Summary:**\n"
        summary_text += f"• Total Alerts: **{total_alerts}**\n"
        summary_text += f"• Unresolved: **{unresolved_count}**\n"
        
        if severity_counts:
            summary_text += f"\n**By Severity:**\n"
            for severity, count in severity_counts.items():
                emoji = "🔴" if severity == "high" else "🟠" if severity == "medium" else "🟡"
                summary_text += f"• {emoji} {severity.title()}: {count}\n"
        
        if type_counts:
            summary_text += f"\n**By Type:**\n"
            for alert_type, count in list(type_counts.items())[:5]:
                summary_text += f"• {alert_type}: {count} occurrences\n"
        
        # Add recent alerts
        if alerts_list:
            summary_text += f"\n\n📋 **Recent Alerts ({min(len(alerts_list), 10)}):**\n\n"
            for idx, alert in enumerate(alerts_list[:10], 1):
                severity_emoji = "🔴" if alert.get('severity') == "high" else "🟠" if alert.get('severity') == "medium" else "🟡"
                status_emoji = "✅" if alert.get('is_resolved') else "🔴"
                
                summary_text += f"**{idx}. [{alert.get('severity', 'unknown').upper()}] {alert.get('type', 'Unknown')}**\n"
                summary_text += f"   {severity_emoji} {alert.get('message', 'No description')}\n"
                if alert.get('equipment'):
                    summary_text += f"   🔧 Equipment: {alert['equipment']}\n"
                if alert.get('timestamp'):
                    try:
                        from datetime import datetime as dt_class
                        dt = dt_class.fromisoformat(alert['timestamp'].replace('Z', '+00:00'))
                        timestamp_str = dt.strftime("%b %d, %Y %I:%M %p")
                        summary_text += f"   📅 {timestamp_str}\n"
                    except:
                        summary_text += f"   📅 {alert['timestamp'][:19]}\n"
                summary_text += f"   {status_emoji} {'Resolved' if alert.get('is_resolved') else 'Active'}\n\n"
        
        # Add LLM analysis
        summary_text += f"\n🤖 **AI ANALYSIS**\n\n{llm_analysis}\n"
        
        response = {
            "status": "success",
            "answer": summary_text,
            "llm_analysis": llm_analysis,
            "alert_summary": {
                "total_alerts": total_alerts,
                "unresolved": unresolved_count,
                "by_severity": severity_counts,
                "by_type": type_counts
            },
            "sample_alerts": alerts_list,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Anomaly detection error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Anomaly detection failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/billing/rates', methods=['POST', 'OPTIONS'])
def billing_rates():
    """Get billing rates with LLM-powered cost optimization suggestions"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Billing rates analysis request from {username}")
        
        # Initialize analyzer
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="billing_analysis",
            document_template="billing_report"
        )
        
        # Fetch billing rates from database
        billing_df = analyzer.db_adapter.get_billing_rates_dataframe()
        
        if billing_df is None or billing_df.empty:
            return jsonify({
                "status": "success",
                "answer": "No billing rates configured yet.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Calculate statistics
        avg_rate = billing_df['rate_per_kwh'].mean()
        min_rate = billing_df['rate_per_kwh'].min()
        max_rate = billing_df['rate_per_kwh'].max()
        total_rates = len(billing_df)
        
        # Prepare rates list
        rates_list = []
        for _, row in billing_df.iterrows():
            rates_list.append({
                "rate": float(row['rate_per_kwh']),
                "currency": row.get('currency', 'PHP'),
                "start_time": str(row.get('start_time')) if pd.notna(row.get('start_time')) else None,
                "end_time": str(row.get('end_time')) if pd.notna(row.get('end_time')) else None,
                "valid_from": row['valid_from'].isoformat() if pd.notna(row.get('valid_from')) else None,
                "valid_to": row['valid_to'].isoformat() if pd.notna(row.get('valid_to')) else None
            })
        
        # Prepare LLM context
        llm_context = f"""Analyze electricity billing rates and provide cost optimization recommendations.

BILLING RATES SUMMARY:
- Total rate configurations: {total_rates}
- Average rate: {avg_rate:.4f} PHP per kWh
- Lowest rate: {min_rate:.4f} PHP per kWh
- Highest rate: {max_rate:.4f} PHP per kWh
- Currency: PHP

RATE DETAILS:
"""
        for i, rate in enumerate(rates_list[:5], 1):
            llm_context += f"{i}. {rate['rate']:.4f} per kWh ({rate['start_time']} - {rate['end_time']})\n"
        
        llm_context += f"""\n\nProvide 3 recommendations using this format:

**1. RATE ANALYSIS:**
What patterns do you see in the billing rates? Are there peak/off-peak opportunities?

**2. COST OPTIMIZATION:**
How can we reduce electricity costs based on these rates?

**3. ACTION ITEMS:**
What specific actions should we take to optimize billing costs?

Be concise (2-3 sentences each)."""
        
        # Call LLM
        try:
            llm_analysis = sanitize_llm_output(_llm.invoke(llm_context))
            logger.info(f"LLM billing analysis generated for {username}")
        except Exception as llm_error:
            logger.warning(f"LLM call failed: {llm_error}")
            llm_analysis = f"""**1. RATE ANALYSIS:**
Average rate is {avg_rate:.4f} per kWh with variation from {min_rate:.4f} to {max_rate:.4f}.

**2. COST OPTIMIZATION:**
Focus energy consumption during lower-rate periods to reduce costs.

**3. ACTION ITEMS:**
Schedule high-energy tasks during off-peak hours when rates are lowest."""
        
        response = {
            "status": "success",
            "answer": llm_analysis,
            "billing_data": {
                "total_rates": total_rates,
                "average_rate": float(avg_rate),
                "min_rate": float(min_rate),
                "max_rate": float(max_rate),
                "currency": "PHP",  # Always use PHP
                "rates": rates_list
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Billing rates analysis error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Billing analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/kpi/heartbeat', methods=['POST', 'OPTIONS'])
def kpi_heartbeat_analysis():
    """Analyze system health KPIs from heartbeat logs with LLM insights"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"KPI heartbeat analysis request from {username}")
        
        # Fetch heartbeat data using raw SQL
        from database_adapter import DatabaseAdapter
        db_adapter = DatabaseAdapter()
        
        query = """
        SELECT 
            id, timestamp, dht22_working, pzem_working, success_rate,
            wifi_signal, uptime, sensor_type, current_temp, current_humidity,
            current_power, recorded_at, equipment_id, photoresistor_working,
            failed_readings, pzem_error_count, voltage_stability
        FROM core_heartbeatlog
        ORDER BY recorded_at DESC
        LIMIT 100
        """
        
        heartbeat_df = pd.read_sql_query(query, db_adapter.connection)
        
        if heartbeat_df.empty:
            return jsonify({
                "status": "success",
                "answer": "No heartbeat data available yet.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        # Calculate KPIs
        avg_success_rate = heartbeat_df['success_rate'].mean()
        avg_wifi_signal = heartbeat_df['wifi_signal'].mean()
        avg_uptime = heartbeat_df['uptime'].mean()
        avg_voltage_stability = heartbeat_df['voltage_stability'].mean()
        total_failed_readings = heartbeat_df['failed_readings'].sum()
        total_pzem_errors = heartbeat_df['pzem_error_count'].sum()
        
        # Sensor health
        dht22_health = (heartbeat_df['dht22_working'].sum() / len(heartbeat_df)) * 100
        pzem_health = (heartbeat_df['pzem_working'].sum() / len(heartbeat_df)) * 100
        photoresistor_health = (heartbeat_df['photoresistor_working'].sum() / len(heartbeat_df)) * 100
        
        # Prepare LLM context
        llm_context = f"""You are a system health analyst. Analyze these IoT device health metrics and provide insights.

SYSTEM HEALTH KPIs:
- Average Success Rate: {avg_success_rate:.2f}%
- Average WiFi Signal: {avg_wifi_signal:.1f} dBm
- Average Uptime: {avg_uptime/3600:.1f} hours
- Average Voltage Stability: {avg_voltage_stability:.2f}
- Total Failed Readings: {total_failed_readings}
- Total PZEM Errors: {total_pzem_errors}

SENSOR HEALTH:
- DHT22 (Temp/Humidity): {dht22_health:.1f}% operational
- PZEM (Power Meter): {pzem_health:.1f}% operational  
- Photoresistor (Light): {photoresistor_health:.1f}% operational

Data Points Analyzed: {len(heartbeat_df)}

Provide 3 recommendations using this format:

**1. SYSTEM HEALTH ASSESSMENT:**
What is the overall health status of the IoT sensors?

**2. CRITICAL ISSUES:**
What problems need immediate attention?

**3. MAINTENANCE RECOMMENDATIONS:**
What preventive actions should be taken?

Be concise (2-3 sentences each)."""
        
        # Call LLM
        try:
            llm_analysis = sanitize_llm_output(_llm.invoke(llm_context))
            logger.info(f"LLM KPI analysis generated for {username}")
        except Exception as llm_error:
            logger.warning(f"LLM call failed: {llm_error}")
            llm_analysis = f"""**1. SYSTEM HEALTH ASSESSMENT:**
System shows {avg_success_rate:.1f}% success rate with sensors mostly operational.

**2. CRITICAL ISSUES:**
{total_failed_readings} failed readings and {total_pzem_errors} PZEM errors need investigation.

**3. MAINTENANCE RECOMMENDATIONS:**
Monitor WiFi signal strength and check sensors with low operational rates."""
        
        response = {
            "status": "success",
            "answer": llm_analysis,
            "kpi_data": {
                "success_rate": float(avg_success_rate),
                "wifi_signal": float(avg_wifi_signal),
                "uptime_hours": float(avg_uptime / 3600),
                "voltage_stability": float(avg_voltage_stability),
                "total_failed_readings": int(total_failed_readings),
                "total_pzem_errors": int(total_pzem_errors),
                "sensor_health": {
                    "dht22": float(dht22_health),
                    "pzem": float(pzem_health),
                    "photoresistor": float(photoresistor_health)
                },
                "data_points": len(heartbeat_df)
            },
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"KPI heartbeat analysis error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"KPI analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/chat/history/save', methods=['POST', 'OPTIONS'])
def save_chat_history():
    """Save chat message to MongoDB"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        if chat_collection is None:
            return jsonify({
                "status": "warning",
                "message": "MongoDB not connected. Chat not saved.",
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        data = request.get_json() or {}
        
        # Create chat document
        chat_document = {
            "user_id": data.get('user_id', 'anonymous'),
            "username": data.get('username', 'anonymous'),
            "session_id": data.get('session_id', f"session_{datetime.now().timestamp()}"),
            "user_message": data.get('user_message', ''),
            "assistant_response": data.get('assistant_response', ''),
            "query_type": data.get('query_type', 'general'),
            "timestamp": datetime.now(timezone.utc),
            "metadata": {
                "user_role": data.get('user_role', 'viewer'),
                "response_time_ms": data.get('response_time_ms'),
                "has_error": data.get('has_error', False)
            }
        }
        
        # Insert into MongoDB
        result = chat_collection.insert_one(chat_document)
        
        logger.info(f"Chat saved to MongoDB: {result.inserted_id}")
        
        return jsonify({
            "status": "success",
            "message": "Chat history saved",
            "chat_id": str(result.inserted_id),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error saving chat history: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Failed to save chat: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/chat/history/get', methods=['POST', 'OPTIONS'])
def get_chat_history():
    """Retrieve chat history from MongoDB"""
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        if chat_collection is None:
            return jsonify({
                "status": "warning",
                "message": "MongoDB not connected",
                "chats": [],
                "timestamp": datetime.now(timezone.utc).isoformat()
            })
        
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        session_id = data.get('session_id')
        limit = data.get('limit', 50)
        
        # Build query
        query = {"user_id": user_id}
        if session_id:
            query["session_id"] = session_id
        
        # Fetch chat history
        chats = list(chat_collection.find(query).sort("timestamp", DESCENDING).limit(limit))
        
        # Convert ObjectId to string
        for chat in chats:
            chat['_id'] = str(chat['_id'])
            chat['timestamp'] = chat['timestamp'].isoformat()
        
        return jsonify({
            "status": "success",
            "chats": chats,
            "count": len(chats),
            "timestamp": datetime.now(timezone.utc).isoformat()
        })
        
    except Exception as e:
        logger.error(f"Error retrieving chat history: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Failed to retrieve chat: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/system/status', methods=['GET'])
def system_status():
    """Comprehensive system status endpoint"""
    mongodb_status = "connected" if chat_collection is not None else "disconnected"
    
    return jsonify({
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system_health": system_health,
        "mongodb_status": mongodb_status,
        "endpoints_available": [
            {"path": "/health", "methods": ["GET"], "description": "System health check"},
            {"path": "/llmquery", "methods": ["POST"], "description": "General LLM queries"},
            {"path": "/insights/energy", "methods": ["POST"], "description": "Energy consumption analysis"},
            {"path": "/maintenance/predict", "methods": ["POST"], "description": "Predictive maintenance"},
            {"path": "/anomalies/detect", "methods": ["POST"], "description": "Anomaly detection"},
            {"path": "/reports/weekly", "methods": ["POST"], "description": "Weekly summary reports"},
            {"path": "/rooms/utilization", "methods": ["POST"], "description": "Room usage analysis"},
            {"path": "/context/analyze", "methods": ["POST"], "description": "Context-aware analysis"},
            {"path": "/system/status", "methods": ["GET"], "description": "Comprehensive system status"}
        ]
    })

# Enhanced role-based access control
def require_role(required_role: str):
    """Enhanced decorator for role-based access control with logging"""
    def decorator(f):
        def decorated_function(*args, **kwargs):
            user_role = request.headers.get('X-User-Role', 'viewer')
            user_id = request.get_json().get('user_id', 'anonymous') if request.get_json() else 'unknown'
            
            role_permissions = {
                'admin': ['all'],
                'facility_manager': ['maintenance', 'reports', 'anomalies', 'energy', 'utilization', 'context'],
                'energy_analyst': ['energy', 'reports', 'context'],
                'technician': ['maintenance', 'anomalies'],
                'viewer': ['reports', 'utilization', 'context'],
                'guest': ['reports']
            }
            
            if user_role not in role_permissions:
                logger.warning(f"Unauthorized role attempt: {user_role} by {user_id}")
                return jsonify({
                    "error": "Unauthorized role",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }), 401
            
            if required_role not in role_permissions[user_role] and 'all' not in role_permissions[user_role]:
                logger.warning(f"Insufficient permissions: {user_role} tried to access {required_role} by {user_id}")
                return jsonify({
                    "error": f"Insufficient permissions. Role '{user_role}' cannot access '{required_role}' features",
                    "timestamp": datetime.now(timezone.utc).isoformat()
                }), 403
            
            logger.info(f"Access granted: {user_role} accessing {required_role} by {user_id}")
            return f(*args, **kwargs)
        decorated_function.__name__ = f.__name__
        return decorated_function
    return decorator

# Apply enhanced role-based access control (only for existing endpoints)
predict_maintenance = require_role('maintenance')(predict_maintenance)
detect_anomalies = require_role('anomalies')(detect_anomalies)
# Removed decorators for deleted endpoints: generate_weekly_summary, energy_insights, room_utilization, context_analysis

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({
        "status": "error",
        "error": "Endpoint not found",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 404

@app.errorhandler(405)
def method_not_allowed(error):
    return jsonify({
        "status": "error", 
        "error": "Method not allowed",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 405

@app.errorhandler(500)
def internal_error(error):
    return jsonify({
        "status": "error",
        "error": "Internal server error",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }), 500

if __name__ == '__main__':
    print("🚀 INITIALIZING ENHANCED ADVANCED LLM API SERVER")
    print("=" * 60)
    
    # Initialize MongoDB for chat history
    mongodb_connected = initialize_mongodb()
    if mongodb_connected:
        print("✅ MongoDB connected - Chat history will be saved")
    else:
        print("⚠️  MongoDB not connected - Chat history will NOT be saved")
    
    # Initialize system
    if initialize_system():
        print("✅ System initialized successfully")
        print(f"📊 System Health: {system_health['status']}")
        print(f"📈 Data Quality: {system_health.get('data_quality', 'unknown')}")
        print(f"🗂️  Records Loaded: {system_health.get('records_loaded', 0)}")
        
        print("\n🎯 Enhanced Capabilities:")
        print("• Real-time data quality assessment")
        print("• Comprehensive pattern detection") 
        print("• Advanced statistical analysis")
        print("• Robust fallback mechanisms")
        print("• Enhanced error handling")
        print("• Detailed analytics and insights")
        
        print("\n📡 Available Endpoints:")
        endpoints = [
            ("GET   /health", "System health check"),
            ("POST  /llmquery", "General LLM chat queries (auto-routes room queries)"),
            ("GET   /rooms/list", "List all rooms with details"),
            ("POST  /energy/report", "Energy analysis (daily/weekly/monthly/yearly)"),
            ("POST  /maintenance/predict", "Maintenance predictions with LLM"),
            ("POST  /anomalies/detect", "Anomaly detection"),
            ("POST  /billing/rates", "Billing analysis with LLM"),
            ("POST  /kpi/heartbeat", "KPI monitoring"),
            ("POST  /chat/history/save", "Save chat to MongoDB"),
            ("POST  /chat/history/get", "Retrieve chat history"),
            ("GET   /system/status", "System status"),
            ("", ""),
            ("POST  /ask", "Legacy: redirects to /llmquery"),
            ("POST  /reports/weekly", "Legacy: redirects to /energy/report")
        ]
        
        for endpoint, description in endpoints:
            print(f"  {endpoint:<30} {description}")
        
        print("\n🔐 Role-Based Access:")
        roles = {
            'admin': 'Full system access',
            'facility_manager': 'Maintenance, energy, anomalies, billing, KPI',
            'energy_analyst': 'Energy analysis, billing, KPI',
            'technician': 'Maintenance and anomaly access', 
            'viewer': 'Energy reports and KPI monitoring'
        }
        
        for role, access in roles.items():
            print(f"  {role:<18} {access}")
        
        print(f"\n🌐 Starting enhanced server on http://localhost:5000")
        print("💡 Debug mode: ON")
        print("📝 Logs: apillm_enhanced.log")
        
        app.run(debug=True, host='0.0.0.0', port=5000, threaded=True)
    else:
        print("❌ Failed to initialize system")
        print("🔧 Troubleshooting suggestions:")
        print("  • Check database connection")
        print("  • Verify environment variables")
        print("  • Ensure required packages are installed")
        print("  • Review apillm_enhanced.log for details")
        sys.exit(1)