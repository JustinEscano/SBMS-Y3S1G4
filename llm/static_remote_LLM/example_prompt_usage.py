#!/usr/bin/env python3
"""
Example: Using Different Prompts with the LLM System
This script demonstrates how to use different prompt configurations
"""

import os
import sys
import logging

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import RoomLogAnalyzer
from prompts_config import PromptsConfig

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def demonstrate_different_prompts():
    """Demonstrate using different prompt types"""
    
    # Test query
    test_query = "What is the average temperature in the room?"
    
    # Different prompt configurations to test
    configurations = [
        {
            "name": "Standard Business",
            "prompt_type": "base_enhancement",
            "document_template": "standard"
        },
        {
            "name": "Detailed Analysis", 
            "prompt_type": "detailed_enhancement",
            "document_template": "detailed"
        },
        {
            "name": "Friendly Assistant",
            "prompt_type": "friendly_enhancement", 
            "document_template": "concise"
        }
    ]
    
    print("=" * 80)
    print("DEMONSTRATING DIFFERENT PROMPT CONFIGURATIONS")
    print("=" * 80)
    print(f"Test Query: {test_query}")
    print()
    
    for config in configurations:
        print(f"🔧 Configuration: {config['name']}")
        print(f"   Prompt Type: {config['prompt_type']}")
        print(f"   Document Template: {config['document_template']}")
        print("-" * 60)
        
        try:
            # Create analyzer with specific configuration
            analyzer = RoomLogAnalyzer(
                use_database=True,
                prompt_type=config['prompt_type'],
                document_template=config['document_template'],
                prompts_config_file="custom_prompts.json"
            )
            
            # Initialize the system (this would normally be done once)
            df = analyzer.load_and_process_data(limit=5)
            documents = analyzer.create_documents(df)
            analyzer.initialize_vector_store(documents)
            analyzer.initialize_qa_chain()
            
            # Show the system prompt being used
            prompts = PromptsConfig("custom_prompts.json")
            system_prompt = prompts.get_system_prompt(config['prompt_type'])
            print(f"📝 System Prompt Preview:")
            print(f"   {system_prompt[:100]}...")
            print()
            
            # Show document template being used
            doc_template = prompts.get_document_template(config['document_template'])
            print(f"📄 Document Template Preview:")
            print(f"   {doc_template[:100]}...")
            print()
            
            # Test the query
            result = analyzer.ask(test_query)
            
            print(f"📤 Query: {test_query}")
            print(f"📥 Response:")
            if "error" in result:
                print(f"   ❌ Error: {result['error']}")
            else:
                print(f"   ✅ {result.get('answer', 'No answer')}")
            
            print()
            
        except Exception as e:
            print(f"❌ Error with {config['name']}: {e}")
            print()
        
        print("=" * 80)

def create_custom_prompt_example():
    """Example of creating and using a custom prompt"""
    
    print("\n🎨 CREATING CUSTOM PROMPT EXAMPLE")
    print("=" * 60)
    
    # Load prompts configuration
    prompts = PromptsConfig("custom_prompts.json")
    
    # Create a custom prompt for energy efficiency analysis
    custom_prompt = """You are an energy efficiency consultant analyzing room sensor data.

Your task: Provide energy efficiency insights based EXCLUSIVELY on the provided room data.

Guidelines:
- Focus on energy consumption patterns and efficiency opportunities
- Identify potential energy savings
- Suggest optimization strategies when relevant
- Only use data from the provided documents
- If data is insufficient, clearly state limitations

Question: {query}

Provide your energy efficiency analysis:"""
    
    # Add the custom prompt
    prompts.update_prompt("system_prompts", "energy_efficiency", custom_prompt)
    
    # Create a custom document template for efficiency analysis
    efficiency_template = """Energy Data Point - {timestamp}
Occupancy: {occupancy_count} people ({occupancy_status})
Power Usage: {total_power}W (Lighting: {lighting_power}W, HVAC: {hvac_power}W, Other: {standby_power}W)
Energy Consumed: {energy_consumption_kwh} kWh
Environmental: {temperature}°C, {humidity}% humidity
Equipment Runtime: Lights {lights_hours}h, AC {ac_hours}h"""
    
    prompts.update_prompt("document_templates", "efficiency_focused", efficiency_template)
    
    # Save the custom prompts
    prompts.save_prompts_to_file("custom_prompts.json")
    
    print("✅ Created custom 'energy_efficiency' prompt")
    print("✅ Created custom 'efficiency_focused' document template")
    print("✅ Saved to custom_prompts.json")
    
    # Test the custom prompt
    print("\n🧪 Testing Custom Prompt...")
    try:
        analyzer = RoomLogAnalyzer(
            use_database=True,
            prompt_type="energy_efficiency",
            document_template="efficiency_focused",
            prompts_config_file="custom_prompts.json"
        )
        
        # Initialize (simplified for demo)
        df = analyzer.load_and_process_data(limit=3)
        documents = analyzer.create_documents(df)
        analyzer.initialize_vector_store(documents)
        analyzer.initialize_qa_chain()
        
        # Test query
        test_query = "What energy efficiency improvements can you suggest?"
        result = analyzer.ask(test_query)
        
        print(f"📤 Query: {test_query}")
        print(f"📥 Custom Prompt Response:")
        if "error" in result:
            print(f"   ❌ Error: {result['error']}")
        else:
            print(f"   ✅ {result.get('answer', 'No answer')}")
        
    except Exception as e:
        print(f"❌ Error testing custom prompt: {e}")

def show_prompt_management_examples():
    """Show examples of prompt management operations"""
    
    print("\n🛠️  PROMPT MANAGEMENT EXAMPLES")
    print("=" * 60)
    
    prompts = PromptsConfig("custom_prompts.json")
    
    # Example 1: Get all available prompts
    print("📋 Available System Prompts:")
    all_prompts = prompts.get_all_prompts()
    for prompt_name in all_prompts.get("system_prompts", {}):
        print(f"   - {prompt_name}")
    
    # Example 2: Show a specific prompt
    print(f"\n📝 Example Prompt Content:")
    friendly_prompt = prompts.get_system_prompt("friendly_enhancement")
    print(f"   {friendly_prompt[:150]}...")
    
    # Example 3: Show template variables
    print(f"\n📄 Document Template Variables Available:")
    template_vars = [
        "timestamp", "occupancy_status", "occupancy_count", 
        "energy_consumption_kwh", "total_power", "temperature", "humidity"
    ]
    for var in template_vars:
        print(f"   - {{{var}}}")
    
    print(f"\n💡 Tip: Use prompt_manager.py for interactive editing!")

def main():
    """Main demonstration function"""
    print("🚀 LLM PROMPTS SYSTEM DEMONSTRATION")
    print("=" * 80)
    
    try:
        # Demonstrate different prompt configurations
        demonstrate_different_prompts()
        
        # Show custom prompt creation
        create_custom_prompt_example()
        
        # Show prompt management examples
        show_prompt_management_examples()
        
        print("\n🎉 DEMONSTRATION COMPLETE!")
        print("\nNext steps:")
        print("1. Edit custom_prompts.json to customize prompts")
        print("2. Use prompt_manager.py for interactive management")
        print("3. Test different configurations with your queries")
        print("4. Monitor performance and iterate on prompts")
        
    except Exception as e:
        print(f"❌ Demonstration failed: {e}")
        print("Make sure your database is running and accessible")

if __name__ == "__main__":
    main()