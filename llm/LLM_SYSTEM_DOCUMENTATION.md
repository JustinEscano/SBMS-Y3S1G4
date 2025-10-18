# ORB AI - Comprehensive Documentation

## 📖 Overview

ORB AI is a cutting-edge, AI-powered system designed to revolutionize building management by processing and analyzing room sensor data, maintenance requests, and energy consumption patterns. By blending deterministic data processing with advanced Large Language Model (LLM) capabilities, ORB AI delivers intelligent insights for building management, energy efficiency, and maintenance operations.

## 🏢 Core Capabilities

ORB AI empowers users with a robust set of tools to monitor and optimize building operations. Here's what it can do:

### 1. Room Analysis & Usage Tracking

- **Room Counting**: Track total and occupied rooms in real-time.
- **Room Utilization**: Identify the most-used rooms and analyze usage patterns.
- **Occupancy Analysis**: Monitor people counts and room usage statistics.
- **Space Optimization**: Gain insights into room efficiency and utilization metrics.

### 2. Energy & Power Consumption Analysis

- **Real-time Monitoring**: View current power consumption across all rooms.
- **Energy Trends**: Analyze consumption patterns over time.
- **Power Breakdown**: Detailed component-wise consumption analysis (e.g., lighting, HVAC).
- **Efficiency Metrics**: Track energy usage per room and equipment.

### 3. Environmental Monitoring

- **Temperature Tracking**: Monitor current, average, min/max temperatures.
- **Humidity Analysis**: Assess environmental humidity levels.
- **Climate Control**: Evaluate HVAC system performance.
- **Comfort Metrics**: Ensure optimal environmental conditions for occupants.

### 4. Maintenance Management

- **Issue Tracking**: Monitor pending and resolved maintenance requests.
- **Equipment Status**: Check functionality and repair needs of equipment.
- **Maintenance Scheduling**: Track request status and resolution timelines.
- **Fault Detection**: Identify equipment malfunctions proactively.

### 5. Advanced Analytics & Reporting

- **Building Performance Dashboard**: Comprehensive KPIs with efficiency scoring and ratings.
- **Smart Recommendations**: Context-aware, actionable suggestions based on real data.
- **Multi-Period Reports**: Daily, weekly, monthly, and yearly energy reports.
- **Trend Analysis**: Identify energy and usage patterns with cost projections.
- **Anomaly Detection**: Detect unusual patterns and potential issues with alerts.
- **Billing Analysis**: Real-time rate information with cost optimization suggestions.

## 🗣️ What You Can Ask

ORB AI is designed to handle a wide range of queries, from simple data lookups to complex analytical insights. Below are example prompts, highlighted for clarity, to show what you can ask:

### Room-Related Questions

#### Basic Room Information

- "How many rooms are in the system?"
- "How many rooms are currently occupied?"
- "Show me all available rooms."
- "What's the room capacity across the building?"

#### Room Usage & Utilization

- "What's the most used room?"
- "Show me room utilization statistics."
- "Which room has the highest occupancy?"
- "Room usage patterns this week."

#### Specific Room Queries

- "What's happening in Room 101 right now?"
- "Show me data for Conference Room A."
- "How many people are in the main hall?"
- "Temperature in the laboratory."

### Energy & Power Questions

#### Consumption Analysis

- "What's the highest energy consumption recorded?"
- "Show me the lowest power usage."
- "What's the average energy consumption?"
- "Total energy used today."

#### Power Breakdown

- "Power consumption breakdown for Room 205."
- "Show me lighting power usage."
- "HVAC system power consumption."
- "Equipment power usage breakdown."

#### Trend Analysis

- "Show me energy trends this week."
- "Analyze power usage patterns."
- "Energy consumption comparison by room."
- "Weekly energy summary."

### Environmental Questions

#### Temperature & Climate

- "What's the highest temperature recorded?"
- "Show me the lowest humidity levels."
- "Average temperature across all rooms."
- "Temperature trends over time."
- "Current environmental conditions."

#### Comfort & Conditions

- "Which rooms are too hot/cold?"
- "Humidity levels in meeting rooms."
- "Environmental comfort metrics."
- "Climate control efficiency."

### Maintenance Questions

#### Status & Tracking

- "How many pending maintenance requests?"
- "Show me resolved maintenance issues."
- "What equipment needs repair?"
- "Maintenance request status."

#### Specific Maintenance

- "Any broken equipment in Room 205?"
- "Show me recent maintenance activities."
- "Equipment fault history."
- "Pending HVAC repairs."

### Advanced Analytics

#### KPIs & Performance

- "Show me key performance indicators."
- "What are the energy efficiency metrics?"

#### Reports & Summaries

- "Generate weekly summary."
- "Show me this week's performance report."
- "Daily report" / "Monthly report" / "Yearly report"
- "Show me billing rates."
- "Check for maintenance issues."

#### Anomaly Detection

- "Are there any unusual energy spikes?"
- "Detect abnormal temperature patterns."
- "Identify equipment malfunctions."
- "System alerts and warnings."

## 📊 Expected Responses

ORB AI delivers two types of responses tailored to your needs:

### Deterministic Responses (Direct Data Answers)

- **Exact Numbers**: Room counts, temperature values, power consumption.
- **Specific Timestamps**: Precise timing of events.
- **Room Names**: Actual room identifiers from the database.
- **Maintenance Status**: Current state of repair requests.
- **Power Breakdowns**: Component-wise consumption details.

### LLM-Enhanced Responses (Analytical Insights)

- **Trend Analysis**: Detailed pattern identification and explanations.
- **Comparative Analysis**: Room-to-room or time-based comparisons.
- **Recommendations**: Actionable energy-saving and optimization suggestions.
- **Anomaly Explanations**: Root cause analysis for unusual patterns.
- **Summary Reports**: Consolidated insights with key findings.

## 🔧 Technical Features

ORB AI is built with cutting-edge technology to ensure robust performance and flexibility.

### Smart Query Processing

- **Deterministic Handling**: Direct data queries bypass LLM for 100% accuracy.
- **Mixed Query Support**: Handles multiple operations in a single question.
- **Context Awareness**: Understands temporal and spatial context.
- **Fallback Mechanism**: Uses LLM when deterministic methods are insufficient.

### Data Integration

- **Real-time Sensor Data**: Live updates on occupancy, temperature, and power consumption.
- **Maintenance Records**: Tracks repair requests, equipment status, and resolutions.
- **Historical Analysis**: Leverages stored data for trend analysis.
- **Equipment Monitoring**: Tracks HVAC, lighting, projectors, and computers.

### Advanced Capabilities

- **Duplicate Prevention**: Hash-based document deduplication.
- **Real-time Updates**: Continuous data loading and processing.
- **Vector Storage**: Uses ChromaDB for efficient similarity search.
- **Comprehensive Logging**: MongoDB logging for audits and improvements.

## 🎯 Example Interactions

### Simple Queries & Responses

**User:** "How many occupied rooms?"  
**AI:** "There are 5 occupied rooms: Conference Room A, Lab 101, Office 205, Classroom B, and Meeting Room 3."

**User:** "What's the highest temperature?"  
**AI:** "The highest temperature is 26.5°C in Lab 101 at 2024-01-15 14:30:00."

**User:** "How many pending maintenance requests?"  
**AI:** "There are 3 pending maintenance issues: HVAC issue in Conference Room A, projector replacement in Classroom B, and lighting repair in Office 205."

### Complex Analytical Queries

**User:** "Show me energy trends and pending maintenance."  
**AI:** "Energy consumption shows a 15% increase this week, with peak usage during 2-4 PM. There are 3 pending maintenance requests affecting efficiency. Recommendations: Optimize HVAC scheduling and address lighting repairs."

**User:** "Weekly summary with key findings."  
**AI:** "Weekly Summary: Total energy consumption: 1,250 kWh (↑8% from last week). Average occupancy: 45 people/day. 2 maintenance issues resolved. Key finding: High energy usage in unoccupied rooms suggests automated systems optimization needed."

**User:** "Analyze room utilization and suggest improvements."  
**AI:** "Room utilization analysis: Conference Room A (85% usage), Lab 101 (60%), Office 205 (45%). Recommendation: Consider repurposing underutilized Office 205 for additional collaborative space. Energy savings potential: 15% with better space allocation."

## 📈 Data Sources & Integration

### Primary Data Sources

- **PostgreSQL Database**: Stores real-time sensor data and maintenance records.
- **Room Sensors**: Capture occupancy, temperature, humidity, and power consumption.
- **Equipment Monitors**: Track lighting, HVAC, projectors, and computers.
- **Maintenance System**: Manages repair requests, equipment status, and work orders.

### Data Types Processed

- **Occupancy Data**: Status, counts, and room usage.
- **Power Consumption**: Total and component-wise (lighting, HVAC, etc.).
- **Energy Usage**: kWh consumption metrics.
- **Equipment Usage**: Operating hours and patterns.
- **Environmental Data**: Temperature, humidity, and comfort metrics.
- **Maintenance Records**: Issues, status, scheduling, and resolutions.

## 🚀 System Requirements

### Technical Requirements

- Python 3.8+ with required dependencies.
- PostgreSQL Database with sensor data schema.
- MongoDB Atlas for logging and analytics.
- Ollama LLM Service (local or remote).
- Adequate storage for vector embeddings and logs.

### Configuration Needs

- Environment variables for database connections.
- API endpoints for real-time data access.
- Custom prompts for specialized query handling.
- Logging setup for monitoring and debugging.

## 💡 Best Practices for Queries

### For Accurate Results

- **Be Specific**: Include room names or time frames when possible.
- **Use Natural Language**: Keep sentences clear and concise.
- **Ask Direct Questions**: For precise numbers and specific data.
- **Request Analysis**: For trends, patterns, and recommendations.

### Query Examples by Category

#### ✅ Good Examples:

- "What's the current temperature in Conference Room A?"
- "Show me energy consumption trends for the past week."
- "How many maintenance requests were resolved?"

#### ❌ Avoid:

- "Tell me everything about the building." (Too vague)
- "What should I do about energy?" (Lacks specificity)
- Complex multi-part questions in a single query.

## 🔍 Limitations & Considerations

### Current Limitations

- Requires structured sensor data format.
- Limited to available historical data.
- Maintenance data depends on database integration.
- Real-time data relies on sensor update frequency.

### Data Availability

- **Room Information**: Dependent on room naming in the database.
- **Historical Trends**: Limited by data retention policies.
- **Maintenance Data**: Requires active maintenance system integration.
- **Real-time Updates**: Subject to sensor reporting intervals.

## 🎊 Getting Started

### Quick Start Queries

- "How many rooms do we have?" - Basic room inventory.
- "What's the current occupancy?" - Real-time usage.
- "Any maintenance issues?" - System health check.
- "Energy consumption summary." - Efficiency overview.
- "Weekly performance report." - Comprehensive analysis.

### Advanced Usage

- Combine multiple data points in single queries.
- Request trend analysis for specific time periods.
- Ask for optimization recommendations.
- Request comparative analysis between rooms or periods.

## 🎨 User Interface Features

### Modern Chat Interface

- **Clean Design**: Centered layout with optimized spacing for readability.
- **Smooth Animations**: Messages fade in with smooth transitions.
- **Auto-Scroll**: Automatically scrolls to new messages.
- **Responsive**: Adapts to desktop and mobile screens.

### Message Display

- **User Messages**: Blue gradient background, right-aligned.
- **AI Responses**: Dark background with blue accent border, left-aligned.
- **Formatted Content**: Supports bold text, emojis, and structured data.
- **Timestamps**: Shows when each message was sent.

### Input Controls

- **Centered Input Box**: Fixed at bottom, max-width 1400px.
- **Clear Button**: Appears when messages exist, removes all chat history.
- **Send Button**: Submits your query to ORB AI.
- **Loading States**: Visual feedback while processing.

## 🆕 Recent Enhancements

### Intelligent Query Routing

ORB AI now automatically detects query intent and routes to specialized endpoints:

- **Maintenance Queries**: "Check for maintenance" → Dedicated maintenance analysis
- **Report Queries**: "Daily/Monthly/Yearly report" → Period-specific energy reports
- **Billing Queries**: "Show billing rates" → Real-time rate information
- **Room Queries**: "Room utilization" → Comprehensive space analysis

### Enhanced KPI Dashboard

The new **Building Performance Dashboard** provides:

- **Energy Performance**: Total consumption, highest consumer, efficiency score, cost estimation
- **Space Utilization**: Utilization rate, peak occupancy, energy per person
- **Environmental Comfort**: Temperature range, comfort rate (20-24°C ideal), status indicators
- **System Health**: Overall efficiency score (0-100%), performance ratings
- **Smart Recommendations**: Context-aware suggestions based on actual performance

### Improved Reporting

- **Multi-Period Reports**: Daily, monthly, yearly energy summaries
- **Cost Analysis**: Automatic cost calculations in PHP
- **Top Consumers**: Identifies highest energy-consuming rooms
- **Trend Indicators**: Shows increases/decreases with percentages

### Better Maintenance Insights

- **User Attribution**: Shows who requested each maintenance item
- **Status Tracking**: Pending, in-progress, resolved with timestamps
- **AI + User Requests**: Combines predictive maintenance with actual user requests
- **Priority Levels**: Critical, high, medium, low urgency indicators

### Enhanced Room Utilization

- **Detailed Breakdown**: All rooms with event counts and percentages
- **Usage Levels**: Color-coded (🔴 High, 🟡 Medium, 🟢 Low)
- **Statistics**: Average events per room, utilization distribution
- **Recommendations**: Actionable suggestions for space optimization

### Billing Rate Display

- **Clean Format**: Organized by room with clear rate information
- **Time Windows**: Shows active hours for each rate
- **Validity Periods**: Displays when rates are effective
- **Summary Statistics**: Total rates, average, min/max ranges
- **Optimization Tips**: Suggestions for cost savings

## 📝 Response Format Examples

### Building Performance Dashboard

```
📊 **Building Performance Dashboard**

⚡ **Energy Performance:**
   • Total Consumption: **60.70 kWh**
   • Highest Consumer: **Conference Room A** (25.30 kWh)
   • Distribution Efficiency: **85.5%**
   • Estimated Cost: **₱728.40**

👥 **Space Utilization:**
   • Utilization Rate: **65.0%**
   • Peak Occupancy: **8 people**
   • Avg When Occupied: **3.5 people**
   • Energy per Person: **12.14 kWh**

🌡️ **Environmental Comfort:**
   • Average Temperature: **22.5°C**
   • Range: **20.0°C - 24.5°C**
   • Comfort Rate: **85.0%** (20-24°C)
   • Status: ✅ **Optimal**

📈 **System Health:**
   • Data Points Analyzed: **1,250**
   • Active Rooms: **5**
   • Overall Efficiency: **78.5%**
   • Rating: ✅ **Good**

💡 **Recommendations:**
   • ✅ All systems operating optimally
   • Continue monitoring for sustained performance
```

### Room Utilization Analysis

```
🏢 Room Utilization Analysis

📊 Total Rooms in System: 5
📈 Total Events Recorded: 2,730

📍 Most Utilized Room:
   Break Room D
   • Events: 1,234
   • Usage: 45.2% of total activity

📊 Overall Statistics:
   • Total Rooms: 5
   • Total Events: 2,730
   • Average Events/Room: 546.0

📈 Utilization Distribution:
   • 🔴 High Usage: 1 rooms
   • 🟡 Medium Usage: 3 rooms
   • 🟢 Low Usage: 1 rooms

🏠 Room Breakdown:
   1. 🔴 Break Room D
      Events: 1,234
      Share: 45.2%
   
   2. 🟡 Conference Room A
      Events: 856
      Share: 31.4%

💡 Recommendations:
   • Focus maintenance on high-usage room: Break Room D
   • Monitor usage patterns for optimization opportunities
```

**Note:** ORB AI is designed to provide both immediate factual answers and deeper analytical insights, making it an invaluable tool for facility management, energy optimization, and maintenance coordination in smart building environments.