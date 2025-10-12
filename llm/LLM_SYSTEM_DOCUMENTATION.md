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

- **Key Performance Indicators (KPIs)**: Comprehensive metrics for building performance.
- **Weekly Summaries**: Consolidated reports on weekly performance.
- **Trend Analysis**: Identify energy and usage patterns.
- **Anomaly Detection**: Detect unusual patterns and potential issues.

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
- "Monthly energy consumption summary."
- "Quarterly maintenance report."

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

**Note:** ORB AI is designed to provide both immediate factual answers and deeper analytical insights, making it an invaluable tool for facility management, energy optimization, and maintenance coordination in smart building environments.