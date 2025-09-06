# Web LLM Integration Setup Guide

Your LLM is now integrated into your web application! Here's how to run everything:

## 🚀 Quick Start

### 1. Start the Django API Server
```bash
cd c:\LLM\LLMV2\SBMS-Y3S1G4\api
python manage.py runserver
```

### 2. Start the Web Development Server
```bash
cd c:\LLM\LLMV2\SBMS-Y3S1G4\web
npm run dev
```

### 3. Access the LLM Chat
- Open your web application
- Navigate to the LLM Chat page
- Start asking questions about your building data!

## 🔧 What's Been Added

### New Files Created:
1. **`web/src/service/LLMService.tsx`** - Service for API communication
2. **`web/src/components/LLMTestComponent.tsx`** - Test component for debugging

### Updated Files:
1. **`web/src/features/pages/LLMChatPage.tsx`** - Full chat functionality
2. **`web/src/features/pages/LLMChatPage.css`** - Enhanced styling

## 🎯 Features

### ✅ **Real-time Chat Interface**
- Send messages to your LLM
- Receive responses with source citations
- Loading indicators and error handling

### ✅ **Health Monitoring**
- Real-time LLM service status
- Connection health indicators
- Retry functionality

### ✅ **Smart Suggestions**
- Pre-built query suggestions
- Context-aware recommendations
- Easy-to-use suggestion buttons

### ✅ **Source Citations**
- View data sources for each response
- Timestamp and metadata display
- Transparency in AI responses

## 🔍 Testing the Integration

### Option 1: Use the Chat Interface
1. Go to your LLM Chat page
2. Try these sample queries:
   - "What is the average temperature?"
   - "Show me the highest energy consumption"
   - "How many sensor records do we have?"

### Option 2: Use the Test Component
Add this to any page to test the connection:
```tsx
import LLMTestComponent from '../components/LLMTestComponent';

// In your component:
<LLMTestComponent />
```

## 📊 Sample Queries to Try

### Basic Statistics
- "What is the average temperature?"
- "Show me the highest energy consumption"
- "What is the lowest humidity recorded?"

### Time-based Queries
- "What was the temperature at 2024-01-15 10:30:00?"
- "Show me all readings from today"

### Equipment Queries
- "Which rooms have motion detected?"
- "List all equipment that is offline"

### Complex Analysis
- "Compare energy usage between different rooms"
- "Show me temperature trends over time"

## 🛠️ API Endpoints Used

Your web app now connects to these Django API endpoints:

### LLM Query
```
POST /api/llm/query/
{
  "query": "What is the average temperature?",
  "user_id": "optional_user_id"
}
```

### Health Check
```
GET /api/llm/health/
```

## 🎨 UI Features

### Chat Interface
- **Dark theme** optimized for data analysis
- **Floating input bar** for easy access
- **Message bubbles** with user/assistant distinction
- **Auto-scroll** to latest messages

### Status Indicators
- 🟢 **Green**: LLM is healthy and ready
- 🟡 **Yellow**: Checking LLM status
- 🔴 **Red**: LLM service unavailable

### Interactive Elements
- **Suggestion buttons** for quick queries
- **Source citations** with metadata
- **Loading animations** for better UX
- **Clear chat** functionality

## 🔧 Troubleshooting

### LLM Service Unavailable
1. Check if Django server is running
2. Verify Ollama is running with required models
3. Check the health endpoint: `http://localhost:8000/api/llm/health/`

### No Data in Responses
1. Ensure your database has sensor data
2. Check if the database adapter is working
3. Run the database test script

### CORS Issues
1. Verify Django CORS settings
2. Check if the web app URL is in `ALLOWED_HOSTS`

## 🚀 Next Steps

### Enhance the Chat Experience
1. **Add message persistence** - Save chat history
2. **Add file upload** - Let users upload data files
3. **Add voice input** - Speech-to-text functionality
4. **Add export features** - Download chat transcripts

### Advanced Features
1. **Real-time data streaming** - Live sensor updates
2. **Custom dashboards** - Generate charts from queries
3. **Scheduled reports** - Automated insights
4. **Multi-language support** - Internationalization

## 📱 Mobile Responsiveness

The chat interface is fully responsive and works on:
- 📱 Mobile phones
- 📱 Tablets  
- 💻 Desktop computers
- 🖥️ Large screens

## 🎉 You're All Set!

Your LLM is now fully integrated into your web application! Users can:

1. **Ask natural language questions** about building data
2. **Get intelligent responses** with source citations
3. **Monitor system health** in real-time
4. **Access the chat** from any device

Start asking questions and exploring your building management data with AI! 🤖✨