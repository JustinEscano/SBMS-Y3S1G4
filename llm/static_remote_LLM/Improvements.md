# Smart Building Management System - LLM API

Intelligent building management API powered by LLM for energy analysis, maintenance prediction, and conversational building insights.

## Latest Updates (v5.0 - October 17, 2025)

**🎉 Major New Features:**
- ✅ **Room Directory with LLM Analysis** - New `/rooms/list` endpoint
  - Real-time room data from database
  - AI-powered energy optimization recommendations
  - Space utilization insights
  - Equipment management priorities
- ✅ **100% LLM Coverage** - All 6 major endpoints now use AI
- ✅ **Enhanced Maintenance Display** - Full timestamps, complete descriptions
- ✅ **Smart Query Routing** - "show me rooms" auto-routes to room endpoint

**🐛 Critical Bug Fixes:**
- ✅ Fixed JSON syntax error in `advanced_prompts.json`
- ✅ Fixed RoomSpecificHandlers missing `get_available_rooms()` method
- ✅ Fixed NaT strftime errors (10 locations in maintenance documents)
- ✅ Fixed pandas SQLAlchemy warnings (11 query locations)
- ✅ Converted all database params from lists to tuples

**🔧 System Improvements:**
- ✅ SQLAlchemy engine integration for all database queries
- ✅ Maintenance requests show formatted timestamps ("Oct 17, 2025 12:30 PM")
- ✅ Room data displays real-time sensor information
- ✅ Better error handling across all endpoints
- ✅ Clean startup - zero errors, zero warnings

**📚 Documentation:**
- ✅ Updated README.md with Python 3.11 requirements
- ✅ Added comprehensive IMPROVEMENTS.md changelog
- ✅ Created room functionality guide
- ✅ Added troubleshooting section

**What's Working:**
- All 6 endpoints with LLM-powered insights
- Room directory with AI recommendations
- Daily/Weekly/Monthly/Yearly energy reports
- Maintenance tracking with status grouping
- Anomaly detection with pattern analysis
- Billing analysis with cost optimization
- KPI monitoring with health assessment

## Requirements

**Python Version:** 3.11 (Required)
- ⚠️ Python 3.14+ is NOT compatible with langchain dependencies
- ✅ Python 3.11 is recommended and tested

## Quick Start

### 1. Install Dependencies
```bash
pip install -r requirements-llm.txt
```

### 2. Start the Server
```bash
python apillm.py
```

Server runs on: `http://localhost:5000`

## API Endpoints

### 1. General Chat 
`POST /llmquery`
```json
{
  "query": "what can you do?",
  "session_id": "user123"
}
```

### 2. Room Directory (NEW!)
`GET /rooms/list` or `POST /rooms/list`
```json
{
  "user_id": "user123",
  "username": "John Doe"
}
```

**Features:**
- Real-time room data with sensor information
- Equipment counts per room
- Temperature, humidity, energy usage
- **AI provides 3 recommendations:**
  1. Energy Optimization - which rooms to optimize first
  2. Space Utilization - how to better use rooms across floors
  3. Equipment Management - maintenance/upgrade priorities

**Example Response:**
```
🏢 **ROOM DIRECTORY**

📊 **Total Rooms**: 6

[Room listings with details...]

🤖 **AI RECOMMENDATIONS**

**1. ENERGY OPTIMIZATION:**
Focus on Break Room D which consumes 11.50 kWh...

**2. SPACE UTILIZATION:**
With 6 rooms across 4 floors, consolidate...

**3. EQUIPMENT MANAGEMENT:**
10 devices need regular maintenance...
```

### 3. Energy Reports
`POST /energy/report`
```json
{
  "period": "daily|weekly|monthly|yearly",
  "user_id": "user123",
  "username": "John Doe"
}
```

### 4. Maintenance Predictions
`POST /maintenance/predict`
```json
{
  "query": "provide 3 maintenance requests",
  "user_id": "user123",
  "username": "John Doe"
}
```

Supports dynamic counts:
- "provide 1 maintenance request" → Shows 1
- "give me 5 issues" → Shows 5
- "show 10 requests" → Shows 10
- "show maintenance" → Shows all (max 50)

### 5. Anomaly Detection
`POST /anomalies/detect`

### 6. Billing Analysis
`POST /billing/rates`

### 7. System Health
`GET /health`

## Key Features

### Dynamic Maintenance Requests
Request any number of maintenance items (1-50):
- Supports numbers: "provide **3** maintenance requests"
- Supports words: "give me **three** issues"
- Smart detection with regex

### Enhanced Conversational AI
- Uses building context (room names, energy data)
- Provides specific, actionable insights
- Maintains conversation history (last 5 messages)
- Offers concrete next steps

### Energy Analysis with Timestamps
- Formatted date ranges
- Peak time detection
- Percentage breakdown per room
- Period-aware recommendations

### Smart Query Routing
Automatically detects intent:
- Energy queries → Energy analysis
- Maintenance queries → Maintenance predictions
- General questions → Conversational responses

## Example Queries

### General Questions
- "what can you do?"
- "tell me about rooms"
- "how can you help me?"

### **Maintenance:**
- "provide 1 maintenance request"
- "give me 5 maintenance issues"
- "show 10 maintenance requests"

### Energy
- "daily energy report"
- "weekly energy analysis"
- "which room uses the most energy?"

## Configuration

### Environment Variables
Copy `.env_sample` to `.env` and configure:
```env
MONGODB_URI=mongodb://localhost:27017/
DATABASE_NAME=building_management
OLLAMA_MODEL=incept5/llama3.1-claude:latest
```

### LLM Model
Uses Ollama with `incept5/llama3.1-claude:latest`
- Temperature: 0.7
- Direct LLM calls (bypasses vector store for speed)

## Response Format

### Energy Report
```
📅 REPORTING PERIOD: October 10, 2025 to October 17, 2025
📊 Report Generated: October 17, 2025 at 12:30 AM

ENERGY DATA:
- Period: WEEKLY
- Total consumption: 245.50 kWh
- Peak: 45.2 kWh (occurred on October 15, 2025 at 02:30 PM)

TOP CONSUMING ROOMS:
1. Conference Room A: 85.3 kWh (34.7% of total)

🤖 AI ANALYSIS
[LLM-generated insights]
```

### **Maintenance:**
```
🔧 MAINTENANCE REQUESTS

🔴 PENDING REQUESTS (3):
1. 🟠 Sensor Device 2 - Office Room B
   📝 Issue: Temperature sensor error
   🔧 Action: Replace unit
   👤 Requested by: admin_user

🤖 AI RECOMMENDATIONS
[Priority, Resources, Pattern Analysis]
```

## Best Practices

1. Use specific queries for better results
2. Provide session_id for conversation context
3. Request specific numbers for maintenance (e.g., "3 requests")
4. Use period parameter for energy reports

---

## Files

- `apillm.py` - Main API server
- `main.py` - Core LLM logic
- `database_adapter.py` - Database operations
- `prompts_config.py` - Prompt templates
- `advanced_prompts.json` - Advanced prompt configurations

## Troubleshooting

### Server won't start
- Check if port 5000 is available
- Verify MongoDB is running
- Check Ollama service is running

### LLM responses are slow
- Direct LLM calls bypass vector store (faster)
- Check Ollama model is downloaded
- Verify network connection

### No building data
- Ensure database has room and energy data
- Check database connection in `.env`

## Version History

**v5.0** (October 17, 2025 - Production Release)

**🎉 Major Features:**
- ✅ **Room Directory with LLM** - New `/rooms/list` endpoint
  - Real-time room data from `core_room` table
  - AI-powered energy optimization recommendations
  - Space utilization insights
  - Equipment management priorities
  - Calculates statistics: total equipment, avg temp, energy usage
  - Identifies highest/lowest energy consumers
- ✅ **100% LLM Coverage** - All 6 major endpoints now use AI
- ✅ **Enhanced Maintenance** - Full timestamps, complete descriptions, status grouping
- ✅ **Smart Query Routing** - "show me rooms" auto-routes to room endpoint

**🐛 Critical Bug Fixes:**
- ✅ Fixed JSON syntax error in `advanced_prompts.json` (missing comma)
- ✅ Fixed RoomSpecificHandlers missing `get_available_rooms()` method
- ✅ Fixed NaT strftime errors (10 locations in maintenance document creation)
- ✅ Fixed pandas SQLAlchemy warnings (11 query locations)
- ✅ Converted all database query params from lists to tuples
- ✅ Fixed room utilization showing placeholder message

**🔧 System Improvements:**
- ✅ SQLAlchemy engine integration for all database queries
- ✅ Maintenance timestamps formatted as "Oct 17, 2025 12:30 PM"
- ✅ Room data displays real-time sensor information
- ✅ Better error handling with fallback recommendations
- ✅ Clean startup - zero errors, zero warnings
- ✅ MongoDB integration for room queries

**📚 Documentation:**
- ✅ Updated README.md with Python 3.11 requirements
- ✅ Added comprehensive IMPROVEMENTS.md changelog
- ✅ Created ROOM_FUNCTIONALITY_GUIDE.md
- ✅ Added FRONTEND_ROOM_UPDATE.md
- ✅ Updated troubleshooting section

**Frontend Updates:**
- ✅ Enhanced `callRoomUtilization()` to display LLM analysis
- ✅ Added MongoDB saving for room queries
- ✅ Statistics logging to console
- ✅ Better loading messages ("🏢 Loading room directory with AI insights...")
- ✅ Error handling with user-friendly messages

**Files Modified:**
- `apillm.py` - Added room endpoint with LLM analysis
- `database_adapter.py` - Added `get_rooms_detailed()` method, SQLAlchemy fixes
- `main.py` - Fixed NaT strftime errors, added room handler
- `advanced_prompts.json` - Fixed JSON syntax
- `LLMChatPage.tsx` - Enhanced room display with AI
- `README.md` - Updated documentation
- `Improvements.md` - This file

**v4.0** (October 17, 2025 - Late Night Update)

**Backend Improvements:**
- ✅ Fixed energy report date filtering (overlapping period logic)
- ✅ Smart date detection - shows actual data available in database
- ✅ Dynamic maintenance request count (supports any number 1-50)
- ✅ Enhanced LLM prompts with variance and efficiency metrics
- ✅ Improved general query responses with building context
- ✅ Recent period limits (daily: 7, weekly: 4, monthly: 3, yearly: 2)
- ✅ Fixed database adapter date range queries
- ✅ Removed hardcoded date lookbacks

**Frontend Improvements:**
- ✅ Chat persistence using localStorage (survives navigation)
- ✅ Session management with unique IDs
- ✅ Auto-save messages on every change
- ✅ MongoDB backup for chat history
- ✅ Fixed TypeScript type definitions
- ✅ Removed unused imports

**v3.0** (October 17, 2025)
- ✅ Dynamic maintenance request count (1-50)
- ✅ Enhanced conversational AI
- ✅ Energy reports with timestamps
- ✅ Improved system prompts
- ✅ Conversation history support

**v2.0** (October 16, 2025)
- ✅ Added energy report endpoint
- ✅ Enhanced maintenance predictions
- ✅ MongoDB integration

**v1.0** (Initial Release)
- ✅ Basic LLM chat
- ✅ Maintenance predictions
- ✅ Energy analysis

## Contributing

1. Follow existing code style
2. Test all endpoints before committing
3. Update this README for new features

## License

MIT License - See LICENSE file for details

---

## 📊 Current Status (v5.0)

### All Endpoints with LLM
| Endpoint | LLM Model | Analysis Type | Status |
|----------|-----------|---------------|--------|
| `/rooms/list` | incept5/llama3.1-claude:latest | Utilization insights | ✅ NEW |
| `/energy/report` | incept5/llama3.1-claude:latest | Consumption analysis | ✅ Working |
| `/maintenance/predict` | incept5/llama3.1-claude:latest | Prioritization | ✅ Enhanced |
| `/anomalies/detect` | incept5/llama3.1-claude:latest | Pattern analysis | ✅ Working |
| `/billing/rates` | incept5/llama3.1-claude:latest | Cost optimization | ✅ Working |
| `/kpi/heartbeat` | incept5/llama3.1-claude:latest | Health assessment | ✅ Working |

### System Health
- ✅ **Zero Startup Errors**
- ✅ **Zero Warnings**
- ✅ **All Endpoints Operational**
- ✅ **MongoDB Connected**
- ✅ **PostgreSQL Optimized**
- ✅ **LLM Integration Complete**

### Production Ready
- ✅ Error handling with fallbacks
- ✅ MongoDB chat history
- ✅ Comprehensive documentation
- ✅ Python 3.11 compatible
- ✅ Frontend integration complete

**Status**: PRODUCTION READY 🚀

---

*Last Updated: October 17, 2025*
*Version: 5.0*
*All Endpoints: LLM-Powered ✅*

