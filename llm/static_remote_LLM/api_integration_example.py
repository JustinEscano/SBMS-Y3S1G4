#!/usr/bin/env python3
"""
API Integration Example for Advanced LLM Features
Shows how to integrate all the advanced capabilities into your web application
"""

from flask import Flask, request, jsonify
from flask_cors import CORS  # Add this import
from datetime import datetime
import logging
import os
import sys

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import RoomLogAnalyzer, ask
from prompts_config import PromptsConfig
from advanced_llm_handlers import AdvancedLLMHandlers

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Enable CORS for all routes, allowing all origins for development
CORS(app, resources={r"/*": {"origins": "*"}})  # For development

# For production, use specific origins (uncomment and adjust):
# CORS(app, resources={r"/*": {"origins": ["http://localhost:3000", "http://192.168.1.38:3000"]}})

# Global analyzer instance
analyzer = None

def initialize_system():
    """Initialize the LLM system with advanced capabilities"""
    global analyzer
    try:
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="chat_assistant",  # Default for general queries
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        # Initialize the system
        df = analyzer.load_and_process_data()
        documents = analyzer.create_documents(df)
        analyzer.initialize_vector_store(documents)
        analyzer.initialize_qa_chain()
        
        logger.info("✅ Advanced LLM system initialized successfully")
        return True
    except Exception as e:
        logger.error(f"❌ Failed to initialize system: {e}")
        return False

@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    if analyzer is None:
        return jsonify({
            "status": "unhealthy",
            "message": "LLM system not initialized",
            "timestamp": datetime.utcnow().isoformat()
        }), 503
    
    return jsonify({
        "status": "healthy", 
        "message": "Advanced LLM system operational",
        "capabilities": [
            "predictive_maintenance",
            "anomaly_detection", 
            "energy_insights",
            "room_utilization",
            "weekly_summaries",
            "context_aware_analysis"
        ],
        "timestamp": datetime.utcnow().isoformat()
    })

@app.route('/llmquery', methods=['POST'])
def llm_query():
    """
    Main LLM query endpoint
    Handles: "Most used room?", "Energy trends?", general questions
    """
    try:
        data = request.get_json()
        query = data.get('query', '')
        query_type = data.get('type', 'general')
        
        if not query:
            return jsonify({
                "error": "Query is required",
                "timestamp": datetime.utcnow().isoformat()
            }), 400
        
        # Process the query
        result = ask(query)
        
        # Structure the response
        response = {
            "status": "success",
            "query": query,
            "query_type": query_type,
            "answer": result.get('answer', ''),
            "timestamp": datetime.utcnow().isoformat(),
            "metadata": {
                "sources_count": len(result.get('sources', [])),
                "processing_method": "deterministic" if 'sources' in result else "llm_generated"
            }
        }
        
        # Add additional data if available
        if 'metrics' in result:
            response['metrics'] = result['metrics']
        
        if 'anomalies' in result:
            response['anomalies'] = result['anomalies']
            
        if 'maintenance_alerts' in result:
            response['maintenance_alerts'] = result['maintenance_alerts']
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/maintenance/predict', methods=['POST'])
def predict_maintenance():
    """
    Predictive maintenance endpoint
    Analyzes logs for maintenance suggestions and predictions
    """
    try:
        data = request.get_json()
        query = data.get('query', 'Analyze logs for maintenance suggestions')
        
        # Use maintenance-specific prompt
        maintenance_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="predictive_maintenance",
            document_template="maintenance_analysis",
            prompts_config_file="advanced_prompts.json"
        )
        
        # Get data and analyze
        df = maintenance_analyzer.load_and_process_data()
        
        # Detect anomalies and generate maintenance suggestions
        anomalies = maintenance_analyzer.advanced_handlers.detect_anomalies(df)
        maintenance_alerts = maintenance_analyzer.advanced_handlers.generate_maintenance_suggestions(df, anomalies)
        
        # Structure maintenance response
        response = {
            "status": "success",
            "analysis_type": "predictive_maintenance",
            "timestamp": datetime.utcnow().isoformat(),
            "summary": {
                "anomalies_detected": len(anomalies),
                "maintenance_alerts": len(maintenance_alerts),
                "data_points_analyzed": len(df)
            },
            "anomalies": [
                {
                    "type": a.anomaly_type,
                    "severity": a.severity,
                    "description": a.description,
                    "timestamp": a.timestamp,
                    "confidence": a.confidence
                } for a in anomalies
            ],
            "maintenance_suggestions": [
                {
                    "equipment": m.equipment,
                    "issue": m.issue,
                    "urgency": m.urgency,
                    "timeline": m.timeline,
                    "action": m.action,
                    "cost_estimate": m.cost_estimate,
                    "risk_level": m.risk_level,
                    "confidence": m.confidence
                } for m in maintenance_alerts
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in predictive maintenance: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/anomalies/detect', methods=['POST'])
def detect_anomalies():
    """
    Anomaly detection endpoint
    Triggers suggestions from anomalies
    """
    try:
        data = request.get_json()
        sensitivity = data.get('sensitivity', 0.8)
        
        # Use anomaly detection specific setup
        anomaly_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="anomaly_detection",
            document_template="anomaly_detection",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = anomaly_analyzer.load_and_process_data()
        anomalies = anomaly_analyzer.advanced_handlers.detect_anomalies(df)
        
        # Categorize anomalies by severity
        critical_anomalies = [a for a in anomalies if a.severity == "Critical"]
        high_anomalies = [a for a in anomalies if a.severity == "High"] 
        medium_anomalies = [a for a in anomalies if a.severity == "Medium"]
        
        response = {
            "status": "success",
            "detection_type": "anomaly_analysis",
            "timestamp": datetime.utcnow().isoformat(),
            "summary": {
                "total_anomalies": len(anomalies),
                "critical": len(critical_anomalies),
                "high": len(high_anomalies),
                "medium": len(medium_anomalies),
                "sensitivity": sensitivity
            },
            "anomalies": [
                {
                    "id": f"anomaly_{i}",
                    "type": a.anomaly_type,
                    "severity": a.severity,
                    "location": a.location,
                    "description": a.description,
                    "timestamp": a.timestamp,
                    "value": a.value,
                    "expected_range": a.expected_range,
                    "confidence": a.confidence,
                    "requires_immediate_attention": a.severity in ["Critical", "High"]
                } for i, a in enumerate(anomalies)
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in anomaly detection: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/reports/weekly', methods=['POST'])
def generate_weekly_summary():
    """
    Weekly summary generation endpoint
    Auto-generates weekly summaries
    """
    try:
        data = request.get_json()
        report_type = data.get('type', 'executive')
        
        # Use summary-specific configuration
        summary_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="weekly_summary",
            document_template="summary_report", 
            prompts_config_file="advanced_prompts.json"
        )
        
        df = summary_analyzer.load_and_process_data()
        summary_result = summary_analyzer.advanced_handlers.generate_weekly_summary(df)
        
        # Enhanced summary with additional insights
        energy_insights = summary_analyzer.advanced_handlers.generate_energy_insights(df)
        
        response = {
            "status": "success",
            "report_type": "weekly_summary",
            "period": f"Week ending {datetime.now().strftime('%Y-%m-%d')}",
            "timestamp": datetime.utcnow().isoformat(),
            "executive_summary": summary_result.get('answer', ''),
            "key_metrics": summary_result.get('summary', {}),
            "anomalies": summary_result.get('anomalies', []),
            "maintenance_items": summary_result.get('maintenance_alerts', []),
            "energy_insights": [
                {
                    "metric": i.metric,
                    "current_value": i.current_value,
                    "trend": i.trend,
                    "opportunity": i.opportunity,
                    "recommendation": i.recommendation,
                    "potential_savings": i.potential_savings
                } for i in energy_insights
            ],
            "recommendations": [
                "Monitor critical anomalies immediately",
                "Schedule identified maintenance tasks",
                "Implement energy optimization suggestions",
                "Review occupancy patterns for efficiency"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error generating weekly summary: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/insights/energy', methods=['POST'])
def energy_insights():
    """
    Energy insights and trends endpoint
    Handles "Energy trends?" queries
    """
    try:
        data = request.get_json()
        analysis_type = data.get('analysis_type', 'trends')
        
        insights_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="energy_insights",
            document_template="energy_report",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = insights_analyzer.load_and_process_data()
        
        if analysis_type == 'trends':
            result = insights_analyzer.advanced_handlers.handle_energy_trends_query(df)
        else:
            # General energy insights
            energy_insights = insights_analyzer.advanced_handlers.generate_energy_insights(df)
            result = {
                "answer": f"Generated {len(energy_insights)} energy insights",
                "insights": energy_insights
            }
        
        response = {
            "status": "success",
            "analysis_type": f"energy_{analysis_type}",
            "timestamp": datetime.utcnow().isoformat(),
            "insights": result.get('answer', ''),
            "metrics": result.get('metrics', {}),
            "data_period": f"{len(df)} data points analyzed"
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in energy insights: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/rooms/utilization', methods=['POST'])
def room_utilization():
    """
    Room utilization analysis endpoint
    Handles "Most used room?" queries
    """
    try:
        utilization_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="chat_assistant",
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = utilization_analyzer.load_and_process_data()
        result = utilization_analyzer.advanced_handlers.handle_most_used_room_query(df)
        
        response = {
            "status": "success",
            "analysis_type": "room_utilization",
            "timestamp": datetime.utcnow().isoformat(),
            "summary": result.get('answer', ''),
            "utilization_metrics": result.get('metrics', {}),
            "recommendations": [
                "Optimize scheduling for peak usage periods",
                "Consider energy-saving measures during low occupancy",
                "Monitor equipment efficiency during high usage"
            ]
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in room utilization analysis: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

@app.route('/context/analyze', methods=['POST'])
def context_analysis():
    """
    Context-aware analysis endpoint
    Provides situational awareness and context-sensitive insights
    """
    try:
        data = request.get_json()
        query = data.get('query', 'Analyze current situation')
        
        context_analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="context_aware",
            document_template="standard",
            prompts_config_file="advanced_prompts.json"
        )
        
        df = context_analyzer.load_and_process_data()
        result = context_analyzer.advanced_handlers.handle_context_aware_query(query, df)
        
        response = {
            "status": "success",
            "analysis_type": "context_aware",
            "timestamp": datetime.utcnow().isoformat(),
            "context_analysis": result.get('answer', ''),
            "current_context": result.get('context', {}),
            "insights": result.get('insights', []),
            "recommendations": result.get('recommendations', [])
        }
        
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"Error in context analysis: {e}")
        return jsonify({
            "status": "error",
            "error": str(e),
            "timestamp": datetime.utcnow().isoformat()
        }), 500

# Role-based access control decorator
def require_role(required_role):
    """Decorator for role-based access control"""
    def decorator(f):
        def decorated_function(*args, **kwargs):
            # In a real application, you would validate the user's role here
            # For demo purposes, we'll check a header
            user_role = request.headers.get('X-User-Role', 'guest')
            
            role_permissions = {
                'admin': ['all'],
                'facility_manager': ['maintenance', 'reports', 'anomalies'],
                'energy_analyst': ['energy', 'reports'],
                'technician': ['maintenance', 'anomalies'],
                'viewer': ['reports']
            }
            
            if user_role not in role_permissions:
                return jsonify({"error": "Unauthorized"}), 401
            
            if required_role not in role_permissions[user_role] and 'all' not in role_permissions[user_role]:
                return jsonify({"error": "Insufficient permissions"}), 403
            
            return f(*args, **kwargs)
        decorated_function.__name__ = f.__name__
        return decorated_function
    return decorator

# Apply role-based access to sensitive endpoints
predict_maintenance = require_role('maintenance')(predict_maintenance)
detect_anomalies = require_role('anomalies')(detect_anomalies)
generate_weekly_summary = require_role('reports')(generate_weekly_summary)

if __name__ == '__main__':
    print("🚀 INITIALIZING ADVANCED LLM API SERVER")
    print("=" * 60)
    
    if initialize_system():
        print("✅ System initialized successfully")
        print("\n📡 Available Endpoints:")
        print("• GET  /health - System health check")
        print("• POST /llmquery - General LLM queries")
        print("• POST /maintenance/predict - Predictive maintenance")
        print("• POST /anomalies/detect - Anomaly detection")
        print("• POST /reports/weekly - Weekly summaries")
        print("• POST /insights/energy - Energy analysis")
        print("• POST /rooms/utilization - Room utilization")
        print("• POST /context/analyze - Context-aware analysis")
        print("\n🔐 Role-Based Access:")
        print("• admin: All endpoints")
        print("• facility_manager: maintenance, reports, anomalies")
        print("• energy_analyst: energy, reports")
        print("• technician: maintenance, anomalies")
        print("• viewer: reports only")
        print("\n🌐 Starting server on http://localhost:5000")
        
        app.run(debug=True, host='0.0.0.0', port=5000)
    else:
        print("❌ Failed to initialize system")
        print("Make sure your database is running and accessible")