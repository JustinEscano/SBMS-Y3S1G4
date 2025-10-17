# 🏢 Smart Building Management System - AI Features

[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Flask-3.0-green.svg)](https://flask.palletsprojects.com/)
[![MongoDB](https://img.shields.io/badge/MongoDB-Atlas-green.svg)](https://www.mongodb.com/)
[![LLM](https://img.shields.io/badge/LLM-Ollama-orange.svg)](https://ollama.ai/)

## 🎯 Overview

An intelligent building management system powered by **Large Language Models (LLM)** that provides AI-driven insights for energy optimization, maintenance planning, anomaly detection, and system health monitoring. All features leverage **Ollama LLM** (`incept5/llama3.1-claude:latest`) to deliver actionable recommendations.

### ✨ Key Highlights

- 🤖 **AI-Powered Analysis** - Every feature uses LLM for intelligent insights
- 💾 **MongoDB Integration** - All interactions saved to MongoDB Atlas
- 📊 **Real-Time Monitoring** - Live system health and performance metrics
- 🔋 **Energy Optimization** - Smart recommendations to reduce costs
- ⚠️ **Anomaly Detection** - Proactive issue identification
- 🔧 **Predictive Maintenance** - AI-driven maintenance prioritization

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
• Average Rate: 0.1740 PHP/kWh
• Lowest Rate: 0.1200 PHP/kWh
• Highest Rate: 0.2200 PHP/kWh
• Currency: PHP (Philippine Peso)

⏰ Rate Schedule:
1. 0.1500 PHP/kWh
   Time: 09:00:00 - 18:00:00
   Valid: 10/1/2025 → 12/31/2025

2. 0.1200 PHP/kWh (Off-Peak)
   Time: 22:00:00 - 06:00:00
   Valid: 10/1/2025 → 12/31/2025

🤖 **AI ANALYSIS**

**1. RATE ANALYSIS:**
Significant rate variation between peak (0.22 PHP/kWh) and off-peak (0.12 PHP/kWh) 
hours presents optimization opportunities. Peak rates occur during business hours.

**2. COST OPTIMIZATION:**
Shifting 30% of energy-intensive operations to off-peak hours could reduce monthly 
electricity costs by approximately 15-20%.

**3. ACTION ITEMS:**
Schedule HVAC pre-cooling during off-peak hours, run heavy equipment after 10 PM, 
and implement automated load scheduling based on rate windows.
```

### User Queries
- "show billing rates"
- "what are the rates?"
- "billing analysis"
- "show me the pricing"

---

## 🏢 Room Directory

### Endpoint
`GET /rooms/list` or `POST /rooms/list`

### Description
Displays comprehensive room directory with real-time data and context-aware AI analysis based on your specific query.

### Features
- **Real-Time Data**: Room info, equipment counts, temperature, humidity, energy usage
- **Context-Aware AI**: Different responses based on your query type
- **Smart Analysis**: Availability, detailed analysis, floor-specific, or general overview

### Query Types

**1. Availability Queries**
- "what rooms are available"
- "which rooms can I book"
- AI focuses on: Immediate availability, best rooms for different uses, scheduling optimization

**2. Detailed Analysis**
- "analyze specific rooms"
- "room analysis"
- AI focuses on: Energy efficiency analysis, equipment infrastructure, optimization opportunities

**3. Floor-Specific**
- "show me floor 2"
- "what's on floor 1"
- AI focuses on: Floor overview, floor optimization, floor-specific recommendations

**4. General Overview**
- "show me rooms"
- "list all rooms"
- AI focuses on: Energy optimization, space utilization, equipment management

### Example Response
```
🏢 **ROOM DIRECTORY**

📊 **Total Rooms**: 5

**Floor 1:**
📍 **Conference Room A**
   • Type: Meeting
   • Capacity: 20 people
   • Equipment: 2 devices
   • Current Temp: 23.8°C
   • Humidity: 52.5%
   • Avg Energy: 8.85 kWh
   • Pattern: weekdays 9-5

🤖 **AI RECOMMENDATIONS**
[Context-aware recommendations based on your query]
```

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
Detects system anomalies from alerts and provides AI-powered analysis and recommendations. Analyzes all historical alerts with no date restrictions.

### Features
- **Alert Analysis**: Analyzes ALL alerts (no date restriction)
- **Severity Grouping**: High, Medium, Low levels
- **Type Categorization**: Groups by alert type
- **Equipment Tracking**: Shows which equipment triggered alerts
- **Status Monitoring**: Active vs Resolved alerts
- **Timestamp Formatting**: Human-readable dates (e.g., "Oct 3, 2025, 08:00 PM")
- **AI Analysis**: LLM provides 3 structured recommendations:
  1. **Critical Issues**: Anomalies needing immediate attention
  2. **Pattern Analysis**: Patterns in the alerts
  3. **Preventive Actions**: How to prevent future anomalies

### Data Source
- Table: `core_alert`
- Fields: `type`, `message`, `severity`, `triggered_at`, `resolved`, `equipment_id`
- Joins: `core_equipment`, `core_room` for detailed context

### Example Response
```
⚠️ **ANOMALY DETECTION**

📊 Alert Summary:
• Total Alerts: 10
• Unresolved: 3
• Severity: High: 3, Medium: 5, Low: 2
• Alert Types: 5 different types

📋 Recent Alerts:

**1. [HIGH] temperature_high**
   📝 High temperature detected
   🔧 Equipment: Sensor Device 1
   📅 Oct 3, 2025, 08:00 PM
   🔴 Active

**2. [MEDIUM] motion**
   📝 Motion detected
   🔧 Equipment: Camera Device 2
   📅 Oct 4, 2025, 01:00 PM
   ✅ Resolved

🤖 **AI ANALYSIS**

**1. CRITICAL ISSUES:**
3 unresolved high-priority alerts require immediate attention. Temperature anomalies 
in Sensor Device 1 indicate potential HVAC system failure.

**2. PATTERN ANALYSIS:**
Motion alerts are most frequent (5 occurrences), suggesting possible sensor 
sensitivity issues or increased activity in monitored areas.

**3. PREVENTIVE ACTIONS:**
Schedule HVAC maintenance, review motion sensor calibration, and implement 
automated alert escalation for high-severity issues.
```

### User Queries
- "show me anomalies"
- "detect anomalies"
- "show me alerts"
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
<<<<<<< HEAD
MONGO_ATLAS_URI=mongodb+srv://username:password@cluster.mongodb.net/LLM_logs?retryWrites=true&w=majority
=======
MONGO_ATLAS_URI= MAKE SURE TO USE YOUR OWN MONGO ATLAS DATABASE.
>>>>>>> 2ea06833730776ed5f07ffd449226523df298f68
MONGO_DB_NAME=LLM_logs
```

### Python Version Requirement
**CRITICAL**: Must use **Python 3.11**
- ✅ Python 3.11.x works
- ❌ Python 3.12 may have compatibility issues
- ❌ Python 3.10 missing required features

### Virtual Environment Required
**CRITICAL**: Must use a virtual environment
```bash
# Create with Python 3.11
py -3.11 -m venv myenv

# Activate before running
myenv\Scripts\activate  # Windows
source myenv/bin/activate  # Linux/Mac
```

### Required Python Packages
All packages are in `requirements_llm.txt`:
```bash
pip install -r requirements_llm.txt
```

Key packages:
- Flask 3.0
- SQLAlchemy
- pandas
- langchain-ollama
- pymongo
- psycopg2

---

## 🚀 Usage

### Starting the LLM Server

**Step 1**: Activate virtual environment
```bash
cd llm/static_remote_LLM
myenv\Scripts\activate  # Windows
```

**Step 2**: Run server
```bash
python apillm.py runserver 0.0.0.0:5000
```

### Expected Server Output
```
🚀 INITIALIZING ENHANCED ADVANCED LLM API SERVER
============================================================
✅ MongoDB connected - Chat history will be saved
✅ System initialized successfully
📊 System Health: healthy
📈 Data Quality: good
🗂️  Records Loaded: 10

📡 Available Endpoints:
  GET   /health
  POST  /llmquery
  GET   /rooms/list
  POST  /energy/report
  POST  /maintenance/predict
  ...

🌐 Starting enhanced server on http://localhost:5000
```

### Troubleshooting

**Error: "No module named 'flask'"**
- Solution: Activate virtual environment first

**Error: "Python version mismatch"**
- Solution: Use Python 3.11 specifically

**Error: "MongoDB connection failed"**
- Solution: Check `.env` file has correct MongoDB URI

**Error: "PostgreSQL connection failed"**
- Solution: Ensure PostgreSQL is running on localhost:5432

---

## 📊 Feature Comparison Table

| Feature | Data Source | AI Analysis | MongoDB Logging | Time Range | Output Format |
|---------|-------------|-------------|-----------------|------------|---------------|
| **Room Directory** | `core_room` + joins | ✅ Context-aware insights | ✅ All queries saved | Real-time | Room list + AI recommendations |
| **Energy Reports** | `core_energylog` | ✅ 3-part recommendations | ✅ All queries saved | Daily/Weekly/Monthly/Yearly | Statistics + AI insights |
| **KPI Monitoring** | `core_heartbeatlog` | ✅ Health assessment | ✅ All queries saved | Last 100 records | Performance metrics + AI |
| **Billing Rates** | `core_billingrate` | ✅ Cost optimization | ✅ All queries saved | All active rates | Rate schedule + AI |
| **Maintenance** | `core_maintenancerequest` | ✅ Prioritization | ✅ All queries saved | All requests | Grouped by status + AI |
| **Anomalies** | `core_alert` | ✅ Pattern analysis | ✅ All queries saved | All historical | Alert list + AI |

---

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Frontend (React + TypeScript)            │
│  - LLMChatPage.tsx                                          │
│  - Real-time chat interface                                 │
│  - Markdown rendering                                       │
└────────────────────┬────────────────────────────────────────┘
                     │ HTTP/REST API
┌────────────────────▼────────────────────────────────────────┐
│                   Backend (Flask + Python)                   │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  apillm.py - Main API Server                         │  │
│  │  - Energy Reports (/energy/report)                   │  │
│  │  - KPI Monitoring (/kpi/heartbeat)                   │  │
│  │  - Billing Analysis (/billing/rates)                 │  │
│  │  - Maintenance (/maintenance/predict)                │  │
│  │  - Anomalies (/anomalies/detect)                     │  │
│  └──────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  database_adapter.py - PostgreSQL Interface          │  │
│  │  - Query optimization                                │  │
│  │  - Data transformation                               │  │
│  └──────────────────────────────────────────────────────┘  │
└────────┬──────────────────────────┬────────────────────────┘
         │                          │
         │                          │
┌────────▼──────────┐      ┌────────▼──────────────────────┐
│   PostgreSQL DB   │      │   Ollama LLM Engine           │
│  - core_energylog │      │  Model: incept5/llama3.1-     │
│  - core_alert     │      │         claude:latest         │
│  - core_billing   │      │  - Natural language analysis  │
│  - core_heartbeat │      │  - Pattern recognition        │
│  - core_maintenance│      │  - Recommendations generation │
└───────────────────┘      └───────────────────────────────┘
         │
         │
┌────────▼──────────────────────────────────────────────────┐
│              MongoDB Atlas (Chat History)                  │
│  Database: LLM_logs                                       │
│  Collection: chat_history                                 │
│  - User queries                                           │
│  - AI responses                                           │
│  - Metadata & timestamps                                  │
└───────────────────────────────────────────────────────────┘
```

---

## 📊 Available Endpoints

| Endpoint | Method | Description | Status |
|----------|--------|-------------|--------|
| `/health` | GET | System health check | ✅ |
| `/llmquery` | POST | General LLM chat | ✅ |
| `/rooms/list` | GET/POST | Room directory with context-aware AI | ✅ NEW |
| `/energy/report` | POST | Energy analysis (daily/weekly/monthly/yearly) | ✅ |
| `/maintenance/predict` | POST | Maintenance with timestamps & AI | ✅ Enhanced |
| `/anomalies/detect` | POST | Anomaly detection with AI | ✅ Enhanced |
| `/billing/rates` | POST | Billing analysis with AI | ✅ |
| `/kpi/heartbeat` | POST | KPI monitoring | ✅ |
| `/chat/history/save` | POST | Save chat to MongoDB | ✅ |
| `/chat/history/get` | POST | Get chat history | ✅ |
| `/system/status` | GET | System status | ✅ |

---

## 🎓 Best Practices

### For Users
1. **Use specific queries**: "weekly energy report" instead of just "energy"
2. **Review AI recommendations**: The AI provides actionable insights - implement them!
3. **Check patterns**: Use anomaly detection regularly to catch issues early
4. **Optimize costs**: Act on billing rate recommendations to reduce expenses

### For Developers
1. **Check system health first**: Use `/health` endpoint before making requests
2. **Monitor MongoDB**: Ensure MongoDB Atlas connection is active
3. **Review chat history**: Use saved chats for pattern analysis and debugging
4. **Handle errors gracefully**: All endpoints have fallback responses
5. **Test LLM responses**: Verify AI recommendations are relevant and accurate

---

## 🚀 Quick Start

### Prerequisites

**IMPORTANT**: This LLM server **requires Python 3.11** and a virtual environment.

- ✅ Python 3.11 (not 3.12 or 3.10)
- ✅ PostgreSQL database running
- ✅ MongoDB Atlas account
- ✅ Ollama with `incept5/llama3.1-claude:latest` model

### Installation

#### 1. Clone Repository
```bash
git clone https://github.com/yourusername/SBMS-Y3S1G4.git
cd SBMS-Y3S1G4
```

#### 2. Set Up LLM Server
```bash
cd llm/static_remote_LLM

# Create virtual environment with Python 3.11
py -3.11 -m venv myenv

# Activate virtual environment
# On Windows:
myenv\Scripts\activate
# On Linux/Mac:
source myenv/bin/activate

# Install dependencies
pip install -r requirements_llm.txt
```

#### 3. Configure Environment
```bash
# Create .env file
cp .env.example .env

# Edit .env with your credentials:
# MONGO_ATLAS_URI=mongodb+srv://...
# MONGO_DB_NAME=LLM_logs
```

#### 4. Start LLM Server
```bash
# Make sure virtual environment is activated (myenv)
python apillm.py runserver 0.0.0.0:5000
```

**Expected Output**:
```
🚀 INITIALIZING ENHANCED ADVANCED LLM API SERVER
============================================================
✅ MongoDB connected - Chat history will be saved
✅ System initialized successfully
📊 System Health: healthy
```

Server runs on `http://localhost:5000`

#### 5. Start Frontend (Optional)
```bash
# In a new terminal
cd web
npm install
npm run dev
```

Frontend runs on `http://localhost:3000` (or your configured port)

---

## 📈 Performance Metrics

- **Average Response Time**: < 2 seconds (including LLM processing)
- **MongoDB Write Speed**: < 100ms per chat save
- **Database Query Time**: < 500ms for most queries
- **LLM Analysis Time**: 1-3 seconds depending on complexity
- **Concurrent Users**: Supports 50+ simultaneous connections

---

## 🔒 Security Considerations

- ✅ Environment variables for sensitive data
- ✅ CORS configuration for frontend access
- ✅ MongoDB Atlas with authentication
- ✅ PostgreSQL connection pooling
- ✅ Error messages don't expose system details
- ✅ Input validation on all endpoints

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---

## 📝 License

This project is part of an academic assignment for Year 3 Semester 1 Group 4.

---

## 👥 Team

**Year 3 Semester 1 - Group 4**

---

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Check the chat history in MongoDB for debugging
- Review server logs for error details

---

---

## 🆕 Recent Updates (October 17, 2025)

### New Features
- ✅ **Room Directory with Context-Aware AI**: New `/rooms/list` endpoint
  - Real-time room data with equipment and sensor information
  - Context-aware AI responses based on query type
  - Supports: availability queries, detailed analysis, floor-specific, general overview
  - Different AI recommendations for different query types
- ✅ **Enhanced Anomaly Detection**: Improved alert display with formatted details
  - Shows all alerts with severity indicators
  - Equipment information and timestamps
  - AI pattern analysis and recommendations
  - Better keyword detection ("alert", "warning", "anomaly")
- ✅ **Enhanced Maintenance**: Full timestamps, complete descriptions, status grouping

### Bug Fixes
- ✅ Fixed JSON syntax error in `advanced_prompts.json`
- ✅ Fixed RoomSpecificHandlers missing method
- ✅ Fixed NaT strftime errors in maintenance documents
- ✅ Fixed pandas SQLAlchemy warnings (11 query locations)
- ✅ Fixed f-string formatting error in room LLM context (was preventing LLM from running)

### Improvements
- ✅ All database queries now use SQLAlchemy engine
- ✅ Maintenance requests show formatted timestamps
- ✅ Anomaly detection displays formatted alert details
- ✅ Room queries now context-aware (different AI responses for different query types)
- ✅ Better error handling across all endpoints
- ✅ Enhanced frontend keyword detection for room queries

**See `IMPROVEMENTS.md` for detailed changelog**

---

*Last Updated: October 17, 2025*  
*Version: 2.1*  
*Documentation: Comprehensive AI Features Guide*
