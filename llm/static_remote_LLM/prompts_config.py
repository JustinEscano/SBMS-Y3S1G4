from typing import Dict, Any
import json
import os

class PromptsConfig:
    """
    Centralized configuration for all LLM prompts and templates
    """
    
    def __init__(self, config_file: str = None):
        """
        Initialize prompts configuration
        
        Args:
            config_file: Optional path to JSON config file for prompts
        """
        self.config_file = config_file
        self._prompts = self._load_default_prompts()
        
        # Load custom prompts from file if provided
        if config_file and os.path.exists(config_file):
            self._load_prompts_from_file()
    
    def _load_default_prompts(self) -> Dict[str, Any]:
        """Load default prompt templates"""
        return {
            # System prompts for LLM enhancement
            "system_prompts": {
                "base_enhancement": """
Based EXCLUSIVELY on the room energy consumption data provided, answer the following question.
If the information is not available in the data, say "I cannot find this information in the data."
Do not make up or assume any information.

Question: {query}

Important instructions:
1. Only use numbers and facts from the provided documents
2. If unsure, say you don't know
3. Be precise and factual
""",
                
                "detailed_enhancement": """
You are an expert energy consumption analyst. Based EXCLUSIVELY on the provided room sensor data, answer the following question with precision and accuracy.

STRICT GUIDELINES:
- Only use data from the provided documents
- If information is not available, explicitly state "This information is not available in the provided data"
- Provide specific timestamps, values, and measurements when available
- Do not extrapolate or make assumptions beyond the data
- Be concise but thorough in your analysis

Question: {query}

Analysis Requirements:
1. Use only factual data from the documents
2. Include relevant timestamps and measurements
3. Provide context when possible
4. State limitations if data is incomplete
""",
                
                "conversational_enhancement": """
You are a helpful assistant analyzing room energy consumption data. Please answer the following question based on the provided sensor data.

Guidelines:
- Use only the information from the provided documents
- Be conversational but accurate
- If you don't have the specific information, say so clearly
- Provide helpful context when possible

Question: {query}
"""
            },
            
            # Document creation templates
            "document_templates": {
                "standard": """At {timestamp}, the room was {occupancy_status} with {occupancy_count} people. Energy consumption: {energy_consumption_kwh} kWh. Lighting power: {lighting_power}W, HVAC power: {hvac_power}W, Air Conditioner Compressor: {ac_compressor_power}W, Projector power: {projector_power}W, Computer power: {computer_power}W, Standby power: {standby_power}W, Total power: {total_power}W. Lights usage: {lights_hours} hours, AC usage: {ac_hours} hours, Projector usage: {projector_hours} hours, Computers usage: {computer_hours} hours. Temperature: {temperature}°C, Humidity: {humidity}%.""",
                
                "detailed": """Room Status Report - {timestamp}
Occupancy: {occupancy_status} ({occupancy_count} people)
Energy Metrics:
  - Total Energy Consumption: {energy_consumption_kwh} kWh
  - Total Power Consumption: {total_power}W
Power Breakdown:
  - Lighting: {lighting_power}W
  - HVAC Fan: {hvac_power}W
  - AC Compressor: {ac_compressor_power}W
  - Projector: {projector_power}W
  - Computer: {computer_power}W
  - Standby/Misc: {standby_power}W
Equipment Usage:
  - Lights: {lights_hours} hours
  - Air Conditioner: {ac_hours} hours
  - Projector: {projector_hours} hours
  - Computers: {computer_hours} hours
Environmental Conditions:
  - Temperature: {temperature}°C
  - Humidity: {humidity}%""",
                
                "summary": """At {timestamp}: {occupancy_count} people, {energy_consumption_kwh} kWh consumed, {total_power}W total power, {temperature}°C, {humidity}% humidity."""
            },
            
            # Response templates for deterministic queries
            "response_templates": {
                "count_records": "There are {count} occupied room records in the dataset.",
                "count_people": "There are a total of {total_people} people across all occupied room records.",
                "all_readings": "The room logs contain {count} occupied readings: {timestamps}.",
                "power_breakdown": "At {timestamp}, the power consumption breakdown is: {breakdown}.",
                "min_max_single": "The {operation} {metric} is {value} at {timestamps}.",
                "min_max_combined": "The lowest {metric} is {min_value} at {min_timestamps}. The highest {metric} is {max_value} at {max_timestamps}.",
                "average": "The average {metric} is {value:.2f}.",
                "mixed_query": "{results}.",
                "no_data_error": "I cannot find this information in the data.",
                "data_unavailable": "This information is not available in the provided data."
            },
            
            # Query pattern matching
            "query_patterns": {
                "count_queries": [
                    "how many record",
                    "how many data",
                    "how many log",
                    "number of record",
                    "total record"
                ],
                "people_queries": [
                    "how many people",
                    "total people",
                    "number of people"
                ],
                "all_readings_queries": [
                    "all readings",
                    "all logs",
                    "all records",
                    "all room_logs",
                    "show all"
                ],
                "power_breakdown_queries": [
                    "power consumption breakdown",
                    "power breakdown",
                    "energy breakdown"
                ],
                "min_queries": [
                    "lowest",
                    "minimum",
                    "min "
                ],
                "max_queries": [
                    "highest",
                    "maximum",
                    "max "
                ],
                "average_queries": [
                    "average",
                    "mean",
                    "avg"
                ]
            },
            
            # Column mappings for queries
            "column_mappings": {
                "temperature": "environmental_data.temperature_celsius",
                "temp": "environmental_data.temperature_celsius",
                "energy": "energy_consumption_kwh",
                "power": "power_consumption_watts.total",
                "total": "power_consumption_watts.total",
                "humidity": "environmental_data.humidity_percent",
                "occupancy": "occupancy_count",
                "lighting": "power_consumption_watts.lighting",
                "light": "power_consumption_watts.lighting",
                "hvac": "power_consumption_watts.hvac_fan",
                "fan": "power_consumption_watts.hvac_fan",
                "ac": "power_consumption_watts.hvac_fan",
                "compressor": "power_consumption_watts.air_conditioner_compressor",
                "air conditioner": "power_consumption_watts.air_conditioner_compressor",
                "projector power": "power_consumption_watts.projector",
                "projector": "equipment_usage.projector_on_hours",
                "projectors": "equipment_usage.projector_on_hours",
                "computer": "power_consumption_watts.computer",
                "standby": "power_consumption_watts.standby_misc",
                "misc": "power_consumption_watts.standby_misc"
            },
            
            # Operation mappings
            "operation_mappings": {
                "highest": "max",
                "maximum": "max",
                "max": "max",
                "lowest": "min",
                "minimum": "min",
                "min": "min",
                "average": "mean",
                "mean": "mean",
                "avg": "mean"
            },
            
            # Validation settings
            "validation": {
                "max_reasonable_power": 10000,  # Watts
                "max_reasonable_energy": 1000,  # kWh
                "max_reasonable_temperature": 50,  # Celsius
                "min_reasonable_temperature": -10,  # Celsius
                "max_reasonable_humidity": 100,  # Percent
                "min_reasonable_humidity": 0  # Percent
            },
            
            # Logging settings
            "logging": {
                "model_name": "incept5/llama3.1-claude:latest",
                "retrieval_method": "vector_store",
                "log_sources": True,
                "log_errors": True
            }
        }
    
    def _load_prompts_from_file(self):
        """Load prompts from external JSON file"""
        try:
            with open(self.config_file, 'r', encoding='utf-8') as f:
                custom_prompts = json.load(f)
                # Merge custom prompts with defaults
                self._merge_prompts(custom_prompts)
        except Exception as e:
            print(f"Warning: Could not load prompts from {self.config_file}: {e}")
    
    def _merge_prompts(self, custom_prompts: Dict[str, Any]):
        """Merge custom prompts with default prompts"""
        for category, prompts in custom_prompts.items():
            if category in self._prompts:
                if isinstance(self._prompts[category], dict) and isinstance(prompts, dict):
                    self._prompts[category].update(prompts)
                else:
                    self._prompts[category] = prompts
            else:
                self._prompts[category] = prompts
    
    def get_system_prompt(self, prompt_type: str = "base_enhancement") -> str:
        """Get system prompt for LLM enhancement"""
        return self._prompts["system_prompts"].get(prompt_type, 
                                                  self._prompts["system_prompts"]["base_enhancement"])
    
    def get_document_template(self, template_type: str = "standard") -> str:
        """Get document creation template"""
        return self._prompts["document_templates"].get(template_type,
                                                      self._prompts["document_templates"]["standard"])
    
    def get_response_template(self, template_name: str) -> str:
        """Get response template for deterministic queries"""
        return self._prompts["response_templates"].get(template_name, "")
    
    def get_query_patterns(self, pattern_type: str) -> list:
        """Get query patterns for matching"""
        return self._prompts["query_patterns"].get(pattern_type, [])
    
    def get_column_mapping(self, column_key: str) -> str:
        """Get column mapping for queries"""
        return self._prompts["column_mappings"].get(column_key, "")
    
    def get_operation_mapping(self, operation_key: str) -> str:
        """Get operation mapping"""
        return self._prompts["operation_mappings"].get(operation_key, "")
    
    def get_validation_setting(self, setting_name: str) -> Any:
        """Get validation setting"""
        return self._prompts["validation"].get(setting_name)
    
    def get_logging_setting(self, setting_name: str) -> Any:
        """Get logging setting"""
        return self._prompts["logging"].get(setting_name)
    
    def update_prompt(self, category: str, key: str, value: str):
        """Update a specific prompt"""
        if category not in self._prompts:
            self._prompts[category] = {}
        self._prompts[category][key] = value
    
    def save_prompts_to_file(self, file_path: str = None):
        """Save current prompts to JSON file"""
        if file_path is None:
            file_path = self.config_file or "prompts_config.json"
        
        try:
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(self._prompts, f, indent=2, ensure_ascii=False)
            print(f"Prompts saved to {file_path}")
        except Exception as e:
            print(f"Error saving prompts to {file_path}: {e}")
    
    def get_all_prompts(self) -> Dict[str, Any]:
        """Get all prompts configuration"""
        return self._prompts.copy()
    
    def reset_to_defaults(self):
        """Reset all prompts to default values"""
        self._prompts = self._load_default_prompts()


# Global instance for easy access
default_prompts = PromptsConfig()


# Convenience functions for common operations
def get_system_prompt(prompt_type: str = "base_enhancement") -> str:
    """Get system prompt for LLM enhancement"""
    return default_prompts.get_system_prompt(prompt_type)

def get_document_template(template_type: str = "standard") -> str:
    """Get document creation template"""
    return default_prompts.get_document_template(template_type)

def get_response_template(template_name: str) -> str:
    """Get response template"""
    return default_prompts.get_response_template(template_name)

def enhance_query_with_prompt(query: str, prompt_type: str = "base_enhancement") -> str:
    """Enhance a query with system prompt"""
    system_prompt = get_system_prompt(prompt_type)
    return system_prompt.format(query=query)