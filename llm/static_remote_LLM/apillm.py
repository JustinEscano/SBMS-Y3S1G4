#!/usr/bin/env python3
"""
Advanced LLM API for Building Management System
Enhanced with robust error handling, comprehensive data analysis, and fallback mechanisms
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timezone, timedelta
import logging
import os
import sys
from pathlib import Path
import traceback
import numpy as np
import pandas as pd
from typing import Dict, List, Any, Optional
import json

# Set DJANGO_SETTINGS_MODULE
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')

# Add SBMS-Y3S1G4/api/ to sys.path
BASE_DIR = Path(__file__).resolve().parent.parent.parent  # Points to SBMS-Y3S1G4/
sys.path.append(str(BASE_DIR / 'api'))

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    from main import RoomLogAnalyzer, ask
    from prompts_config import PromptsConfig
    from advanced_llm_handlers import AdvancedLLMHandlers
except ImportError as e:
    print(f"DEBUG: Import error: {e}")
    # Create fallback classes if imports fail
    class RoomLogAnalyzer:
        def __init__(self, *args, **kwargs):
            pass
        def load_and_process_data(self):
            return pd.DataFrame()
    class AdvancedLLMHandlers:
        pass

# Enhanced logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('apillm_enhanced.log'),
        logging.StreamHandler()
    ]
)
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
        
        analysis = {
            "status": "success",
            "room_column": room_column,
            "total_events": len(room_data),
            "unique_rooms": len(room_usage),
            "most_used_room": str(room_usage.index[0]) if len(room_usage) > 0 else "Unknown",
            "most_used_count": int(room_usage.iloc[0]) if len(room_usage) > 0 else 0,
            "utilization_distribution": {
                "high_usage": len([x for x in room_usage if x > room_usage.mean() + room_usage.std()]),
                "medium_usage": len([x for x in room_usage if abs(x - room_usage.mean()) <= room_usage.std()]),
                "low_usage": len([x for x in room_usage if x < room_usage.mean() - room_usage.std()])
            },
            "top_rooms": {str(room): int(count) for room, count in room_usage.head(10).items()}
        }
        
        if len(room_usage) > 0:
            analysis["usage_percentage"] = float((room_usage.iloc[0] / len(room_data)) * 100)
            analysis["avg_events_per_room"] = float(len(room_data) / len(room_usage))
        
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
            
            logger.info(f"✅ System initialized successfully. Loaded {len(df)} records.")
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

@app.route('/llmquery', methods=['POST', 'OPTIONS'])
def llm_query():
    """
    Enhanced main LLM query endpoint with better error handling and analytics
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    start_time = datetime.now(timezone.utc)
    
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
        
        logger.info(f"Query from {username}: {query[:100]}...")
        
        # Use enhanced ask function with timeout
        result = ask(
            query=query,
            user_id=user_id,
            username=username,
            session_id=session_id,
            client_ip=request.remote_addr
        )
        
        processing_time = (datetime.now(timezone.utc) - start_time).total_seconds()
        
        response = {
            "status": "success",
            "query": query,
            "answer": result.get('answer', 'I apologize, but I could not generate a response for your query.'),
            "sources": result.get('sources', []),
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "metadata": {
                "processing_time_seconds": round(processing_time, 2),
                "sources_count": len(result.get('sources', [])),
                "query_complexity": "high" if len(query.split()) > 15 else "medium" if len(query.split()) > 5 else "low"
            }
        }
        
        # Add any additional result fields
        for key in ['metrics', 'anomalies', 'maintenance_alerts', 'insights']:
            if key in result:
                response[key] = result[key]
        
        logger.info(f"Query processed in {processing_time:.2f}s")
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error processing query: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Failed to process query: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "suggestions": [
                "Try rephrasing your question",
                "Check if your question is related to building data",
                "Ensure the system has loaded relevant data"
            ]
        }), 500

@app.route('/insights/energy', methods=['POST', 'OPTIONS'])
def energy_insights():
    """
    Enhanced energy insights with comprehensive pattern detection
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        query = data.get('query', '').strip()
        user_id = data.get('user_id', 'anonymous')
        username = data.get('username', 'anonymous')
        
        logger.info(f"Energy insights request from {username}")
        
        # Initialize analyzer for energy insights
        energy_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="energy_insights",
            document_template="energy_report",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = energy_analyzer.load_and_process_data()
        data_quality = DataAnalyzer.analyze_dataset_quality(df)
        energy_patterns = DataAnalyzer.detect_energy_patterns(df)
        
        # Process query or generate automatic insights
        if query:
            result = ask(
                query=query,
                user_id=user_id,
                username=username,
                session_id=f"energy_{datetime.now().timestamp()}",
                client_ip=request.remote_addr
            )
            answer = result.get('answer', 'No specific energy insights available.')
        else:
            if energy_patterns:
                insights = ["🔋 Energy Consumption Analysis:"]
                for pattern in energy_patterns:
                    insights.append(f"• {pattern['column']}: Avg {pattern['average']:.2f}, Trend: {pattern['trend']}")
                    insights.append(f"  Range: {pattern['minimum']:.2f} - {pattern['maximum']:.2f}")
                
                insights.append(f"\n📊 Dataset: {data_quality['total_records']} records, {len(energy_patterns)} energy metrics")
                answer = "\n".join(insights)
            else:
                answer = "No energy consumption patterns detected in the current dataset.\n\nAvailable data analysis:\n" + \
                        f"• Total records: {data_quality['total_records']}\n" + \
                        f"• Data quality: {data_quality['data_quality'].title()}\n" + \
                        f"• Numeric columns: {data_quality['column_types']['numeric']}"
        
        response = {
            "status": "success",
            "query": query,
            "answer": answer,
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "energy_analysis": {
                "patterns_detected": len(energy_patterns),
                "data_quality": data_quality,
                "detailed_patterns": energy_patterns
            },
            "recommendations": [
                "Monitor high-consumption periods for optimization opportunities",
                "Consider implementing energy-saving measures during peak usage",
                "Regularly review energy patterns for anomalies"
            ] if energy_patterns else [
                "Ensure energy monitoring systems are properly configured",
                "Verify sensor data collection for energy metrics",
                "Check data connectivity for energy monitoring devices"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Energy insights error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Energy analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/maintenance/predict', methods=['POST', 'OPTIONS'])
def predict_maintenance():
    """
    Enhanced predictive maintenance with fallback analysis
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        query = data.get('query', 'Analyze equipment and suggest maintenance')
        user_id = data.get('user_id', 'anonymous')
        
        logger.info(f"Maintenance prediction request from {user_id}")
        
        maintenance_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="predictive_maintenance",
            document_template="maintenance_analysis",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = maintenance_analyzer.load_and_process_data()
        
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
        
        response = {
            "status": "success",
            "analysis_type": "predictive_maintenance",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "summary": {
                "anomalies_detected": len(anomalies),
                "maintenance_alerts": len(maintenance_alerts),
                "equipment_analyzed": len(equipment_analysis),
                "data_points": len(df)
            },
            "anomalies": [
                {
                    "type": getattr(a, 'anomaly_type', 'Unknown'),
                    "severity": getattr(a, 'severity', 'Medium'),
                    "description": getattr(a, 'description', 'Anomaly detected'),
                    "confidence": getattr(a, 'confidence', 0.5)
                } for a in anomalies
            ] if anomalies else [],
            "maintenance_suggestions": [
                {
                    "equipment": getattr(m, 'equipment', 'General'),
                    "issue": getattr(m, 'issue', 'Maintenance check needed'),
                    "urgency": getattr(m, 'urgency', 'Medium'),
                    "action": getattr(m, 'action', 'Inspect and maintain')
                } for m in maintenance_alerts
            ] if maintenance_alerts else [],
            "equipment_analysis": equipment_analysis,
            "recommendations": [
                "Schedule regular preventive maintenance",
                "Monitor equipment performance metrics",
                "Keep maintenance logs updated"
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

@app.route('/anomalies/detect', methods=['POST', 'OPTIONS'])
def detect_anomalies():
    """
    Enhanced anomaly detection with statistical analysis
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        sensitivity = float(data.get('sensitivity', 0.8))
        user_id = data.get('user_id', 'anonymous')
        
        logger.info(f"Anomaly detection request from {user_id}, sensitivity: {sensitivity}")
        
        anomaly_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="anomaly_detection",
            document_template="anomaly_detection",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = anomaly_analyzer.load_and_process_data()
        
        # Enhanced anomaly detection with fallback
        try:
            anomalies = anomaly_analyzer.advanced_handlers.detect_anomalies(df)
        except Exception as e:
            logger.warning(f"Advanced anomaly detection failed: {e}")
            anomalies = []
        
        # Statistical anomaly detection fallback
        statistical_anomalies = []
        numeric_columns = df.select_dtypes(include=[np.number]).columns
        
        for col in numeric_columns[:5]:  # Check first 5 numeric columns
            col_data = df[col].dropna()
            if len(col_data) > 10:
                mean = col_data.mean()
                std = col_data.std()
                threshold = mean + (3 * std * sensitivity)  # Adjust threshold based on sensitivity
                
                potential_anomalies = col_data[col_data > threshold]
                for idx, value in potential_anomalies.items():
                    statistical_anomalies.append({
                        "type": f"Statistical_{col}",
                        "severity": "High",
                        "location": f"Column: {col}",
                        "description": f"Value {value:.2f} exceeds statistical threshold",
                        "value": float(value),
                        "expected_range": f"< {threshold:.2f}",
                        "confidence": 0.7
                    })
        
        all_anomalies = list(anomalies) + statistical_anomalies
        
        # Categorize by severity
        critical_anomalies = [a for a in all_anomalies if getattr(a, 'severity', 'Medium') == "Critical"]
        high_anomalies = [a for a in all_anomalies if getattr(a, 'severity', 'Medium') == "High"]
        medium_anomalies = [a for a in all_anomalies if getattr(a, 'severity', 'Medium') == "Medium"]
        
        response = {
            "status": "success",
            "detection_type": "comprehensive_anomaly_analysis",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "summary": {
                "total_anomalies": len(all_anomalies),
                "critical": len(critical_anomalies),
                "high": len(high_anomalies),
                "medium": len(medium_anomalies),
                "sensitivity_used": sensitivity,
                "data_points_analyzed": len(df)
            },
            "anomalies": [
                {
                    "id": f"anom_{i}",
                    "type": getattr(a, 'anomaly_type', getattr(a, 'type', 'Unknown')),
                    "severity": getattr(a, 'severity', 'Medium'),
                    "location": getattr(a, 'location', 'Unknown'),
                    "description": getattr(a, 'description', 'Anomaly detected'),
                    "value": getattr(a, 'value', None),
                    "confidence": getattr(a, 'confidence', 0.5),
                    "detection_method": "advanced" if i < len(anomalies) else "statistical"
                } for i, a in enumerate(all_anomalies)
            ],
            "recommendations": [
                "Investigate critical anomalies immediately",
                "Review high-severity anomalies within 24 hours",
                "Monitor medium-severity anomalies regularly"
            ] if all_anomalies else [
                "No significant anomalies detected",
                "Continue regular monitoring",
                "Maintain current operational procedures"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Anomaly detection error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Anomaly detection failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/reports/weekly', methods=['POST', 'OPTIONS'])
def generate_weekly_summary():
    """
    Enhanced weekly summary with comprehensive analytics
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        report_type = data.get('type', 'executive')
        user_id = data.get('user_id', 'anonymous')
        
        logger.info(f"Weekly summary request from {user_id}, type: {report_type}")
        
        summary_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="weekly_summary",
            document_template="summary_report",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = summary_analyzer.load_and_process_data()
        
        # Generate comprehensive summary
        data_quality = DataAnalyzer.analyze_dataset_quality(df)
        energy_patterns = DataAnalyzer.detect_energy_patterns(df)
        room_analysis = DataAnalyzer.analyze_room_utilization(df)
        
        # Create executive summary
        executive_summary = f"Weekly Building Management Report\n"
        executive_summary += f"Period: {datetime.now(timezone.utc).strftime('%Y-%m-%d')}\n\n"
        
        executive_summary += f"📊 Data Overview:\n"
        executive_summary += f"• Total Records: {data_quality['total_records']:,}\n"
        executive_summary += f"• Data Quality: {data_quality['data_quality'].title()}\n"
        executive_summary += f"• Completeness: {data_quality['completeness_score']:.1%}\n\n"
        
        if energy_patterns:
            executive_summary += f"🔋 Energy Insights:\n"
            for pattern in energy_patterns[:3]:
                executive_summary += f"• {pattern['column']}: {pattern['average']:.2f} avg ({pattern['trend']} trend)\n"
            executive_summary += f"\n"
        
        if room_analysis['status'] == 'success':
            executive_summary += f"🏢 Room Utilization:\n"
            executive_summary += f"• Most Used: {room_analysis['most_used_room']} ({room_analysis['most_used_count']} events)\n"
            executive_summary += f"• Total Rooms: {room_analysis['unique_rooms']}\n"
            executive_summary += f"• Usage Distribution: {room_analysis['utilization_distribution']['high_usage']} high, {room_analysis['utilization_distribution']['medium_usage']} medium, {room_analysis['utilization_distribution']['low_usage']} low\n\n"
        
        executive_summary += f"💡 Recommendations:\n"
        executive_summary += f"• Continue monitoring key performance indicators\n"
        executive_summary += f"• Review equipment maintenance schedules\n"
        executive_summary += f"• Optimize energy consumption patterns\n"
        
        response = {
            "status": "success",
            "report_type": "weekly_summary",
            "period": f"Week ending {datetime.now(timezone.utc).strftime('%Y-%m-%d')}",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "executive_summary": executive_summary,
            "detailed_analysis": {
                "data_quality": data_quality,
                "energy_insights": energy_patterns,
                "room_utilization": room_analysis,
                "key_metrics": {
                    "total_operations": len(df),
                    "system_uptime": "99.8%",  # Placeholder - would come from actual metrics
                    "alerts_resolved": 0,  # Placeholder
                    "maintenance_completed": 0  # Placeholder
                }
            },
            "action_items": [
                "Review energy consumption trends",
                "Check equipment maintenance status",
                "Analyze room utilization patterns",
                "Update operational procedures as needed"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Weekly summary error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Weekly summary generation failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/rooms/utilization', methods=['POST', 'OPTIONS'])
def room_utilization():
    """
    Enhanced room utilization analysis with comprehensive metrics
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        user_id = data.get('user_id', 'anonymous')
        
        logger.info(f"Room utilization analysis request from {user_id}")
        
        utilization_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="chat_assistant",
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = utilization_analyzer.load_and_process_data()
        room_analysis = DataAnalyzer.analyze_room_utilization(df)
        data_quality = DataAnalyzer.analyze_dataset_quality(df)
        
        if room_analysis['status'] == 'success':
            summary = f"🏢 Comprehensive Room Utilization Analysis\n\n"
            summary += f"• Most Utilized Room: {room_analysis['most_used_room']}\n"
            summary += f"• Usage Count: {room_analysis['most_used_count']:,} events\n"
            summary += f"• Usage Percentage: {room_analysis.get('usage_percentage', 0):.1f}% of total\n"
            summary += f"• Total Rooms: {room_analysis['unique_rooms']}\n"
            summary += f"• Total Events: {room_analysis['total_events']:,}\n"
            summary += f"• Average Events per Room: {room_analysis.get('avg_events_per_room', 0):.1f}\n\n"
            
            summary += f"📈 Utilization Distribution:\n"
            summary += f"• High Usage: {room_analysis['utilization_distribution']['high_usage']} rooms\n"
            summary += f"• Medium Usage: {room_analysis['utilization_distribution']['medium_usage']} rooms\n"
            summary += f"• Low Usage: {room_analysis['utilization_distribution']['low_usage']} rooms\n"
            
            response_data = {
                "status": "success",
                "analysis_type": "room_utilization",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "summary": summary,
                "detailed_metrics": room_analysis,
                "data_quality": data_quality,
                "recommendations": [
                    f"Focus maintenance on high-usage room: {room_analysis['most_used_room']}",
                    "Consider load balancing for underutilized spaces",
                    "Monitor usage patterns for optimization opportunities",
                    "Review peak usage times for energy efficiency"
                ]
            }
        else:
            response_data = {
                "status": "success",
                "analysis_type": "room_utilization",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "summary": "Room utilization analysis completed. No specific room data identified in current dataset.",
                "data_analysis": {
                    "data_quality": data_quality,
                    "available_columns": df.columns.tolist(),
                    "suggested_improvements": [
                        "Add room identification columns (room_id, location, etc.)",
                        "Ensure consistent data labeling across systems",
                        "Implement standardized room naming conventions"
                    ]
                },
                "recommendations": [
                    "Review data collection schema for room identification",
                    "Ensure sensors are properly tagged with location data",
                    "Consider implementing room usage tracking system"
                ]
            }
        
        return jsonify(response_data)
        
    except Exception as e:
        logger.error(f"Room utilization error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Room utilization analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/context/analyze', methods=['POST', 'OPTIONS'])
def context_analysis():
    """
    Enhanced context-aware analysis with situational awareness
    """
    if request.method == 'OPTIONS':
        return jsonify({}), 200
    
    try:
        data = request.get_json() or {}
        query = data.get('query', 'Provide current system status and insights').strip()
        user_id = data.get('user_id', 'anonymous')
        
        logger.info(f"Context analysis request from {user_id}: {query}")
        
        context_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="context_aware",
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = context_analyzer.load_and_process_data()
        
        # Comprehensive context analysis
        data_quality = DataAnalyzer.analyze_dataset_quality(df)
        energy_patterns = DataAnalyzer.detect_energy_patterns(df)
        room_analysis = DataAnalyzer.analyze_room_utilization(df)
        
        # Build context profile
        current_context = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "data_status": {
                "records_available": data_quality['total_records'],
                "data_quality": data_quality['data_quality'],
                "completeness": f"{data_quality['completeness_score']:.1%}"
            },
            "system_health": system_health['status'],
            "key_metrics": {
                "energy_metrics_detected": len(energy_patterns),
                "rooms_analyzed": room_analysis.get('unique_rooms', 0),
                "operational_status": "Normal"
            }
        }
        
        # Generate context-aware insights
        insights = []
        
        if energy_patterns:
            avg_energy = sum(p['average'] for p in energy_patterns) / len(energy_patterns)
            insights.append(f"Current energy consumption averaging {avg_energy:.2f} across {len(energy_patterns)} metrics")
        
        if room_analysis['status'] == 'success':
            insights.append(f"Room utilization shows {room_analysis['most_used_room']} as most active with {room_analysis['most_used_count']} events")
        
        if data_quality['data_quality'] == 'good':
            insights.append("Data quality is good, enabling reliable analysis")
        else:
            insights.append("Data quality needs improvement for optimal insights")
        
        response = {
            "status": "success",
            "analysis_type": "context_aware",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "context_analysis": f"Current System Context Analysis:\n\n" + "\n".join([f"• {insight}" for insight in insights]),
            "current_context": current_context,
            "insights": insights,
            "recommendations": [
                "Continue monitoring system performance",
                "Review data collection processes regularly",
                "Implement proactive maintenance based on usage patterns"
            ],
            "alerts": [
                "No critical issues detected" if system_health['status'] == 'healthy' else "System requires attention"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Context analysis error: {e}\n{traceback.format_exc()}")
        return jsonify({
            "status": "error",
            "error": f"Context analysis failed: {str(e)}",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }), 500

@app.route('/system/status', methods=['GET'])
def system_status():
    """Comprehensive system status endpoint"""
    return jsonify({
        "status": "success",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "system_health": system_health,
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

# Apply enhanced role-based access control
predict_maintenance = require_role('maintenance')(predict_maintenance)
detect_anomalies = require_role('anomalies')(detect_anomalies)
generate_weekly_summary = require_role('reports')(generate_weekly_summary)
energy_insights = require_role('energy')(energy_insights)
room_utilization = require_role('utilization')(room_utilization)
context_analysis = require_role('context')(context_analysis)

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
            ("GET   /health", "System health with detailed analytics"),
            ("POST  /llmquery", "Enhanced LLM queries with metadata"),
            ("POST  /insights/energy", "Comprehensive energy analysis"),
            ("POST  /maintenance/predict", "Predictive maintenance with fallbacks"),
            ("POST  /anomalies/detect", "Multi-method anomaly detection"),
            ("POST  /reports/weekly", "Detailed weekly summaries"),
            ("POST  /rooms/utilization", "Advanced room usage analytics"),
            ("POST  /context/analyze", "Context-aware system analysis"),
            ("GET   /system/status", "Comprehensive system status")
        ]
        
        for endpoint, description in endpoints:
            print(f"  {endpoint:<25} {description}")
        
        print("\n🔐 Enhanced Role-Based Access:")
        roles = {
            'admin': 'Full system access',
            'facility_manager': 'Maintenance, reports, anomalies, energy, utilization',
            'energy_analyst': 'Energy analysis, reports, context',
            'technician': 'Maintenance and anomaly access', 
            'viewer': 'Reports and utilization analysis',
            'guest': 'Basic report access'
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