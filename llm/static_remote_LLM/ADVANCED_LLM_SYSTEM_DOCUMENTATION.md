# 🏢 Advanced LLM System for Smart Building Management

## 📋 Table of Contents
- [Overview](#overview)
- [System Architecture](#system-architecture)
- [Room-Specific Capabilities](#room-specific-capabilities)
- [Advanced Features](#advanced-features)
- [API Endpoints](#api-endpoints)
- [Query Examples](#query-examples)
- [Installation & Setup](#installation--setup)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

This advanced LLM system provides **intelligent building management** with comprehensive room-specific analysis, predictive maintenance, anomaly detection, and energy optimization. The system has been completely **removed from JSON dependency** and now operates entirely from your PostgreSQL database.

### ✅ **Key Capabilities**
- **🏠 Room-Specific Analysis**: "What are the predictions for Room 1?"
- **🔧 Predictive Maintenance**: AI-powered equipment failure prediction
- **🚨 Anomaly Detection**: Real-time unusual pattern identification
- **⚡ Energy Optimization**: Consumption analysis and cost savings
- **📊 Weekly Summaries**: Automated executive reports
- **🧠 Context-Aware Responses**: Situational intelligence

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Advanced LLM System                     │
├─────────────────────────────────────────────────────────────┤
│  🏠 Room-Specific Handlers                                 │
│  ├── Room Data Extraction                                  │
│  ├── Room-Specific Predictions                             │
│  ├── Room Anomaly Detection                                │
│  └── Room Energy Analysis                                  │
├─────────────────────────────────────────────────────────────┤
│  🔧 Advanced LLM Handlers                                  │
│  ├── Predictive Maintenance                                │
│  ├── Anomaly Detection Engine                              │
│  ├── Energy Insights Generator                             │
│  └── Context-Aware Analysis                                │
├─────────────────────────────────────────────────────────────┤
│  🎛️ Configurable Prompts System                            │
│  ├── 7 Specialized Prompt Types                            │
│  ├── 5 Document Templates                                  │
│  └── Role-Based Access Control                             │
├─────────────────────────────────────────────────────────────┤
│  💾 Database Integration                                    │
│  ├── PostgreSQL (Primary Data)                             │
│  ├── MongoDB Atlas (Logging)                               │
│  └── Vector Store (ChromaDB)                               │
└─────────────────────────────────────────────────────��───────┘
```

---

## 🏠 Room-Specific Capabilities

### **Room Query Patterns**
The system automatically detects and handles room-specific queries:

```python
# Supported patterns:
"What are the predictions for Room 1?"
"Room A energy consumption"
"Maintenance needed in Room 2"
"Anomalies in Conference Room"
"Current status of Room B"
"Energy trends for Room 3"
```

### **Room Analysis Types**

#### 🔮 **Predictive Analysis**
```json
{
  "room": "Room 1",
  "analysis_type": "predictive_analysis",
  "predictions": {
    "energy_forecast": {
      "current_average_kwh": 15.2,
      "trend_direction": "increasing",
      "predicted_next_week": 16.8,
      "confidence": 0.85
    },
    "equipment_health": {
      "power_stability": "stable",
      "efficiency_trend": "declining",
      "maintenance_priority": "medium"
    },
    "environmental_trends": {
      "average_temperature": 22.5,
      "temperature_stability": "stable",
      "hvac_efficiency": "good"
    },
    "occupancy_patterns": {
      "utilization_rate": 65.2,
      "peak_occupancy": 8,
      "usage_classification": "high"
    }
  },
  "maintenance_alerts": [...],
  "anomalies": [...],
  "recommendations": [
    "Monitor equipment efficiency trends",
    "Schedule preventive maintenance within 2 weeks"
  ]
}
```

#### 🚨 **Anomaly Detection**
```json
{
  "room": "Room 1",
  "analysis_type": "anomaly_detection",
  "anomalies": [
    {
      "type": "power_consumption",
      "severity": "High",
      "description": "Power consumption 40% above normal",
      "confidence": 0.92,
      "requires_immediate_attention": true
    }
  ]
}
```

#### ⚡ **Energy Analysis**
```json
{
  "room": "Room 1",
  "analysis_type": "energy_analysis",
  "insights": [
    {
      "metric": "daily_consumption",
      "current_value": 24.5,
      "trend": "increasing",
      "opportunity": "15% reduction possible",
      "recommendation": "Optimize HVAC scheduling"
    }
  ]
}
```

#### 📊 **Current Status**
```json
{
  "room": "Room 1",
  "analysis_type": "current_status",
  "current_status": {
    "occupancy": "occupied",
    "occupant_count": 3,
    "temperature": 23.2,
    "humidity": 45.0,
    "energy_consumption": 18.5,
    "total_power": 1250.0
  }
}
```

---

## 🚀 Advanced Features

### **1. Predictive Maintenance (AI)**
- **Equipment Failure Prediction**: ML-based analysis of equipment degradation
- **Maintenance Scheduling**: Automated priority-based scheduling
- **Cost Estimation**: Predictive maintenance cost analysis
- **Risk Assessment**: Equipment failure risk scoring

### **2. Anomaly Detection Engine**
- **Multi-Dimensional Analysis**: Power, temperature, humidity, runtime
- **Severity Classification**: Critical, High, Medium, Low
- **Confidence Scoring**: AI confidence in anomaly detection
- **Real-Time Alerts**: Immediate notification system

### **3. Energy Optimization**
- **Consumption Forecasting**: Predictive energy usage modeling
- **Cost Analysis**: Energy cost breakdown and optimization
- **Efficiency Benchmarking**: Performance comparison analysis
- **Savings Opportunities**: Automated cost-saving recommendations

### **4. Context-Aware Intelligence**
- **Seasonal Adjustments**: Weather and season-based analysis
- **Occupancy Patterns**: Usage pattern recognition
- **Time-Based Analysis**: Peak/off-peak optimization
- **Environmental Factors**: Temperature, humidity impact analysis

---

## 🌐 API Endpoints

### **Core Endpoints**

#### **General LLM Queries**
```http
POST /llmquery
Content-Type: application/json

{
  "query": "Most used room?",
  "type": "room_utilization"
}
```

#### **Room-Specific Analysis**
```http
POST /rooms/{room_name}/analyze
Content-Type: application/json

{
  "analysis_type": "predictive",
  "query": "What are the predictions for Room 1?"
}
```

#### **Predictive Maintenance**
```http
POST /maintenance/predict
Content-Type: application/json
X-User-Role: facility_manager

{
  "query": "Analyze logs for maintenance suggestions"
}
```

#### **Anomaly Detection**
```http
POST /anomalies/detect
Content-Type: application/json
X-User-Role: technician

{
  "sensitivity": 0.8
}
```

#### **Weekly Reports**
```http
POST /reports/weekly
Content-Type: application/json
X-User-Role: facility_manager

{
  "type": "executive"
}
```

### **Response Format**
```json
{
  "status": "success",
  "query": "What are the predictions for Room 1?",
  "answer": "Room 1 analysis shows...",
  "timestamp": "2024-01-15T10:30:00Z",
  "room": "Room 1",
  "analysis_type": "predictive_analysis",
  "predictions": {...},
  "maintenance_alerts": [...],
  "anomalies": [...],
  "recommendations": [...]
}
```

---

## 💬 Query Examples

### **Room-Specific Queries**

```python
# Basic room queries
"What are the predictions for Room 1?"
"Room A current status"
"Energy consumption in Room 2"
"Maintenance needed for Conference Room"

# Advanced room analysis
"Predict equipment failures in Room 1"
"Anomalies detected in Room B"
"Energy optimization for Room 3"
"Weekly summary for Room A"

# Comparative analysis
"Compare Room 1 and Room 2 energy usage"
"Which room needs maintenance first?"
"Most efficient room this week"
```

### **General Building Queries**

```python
# Utilization analysis
"Most used room?"
"Room utilization patterns"
"Peak occupancy times"

# Energy insights
"Energy trends?"
"Consumption patterns"
"Cost optimization opportunities"

# Maintenance predictions
"What maintenance is needed?"
"Equipment health status"
"Predictive maintenance alerts"

# Anomaly detection
"Detect anomalies"
"Unusual patterns"
"System alerts"

# Executive summaries
"Weekly summary"
"Generate executive report"
"Key performance indicators"
```

---

## 🛠️ Installation & Setup

### **1. Prerequisites**
```bash
# Python dependencies
pip install pandas numpy scikit-learn
pip install langchain langchain-ollama langchain-community
pip install chromadb pymongo psycopg2-binary
pip install python-dotenv flask

# Ollama setup
ollama pull incept5/llama3.1-claude:latest
ollama pull nomic-embed-text
```

### **2. Database Configuration**
```python
# PostgreSQL connection (database_adapter.py)
psycopg2.connect(
    host='localhost',
    database='sbmsdb',
    user='postgres',
    password='9609',
    port='5432'
)
```

### **3. Environment Variables**
```bash
# .env file
MONGO_ATLAS_URI=mongodb+srv://your-connection-string
MONGO_DB_NAME=LLM_logs
MONGO_COLLECTION_NAME=logs
PROMPT_LOGS_DB_NAME=prompt_logs
PROMPT_LOGS_COLLECTION_NAME=queries
```

### **4. System Initialization**
```python
from main import initialize_analyzer, ask

# Initialize the system
if initialize_analyzer():
    print("✅ System ready!")
    
    # Test room-specific query
    result = ask("What are the predictions for Room 1?")
    print(result)
```

---

## ⚙️ Configuration

### **Prompt Types**
```python
prompt_types = {
    "predictive_maintenance": "AI maintenance analyst",
    "anomaly_detection": "Anomaly detection specialist",
    "energy_insights": "Energy efficiency consultant",
    "maintenance_scheduler": "Maintenance scheduling AI",
    "weekly_summary": "Automated report generator",
    "chat_assistant": "Helpful building assistant",
    "context_aware": "Situational intelligence"
}
```

### **Document Templates**
```python
templates = {
    "maintenance_analysis": "Equipment-focused format",
    "anomaly_detection": "Anomaly scanning format",
    "energy_report": "Energy efficiency format",
    "summary_report": "Executive summary format",
    "standard": "General purpose format"
}
```

### **Role-Based Access**
```python
roles = {
    "admin": ["all"],
    "facility_manager": ["maintenance", "reports", "anomalies"],
    "energy_analyst": ["energy", "reports"],
    "technician": ["maintenance", "anomalies"],
    "viewer": ["reports"]
}
```

---

## 📝 Usage Examples

### **Python Integration**
```python
from main import ask

# Room-specific analysis
result = ask("What are the predictions for Room 1?")
print(f"Room Analysis: {result['answer']}")

if 'predictions' in result:
    energy_forecast = result['predictions']['energy_forecast']
    print(f"Energy Trend: {energy_forecast['trend_direction']}")
    print(f"Next Week Prediction: {energy_forecast['predicted_next_week']} kWh")

if 'maintenance_alerts' in result:
    for alert in result['maintenance_alerts']:
        print(f"⚠️ {alert['equipment']}: {alert['issue']} (Urgency: {alert['urgency']})")

# General building queries
trends = ask("Energy trends?")
maintenance = ask("What maintenance is needed?")
anomalies = ask("Detect anomalies")
summary = ask("Generate weekly summary")
```

### **Flask API Integration**
```python
from flask import Flask, request, jsonify
from main import ask

app = Flask(__name__)

@app.route('/room/<room_name>/predict', methods=['POST'])
def room_predictions(room_name):
    query = f"What are the predictions for {room_name}?"
    result = ask(query)
    return jsonify(result)

@app.route('/building/status', methods=['GET'])
def building_status():
    queries = [
        "Most used room?",
        "Energy trends?",
        "What maintenance is needed?",
        "Detect anomalies"
    ]
    
    status = {}
    for query in queries:
        result = ask(query)
        status[query] = result['answer']
    
    return jsonify(status)
```

### **Automated Monitoring**
```python
import schedule
import time
from main import ask

def daily_maintenance_check():
    """Daily automated maintenance analysis"""
    result = ask("What maintenance is needed?")
    
    if 'maintenance_alerts' in result:
        critical_alerts = [
            alert for alert in result['maintenance_alerts'] 
            if alert['urgency'] in ['critical', 'high']
        ]
        
        if critical_alerts:
            # Send notifications
            send_maintenance_alerts(critical_alerts)

def weekly_summary_report():
    """Weekly automated summary generation"""
    summary = ask("Generate weekly summary")
    
    # Generate PDF report
    generate_pdf_report(summary)
    
    # Email to stakeholders
    email_weekly_report(summary)

# Schedule automated tasks
schedule.every().day.at("08:00").do(daily_maintenance_check)
schedule.every().monday.at("09:00").do(weekly_summary_report)

while True:
    schedule.run_pending()
    time.sleep(3600)  # Check every hour
```

---

## 🔧 Troubleshooting

### **Common Issues**

#### **1. "QA chain not initialized" Error**
```python
# Solution: Ensure proper initialization
from main import initialize_analyzer

if not initialize_analyzer():
    print("❌ Initialization failed - check database connection")
else:
    print("✅ System initialized successfully")
```

#### **2. Room Not Found**
```python
# Check available rooms
from main import analyzer

if analyzer and analyzer.room_handlers:
    rooms = analyzer.room_handlers.get_available_rooms()
    print("Available rooms:", [room['name'] for room in rooms])
```

#### **3. Database Connection Issues**
```python
# Test database connections
import psycopg2
from pymongo import MongoClient

# Test PostgreSQL
try:
    conn = psycopg2.connect(
        host='localhost',
        database='sbmsdb',
        user='postgres',
        password='9609'
    )
    print("✅ PostgreSQL connected")
    conn.close()
except Exception as e:
    print(f"❌ PostgreSQL error: {e}")

# Test MongoDB
try:
    client = MongoClient("your-mongo-uri")
    client.admin.command('ping')
    print("✅ MongoDB connected")
except Exception as e:
    print(f"❌ MongoDB error: {e}")
```

#### **4. Ollama Model Issues**
```bash
# Ensure models are available
ollama list

# Pull required models if missing
ollama pull incept5/llama3.1-claude:latest
ollama pull nomic-embed-text

# Test model
ollama run incept5/llama3.1-claude:latest "Hello"
```

### **Performance Optimization**

#### **1. Vector Store Optimization**
```python
# Reset vector store if needed
from main import initialize_analyzer

initialize_analyzer(reset_vector_store=True)
```

#### **2. Database Query Optimization**
```python
# Limit data for testing
from main import RoomLogAnalyzer

analyzer = RoomLogAnalyzer()
df = analyzer.load_and_process_data(limit=100)  # Limit to 100 records
```

#### **3. Memory Management**
```python
# Clear cache periodically
import gc

def clear_system_cache():
    if analyzer:
        analyzer.df = None  # Clear cached dataframe
    gc.collect()
```

---

## 📊 System Monitoring

### **Health Check Endpoint**
```python
@app.route('/health', methods=['GET'])
def health_check():
    try:
        # Test basic query
        result = ask("How many records?")
        
        if "error" not in result:
            return jsonify({
                "status": "healthy",
                "message": "Advanced LLM system operational",
                "capabilities": [
                    "room_specific_analysis",
                    "predictive_maintenance",
                    "anomaly_detection",
                    "energy_optimization"
                ]
            })
        else:
            return jsonify({
                "status": "unhealthy",
                "error": result["error"]
            }), 503
            
    except Exception as e:
        return jsonify({
            "status": "unhealthy",
            "error": str(e)
        }), 503
```

### **Performance Metrics**
```python
def get_system_metrics():
    """Get system performance metrics"""
    metrics = {
        "total_queries_processed": get_query_count(),
        "average_response_time": get_avg_response_time(),
        "rooms_analyzed": len(get_available_rooms()),
        "anomalies_detected_today": get_daily_anomaly_count(),
        "maintenance_alerts_active": get_active_maintenance_count(),
        "system_uptime": get_system_uptime()
    }
    return metrics
```

---

## 🎯 Best Practices

### **1. Query Optimization**
- Use specific room names: "Room 1" instead of "room one"
- Be explicit about analysis type: "predict maintenance for Room A"
- Combine related queries: "Room 1 energy and maintenance status"

### **2. Error Handling**
```python
def safe_query(query):
    """Safe query execution with error handling"""
    try:
        result = ask(query)
        
        if "error" in result:
            logger.error(f"Query error: {result['error']}")
            return {"status": "error", "message": "Query failed"}
        
        return {"status": "success", "data": result}
        
    except Exception as e:
        logger.error(f"System error: {e}")
        return {"status": "error", "message": "System unavailable"}
```

### **3. Data Validation**
```python
def validate_room_query(room_name):
    """Validate room exists before querying"""
    available_rooms = get_available_rooms()
    room_names = [room['name'].lower() for room in available_rooms]
    
    if room_name.lower() not in room_names:
        return False, f"Room '{room_name}' not found. Available: {', '.join([r['name'] for r in available_rooms])}"
    
    return True, None
```

---

## 🚀 Future Enhancements

### **Planned Features**
- **Multi-Building Support**: Cross-building analysis and comparison
- **IoT Integration**: Real-time sensor data integration
- **Mobile App**: Native mobile application for facility managers
- **Advanced Visualizations**: Interactive dashboards and charts
- **Machine Learning Models**: Custom ML models for specific building types

### **API Expansions**
- **GraphQL Support**: Flexible query language for complex requests
- **WebSocket Integration**: Real-time updates and notifications
- **Batch Processing**: Bulk analysis and reporting capabilities
- **Export Formats**: PDF, Excel, CSV report generation

---

## 📞 Support & Contact

For technical support, feature requests, or bug reports:

- **Documentation**: This comprehensive guide
- **Code Examples**: See `test_advanced_features.py`
- **API Examples**: See `api_integration_example.py`
- **Configuration**: See `prompts_config.py` and `advanced_prompts.json`

---

## 🎉 Conclusion

Your Advanced LLM System is now **fully operational** with comprehensive room-specific capabilities, predictive maintenance, anomaly detection, and energy optimization. The system has been completely **removed from JSON dependency** and operates entirely from your PostgreSQL database.

### **Key Achievements**
✅ **Room-Specific Analysis**: "What are the predictions for Room 1?" - **WORKING**  
✅ **Database-Only Operation**: No JSON files required - **IMPLEMENTED**  
✅ **Predictive Maintenance**: AI-powered equipment analysis - **ACTIVE**  
✅ **Anomaly Detection**: Real-time pattern recognition - **MONITORING**  
✅ **Energy Optimization**: Cost-saving recommendations - **OPTIMIZING**  
✅ **API-Ready**: Production-ready endpoints - **DEPLOYED**  

**Your intelligent building management system is ready for production! 🏢🤖**