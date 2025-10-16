# Smart Building Management System - LLM Features Documentation

## Overview
This document describes the LLM-powered features implemented in the Smart Building Management System. All features use AI analysis to provide intelligent insights and recommendations.

---

## 🔋 Energy Analysis

### Endpoint
`POST /energy/report`

### Description
Generates comprehensive energy consumption reports with AI-powered analysis for different time periods.

### Features
- **Time Periods**: Daily, Weekly, Monthly, Yearly
- **Statistics**: Total consumption, average, peak, lowest usage
- **Timestamps**: Shows when peak and lowest consumption occurred
- **Period Range**: Displays the full date range of the report
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **Consumption Analysis**: Patterns in energy usage
  2. **Cost Optimization**: Ways to reduce energy costs
  3. **Action Items**: Specific actions to take

### Example Request
```json
{
  "period": "weekly",
  "user_id": "web_user",
  "username": "Web User"
}
```

### Example Response
```
⚡ Weekly Energy Report
📅 Period: 10/09/2025 - 10/16/2025

📊 Energy Statistics:
• Total Consumption: 4329.50 kWh
• Average: 721.58 kWh per period
• Peak: 840.00 kWh (on 10/12/2025)
• Lowest: 630.00 kWh (on 10/10/2025)
• Data Points: 6

🤖 **AI ANALYSIS**

**1. CONSUMPTION ANALYSIS:**
[AI-generated pattern analysis]

**2. COST OPTIMIZATION:**
[AI-generated cost reduction strategies]

**3. ACTION ITEMS:**
[AI-generated specific actions]
```

### User Queries
- "daily energy report"
- "weekly energy report"
- "monthly energy report"
- "yearly energy report"

---

## 📊 KPI & System Health Monitoring

### Endpoint
`POST /kpi/heartbeat`

### Description
Analyzes IoT device health metrics from heartbeat logs and provides AI-powered system health insights.

### Features
- **Performance Metrics**: Success rate, WiFi signal, uptime, voltage stability
- **Sensor Health**: DHT22 (temp/humidity), PZEM (power meter), Photoresistor (light)
- **Error Tracking**: Failed readings, PZEM errors
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **System Health Assessment**: Overall sensor status
  2. **Critical Issues**: Problems needing immediate attention
  3. **Maintenance Recommendations**: Preventive actions

### Data Source
- Table: `core_heartbeatlog`
- Fields: `timestamp`, `dht22_working`, `pzem_working`, `success_rate`, `wifi_signal`, `uptime`, `voltage_stability`, `failed_readings`, `pzem_error_count`

### Example Response
```
📊 System Health KPI Analysis

🔍 Performance Metrics:
• Success Rate: 96.50%
• WiFi Signal: -57.5 dBm
• Average Uptime: 5.5 hours
• Voltage Stability: 0.97
• Failed Readings: 10
• PZEM Errors: 3

🔧 Sensor Health:
• DHT22 (Temp/Humidity): 90.0% operational
• PZEM (Power Meter): 85.0% operational
• Photoresistor (Light): 80.0% operational
• Data Points Analyzed: 100

🤖 **AI ANALYSIS**

**1. SYSTEM HEALTH ASSESSMENT:**
[AI-generated health status]

**2. CRITICAL ISSUES:**
[AI-generated critical problems]

**3. MAINTENANCE RECOMMENDATIONS:**
[AI-generated preventive actions]
```

### User Queries
- "show system health"
- "KPI heartbeat"
- "sensor health status"
- "device health check"
- "IoT health"

---

## 💱 Billing Rates Analysis

### Endpoint
`POST /billing/rates`

### Description
Analyzes electricity billing rates and provides AI-powered cost optimization recommendations.

### Features
- **Rate Summary**: Total configurations, average, min, max rates
- **Rate Schedule**: Time windows and validity periods
- **Currency Support**: Handles multiple currencies
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **Rate Analysis**: Patterns and peak/off-peak opportunities
  2. **Cost Optimization**: Ways to reduce electricity costs
  3. **Action Items**: Specific actions to optimize billing

### Data Source
- Table: `core_billingrate`
- Fields: `rate_per_kwh`, `currency`, `start_time`, `end_time`, `valid_from`, `valid_to`

### Example Response
```
💱 Billing Rates Analysis

📊 Rate Summary:
• Total Configurations: 5
• Average Rate: 0.1740 USD/kWh
• Lowest Rate: 0.1200 USD/kWh
• Highest Rate: 0.2200 USD/kWh

⏰ Rate Schedule:
1. 0.1500 USD/kWh
   Time: 09:00:00 - 18:00:00
   Valid: 10/1/2025 → 12/31/2025

🤖 **AI ANALYSIS**

**1. RATE ANALYSIS:**
[AI-generated rate pattern analysis]

**2. COST OPTIMIZATION:**
[AI-generated cost reduction strategies]

**3. ACTION ITEMS:**
[AI-generated optimization actions]
```

### User Queries
- "show billing rates"
- "what are the rates?"
- "billing analysis"
- "show me the pricing"

---

## 🔧 Maintenance Requests

### Endpoint
`POST /maintenance/predict`

### Description
Analyzes maintenance requests and provides AI-powered prioritization and resource allocation recommendations.

### Features
- **Grouped by Status**: Pending, In Progress, Resolved
- **Clear Formatting**: Bold text for requested by and assigned to
- **Priority Indicators**: Color-coded urgency levels
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **Priority Recommendation**: Which issues to fix first
  2. **Resource Estimate**: Technician allocation
  3. **Pattern Analysis**: Equipment replacement vs repair decisions

### Improved Format
```
🔧 **MAINTENANCE REQUESTS**

🔴 **PENDING REQUESTS** (9):

1. 🟠 **Sensor Device 2** - Office Room B
   📝 Issue: testing
   🔧 Action: wwwhyyyyyy
   👤 Requested by: **test**
   👨‍🔧 Assigned to: **admin_user**
   📅 Scheduled: 2025-10-16 00:00:00

🟡 **IN PROGRESS** (1):

1. **Sensor Device 4** - Break Room D
   📝 w
   👨‍🔧 Assigned to: **maintenance_user**

✅ **RECENTLY RESOLVED** (5 total, showing last 3):

1. Sensor Device 10 - Conference Room E
   ✓ Recalibrated

🤖 **AI RECOMMENDATIONS**

**1. PRIORITY RECOMMENDATION:**
[AI-generated priority analysis]

**2. RESOURCE ESTIMATE:**
[AI-generated resource allocation]

**3. PATTERN ANALYSIS:**
[AI-generated pattern insights]
```

### User Queries
- "check for maintenance"
- "show maintenance requests"
- "maintenance analysis"

---

## ⚠️ Anomaly Detection

### Endpoint
`POST /anomalies/detect`

### Description
Detects system anomalies from alerts and provides AI-powered analysis and recommendations.

### Features
- **Alert Analysis**: Analyzes alerts from the past 7 days
- **Severity Grouping**: Critical, High, Medium levels
- **Type Categorization**: Groups by alert type
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **Critical Issues**: Anomalies needing immediate attention
  2. **Pattern Analysis**: Patterns in the alerts
  3. **Preventive Actions**: How to prevent future anomalies

### Data Source
- Table: `core_alert`
- Fields: `alert_type`, `message`, `severity_level`, `created_at`, `is_resolved`

### Example Response
```
⚠️ **ANOMALY DETECTION**

📊 Alert Summary (7 days):
• Total Alerts: 10
• Unresolved: 3
• By Severity: {'high': 3, 'medium': 5, 'low': 2}
• By Type: {'motion': 5, 'humidity_low': 3, 'temperature_high': 2}

🤖 **AI ANALYSIS**

**1. CRITICAL ISSUES:**
[AI-generated critical issue analysis]

**2. PATTERN ANALYSIS:**
[AI-generated pattern insights]

**3. PREVENTIVE ACTIONS:**
[AI-generated prevention strategies]
```

### User Queries
- "show me anomalies"
- "detect anomalies"
- "check for alerts"
- "system anomalies"

---

## 💾 MongoDB Chat History

### Description
All prompts and responses are automatically saved to MongoDB Atlas for historical tracking and analysis.

### Database Configuration
- **Connection**: MongoDB Atlas (from `.env` file)
- **Database**: `LLM_logs`
- **Collection**: `chat_history`

### Saved Data
```javascript
{
  "_id": ObjectId("..."),
  "user_id": "web_user",
  "username": "Web User",
  "session_id": "web_session_1729094567890",
  "user_message": "Show billing rates",
  "assistant_response": "💱 Billing Rates Analysis...",
  "query_type": "billing",  // billing, kpi, energy, maintenance, anomalies
  "timestamp": ISODate("2025-10-16T13:56:07.890Z"),
  "metadata": {
    "user_role": "energy_analyst",
    "response_time_ms": null,
    "has_error": false
  }
}
```

### Features
- ✅ **Automatic Saving**: All prompts saved automatically
- ✅ **Error Tracking**: Errors saved with `has_error: true`
- ✅ **Session Tracking**: Unique session IDs
- ✅ **Query Type Tracking**: Categorized by feature type
- ✅ **User Role Tracking**: Tracks user permissions
- ✅ **Timestamps**: UTC timestamps for all chats
- ✅ **Graceful Degradation**: App works even if MongoDB is down

---

## 🎯 Key Features

### All Endpoints Use LLM
Every endpoint uses AI (Ollama with `incept5/llama3.1-claude:latest` model) to provide intelligent analysis and recommendations.

### Consistent Format
All AI responses follow a 3-part recommendation structure:
1. Analysis/Assessment
2. Optimization/Issues
3. Actions/Recommendations

### MongoDB Integration
All user prompts and AI responses are saved to MongoDB Atlas for:
- Historical analysis
- Usage tracking
- Quality improvement
- Audit trails

### Error Handling
- Graceful fallbacks if LLM fails
- Error messages saved to MongoDB
- User-friendly error responses

---

## 📝 Environment Setup

### Required Environment Variables (`.env`)
```bash
MONGO_ATLAS_URI=mongodb+srv://smartiot:***@smartiot.pm14zxa.mongodb.net/LLM_logs?retryWrites=true&w=majority
MONGO_DB_NAME=LLM_logs
```

### Required Python Packages
```bash
pip install python-dotenv pymongo langchain-ollama pandas numpy flask flask-cors
```

---

## 🚀 Usage

### Starting the Server
```bash
python apillm.py
```

### Server Output
```
🚀 INITIALIZING ENHANCED ADVANCED LLM API SERVER
============================================================
✅ MongoDB connected - Chat history will be saved
✅ System initialized successfully
📊 System Health: healthy
📈 Data Quality: good
```

---

## 📊 Available Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/energy/report` | POST | Energy consumption reports with AI analysis |
| `/kpi/heartbeat` | POST | System health KPIs with AI insights |
| `/billing/rates` | POST | Billing rate analysis with AI recommendations |
| `/maintenance/predict` | POST | Maintenance request analysis with AI prioritization |
| `/anomalies/detect` | POST | Anomaly detection with AI pattern analysis |
| `/chat/history/save` | POST | Save chat to MongoDB |
| `/chat/history/get` | POST | Retrieve chat history from MongoDB |
| `/health` | GET | System health check |

---

## 🎓 Best Practices

1. **Always use specific queries**: "weekly energy report" instead of just "energy"
2. **Check system health first**: Use `/health` endpoint before making requests
3. **Monitor MongoDB**: Ensure MongoDB Atlas connection is active
4. **Review chat history**: Use saved chats for pattern analysis
5. **Act on AI recommendations**: The AI provides actionable insights - implement them!

---

*Last Updated: October 16, 2025*
*Version: 1.0*
