# LLM Database Integration Setup Guide

This guide will help you connect your main.py LLM to your PostgreSQL database.

## Prerequisites

1. **PostgreSQL Database**: Your database should be running with the settings from `api/dbmsAPI/settings.py`
2. **Ollama**: Make sure Ollama is installed and running with the required models
3. **Python Environment**: Python 3.8+ with pip

## Installation Steps

### 1. Install Required Dependencies

Navigate to the LLM directory and install dependencies:

```bash
cd c:\LLM\LLMV2\SBMS-Y3S1G4\llm\static_remote_LLM
pip install -r requirements.txt
```

### 2. Verify Database Connection

Run the test script to verify everything is working:

```bash
python test_database_connection.py
```

This will test:
- Database connectivity
- Data retrieval from PostgreSQL
- LLM integration
- Vector store initialization

### 3. Test the Integration

If the test passes, you can now use your LLM with the database:

```python
from main import ask

# Ask questions about your sensor data
result = ask("What is the average temperature?")
print(result['answer'])

# Query energy consumption
result = ask("Show me the highest energy consumption")
print(result['answer'])
```

## API Endpoints

Your Django API now includes LLM endpoints:

### Query the LLM
```
POST /api/llm/query/
Content-Type: application/json

{
    "query": "What is the average temperature?",
    "user_id": "optional_user_id"
}
```

### Health Check
```
GET /api/llm/health/
```

## Example Usage

### From Python Code
```python
from main import ask

# Simple queries
result = ask("How many sensor records do we have?")
print(result['answer'])

# Complex queries
result = ask("What is the highest temperature and when did it occur?")
print(result['answer'])
print("Sources:", result['sources'])
```

### From API (using curl)
```bash
# Query the LLM via API
curl -X POST http://localhost:8000/api/llm/query/ \
  -H "Content-Type: application/json" \
  -d '{"query": "What is the average temperature?"}'

# Check LLM health
curl http://localhost:8000/api/llm/health/
```

### From Frontend (JavaScript)
```javascript
// Query the LLM
const response = await fetch('http://localhost:8000/api/llm/query/', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
    },
    body: JSON.stringify({
        query: 'What is the average temperature?',
        user_id: 'optional_user_id'
    })
});

const result = await response.json();
console.log(result.answer);
```

## Features

### Database Integration
- ✅ Connects to your existing PostgreSQL database
- ✅ Uses Django ORM models for data access
- ✅ Automatically converts sensor data to LLM-compatible format
- ✅ Supports real-time data queries

### LLM Capabilities
- ✅ Natural language queries about sensor data
- ✅ Statistical analysis (average, min, max, etc.)
- ✅ Time-based queries
- ✅ Equipment and room information
- ✅ Energy consumption analysis

### API Integration
- ✅ RESTful API endpoints
- ✅ Query logging to database
- ✅ Health monitoring
- ✅ Error handling

## Troubleshooting

### Database Connection Issues
1. Check PostgreSQL is running
2. Verify database credentials in `api/dbmsAPI/settings.py`
3. Ensure `psycopg2-binary` is installed

### LLM Issues
1. Check Ollama is running: `ollama list`
2. Verify models are available: `ollama pull nomic-embed-text`
3. Check model name in `main.py` matches your Ollama setup

### Import Errors
1. Ensure Django is properly configured
2. Check Python path includes the correct directories
3. Verify all dependencies are installed

## Configuration

### Database Settings
The database adapter uses settings from your Django configuration:
- Host: localhost
- Database: sbmsdb
- User: postgres
- Password: 9609
- Port: 5432

### LLM Models
Current configuration uses:
- Embedding Model: `nomic-embed-text`
- LLM Model: `incept5/llama3.1-claude:latest`

You can change these in `main.py` if needed.

## Sample Queries

Try these example queries:

1. **Basic Statistics**
   - "What is the average temperature?"
   - "Show me the highest energy consumption"
   - "How many sensor records do we have?"

2. **Time-based Queries**
   - "What was the temperature at 2024-01-15 10:30:00?"
   - "Show me all readings from today"

3. **Equipment Queries**
   - "Which rooms have motion detected?"
   - "List all equipment status"

4. **Complex Analysis**
   - "Compare energy usage between different rooms"
   - "Show me temperature trends over time"

## Next Steps

1. **Add More Data**: The more sensor data you have, the better the LLM responses
2. **Customize Queries**: Modify the deterministic query handlers in `main.py`
3. **Integrate with Frontend**: Use the API endpoints in your web/mobile applications
4. **Monitor Performance**: Check the logs and health endpoints regularly

## Support

If you encounter issues:
1. Check the logs in `room_analysis.log`
2. Run the test script to diagnose problems
3. Verify all prerequisites are met
4. Check the Django server logs for API issues