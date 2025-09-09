# LLM Prompts Configuration System

This system allows you to easily customize and manage all prompts and templates used by your LLM system without modifying the core code.

## 📁 Files Overview

- **`prompts_config.py`** - Core prompts configuration system
- **`custom_prompts.json`** - Your customizable prompts file
- **`prompt_manager.py`** - Utility for managing and testing prompts
- **`main.py`** - Updated to use the prompts system

## 🚀 Quick Start

### 1. View Available Prompts

```bash
python prompt_manager.py --list
```

### 2. Test Different Prompt Types

```bash
# Test with friendly prompt
python prompt_manager.py --test friendly_enhancement standard "What is the average temperature?"

# Test with detailed prompt
python prompt_manager.py --test detailed_enhancement standard "Show me power consumption data"
```

### 3. Compare Prompt Types

```bash
python prompt_manager.py --compare base_enhancement detailed_enhancement friendly_enhancement
```

## 📝 Prompt Types

### System Prompts (for LLM enhancement)

- **`base_enhancement`** - Standard factual prompt
- **`detailed_enhancement`** - Detailed analytical prompt
- **`friendly_enhancement`** - Conversational friendly prompt

### Document Templates

- **`standard`** - Complete detailed format
- **`concise`** - Shortened format for efficiency

## 🛠️ Customizing Prompts

### Method 1: Edit JSON File

Edit `custom_prompts.json` directly:

```json
{
  "system_prompts": {
    "my_custom_prompt": "You are a helpful energy analyst. Answer based on the data provided.\n\nQuestion: {query}\n\nBe precise and helpful."
  }
}
```

### Method 2: Use Interactive Editor

```bash
python prompt_manager.py --interactive
```

### Method 3: Programmatically

```python
from prompts_config import PromptsConfig

prompts = PromptsConfig("custom_prompts.json")
prompts.update_prompt("system_prompts", "my_prompt", "Custom prompt text here")
prompts.save_prompts_to_file()
```

## 🧪 Testing Your Prompts

### Test a Single Configuration

```bash
python prompt_manager.py --test my_custom_prompt standard "How many people were detected?"
```

### Compare Multiple Prompts

```bash
python prompt_manager.py --compare base_enhancement my_custom_prompt
```

## 🔧 Using Custom Prompts in Your Application

### Option 1: Initialize with Custom Prompts

```python
from main import RoomLogAnalyzer

analyzer = RoomLogAnalyzer(
    prompt_type="friendly_enhancement",
    document_template="concise",
    prompts_config_file="custom_prompts.json"
)
```

### Option 2: Environment Variables

Set these in your `.env` file:
```
LLM_PROMPT_TYPE=detailed_enhancement
LLM_DOCUMENT_TEMPLATE=standard
LLM_PROMPTS_CONFIG=custom_prompts.json
```

## 📋 Available Template Variables

### Document Templates

When creating document templates, you can use these variables:

- `{timestamp}` - Formatted timestamp
- `{occupancy_status}` - occupied/unoccupied
- `{occupancy_count}` - Number of people
- `{energy_consumption_kwh}` - Energy consumption
- `{lighting_power}` - Lighting power consumption
- `{hvac_power}` - HVAC power consumption
- `{ac_compressor_power}` - AC compressor power
- `{projector_power}` - Projector power
- `{computer_power}` - Computer power
- `{standby_power}` - Standby power
- `{total_power}` - Total power consumption
- `{lights_hours}` - Lights usage hours
- `{ac_hours}` - AC usage hours
- `{projector_hours}` - Projector usage hours
- `{computer_hours}` - Computer usage hours
- `{temperature}` - Temperature in Celsius
- `{humidity}` - Humidity percentage

### System Prompts

- `{query}` - The user's question

## 🎯 Best Practices

### 1. Prompt Design

- **Be specific** about what the LLM should and shouldn't do
- **Include examples** when possible
- **Set clear boundaries** (e.g., "only use provided data")
- **Define the tone** (formal, friendly, technical)

### 2. Testing

- Test with various query types
- Compare different prompt versions
- Monitor response quality and accuracy
- Test edge cases and error scenarios

### 3. Template Design

- Keep templates consistent
- Include all necessary information
- Consider readability vs. completeness
- Test with different data scenarios

## 📊 Example Custom Prompts

### Technical Analyst Prompt

```json
{
  "system_prompts": {
    "technical_analyst": "You are a technical energy systems analyst. Provide detailed, data-driven responses based exclusively on the sensor data provided.\n\nAnalysis Guidelines:\n- Include specific measurements and timestamps\n- Identify patterns and anomalies\n- Provide technical insights\n- State data limitations clearly\n\nQuery: {query}\n\nProvide a comprehensive technical analysis."
  }
}
```

### Executive Summary Prompt

```json
{
  "system_prompts": {
    "executive_summary": "You are preparing executive summaries of energy data. Provide concise, business-focused insights.\n\nGuidelines:\n- Focus on key metrics and trends\n- Highlight cost/efficiency implications\n- Use business-friendly language\n- Be concise but informative\n\nQuestion: {query}\n\nProvide an executive summary."
  }
}
```

### Minimal Document Template

```json
{
  "document_templates": {
    "minimal": "{timestamp}: {occupancy_count} people, {total_power}W, {temperature}°C"
  }
}
```

## 🔍 Troubleshooting

### Common Issues

1. **Template formatting errors**: Check that all `{variables}` are spelled correctly
2. **JSON syntax errors**: Validate your JSON file
3. **Missing prompts**: Ensure prompt names match exactly
4. **Performance issues**: Consider using shorter templates for large datasets

### Debug Mode

Enable debug logging to see which prompts are being used:

```python
import logging
logging.basicConfig(level=logging.DEBUG)
```

## 🚀 Advanced Usage

### Dynamic Prompt Selection

```python
def get_prompt_for_query(query):
    if "technical" in query.lower():
        return "technical_analyst"
    elif "summary" in query.lower():
        return "executive_summary"
    else:
        return "base_enhancement"

analyzer = RoomLogAnalyzer(prompt_type=get_prompt_for_query(user_query))
```

### A/B Testing Prompts

```python
import random

prompt_types = ["base_enhancement", "detailed_enhancement"]
selected_prompt = random.choice(prompt_types)

analyzer = RoomLogAnalyzer(prompt_type=selected_prompt)
# Log the prompt type used for analysis
```

## 📈 Monitoring and Analytics

Track prompt performance by:

1. Logging which prompts are used
2. Measuring response quality
3. Monitoring user satisfaction
4. A/B testing different versions

The system automatically logs prompt usage to MongoDB when configured, making it easy to analyze which prompts work best for different types of queries.