# Smart Building Management System - LLM API

Intelligent building management API powered by LLM for energy analysis, maintenance prediction, and conversational building insights.

## Latest Updates (v4.0 - October 17, 2025)

**Major Fixes:**
- Fixed energy report date filtering using overlapping period logic
- Smart date detection - automatically finds available data in database
- Dynamic maintenance requests - supports any number (e.g., "provide 3 maintenance requests")
- Enhanced LLM analysis with variance and efficiency metrics
- Improved general responses with specific building context

**What's Working:**
- Daily/Weekly/Monthly/Yearly energy reports with actual database dates
- Maintenance requests with flexible count (1-50)
- "What can you do?" queries with specific examples
- All endpoints with proper date handling

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

### 2. Energy Reports
`POST /energy/report`
```json
{
  "period": "daily|weekly|monthly|yearly",
  "user_id": "user123",
  "username": "John Doe"
}
```

### 3. Maintenance Predictions
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

### 4. Anomaly Detection
`POST /anomalies/detect`

### 5. Billing Analysis
`POST /billing/rates`

### 6. System Health
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

