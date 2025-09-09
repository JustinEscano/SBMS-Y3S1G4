#!/usr/bin/env python3
"""
Prompt Manager Utility
Easy management and testing of LLM prompts and templates
"""

import os
import sys
import json
import logging
from datetime import datetime

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from prompts_config import PromptsConfig
from main import RoomLogAnalyzer

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

class PromptManager:
    """
    Utility class for managing and testing LLM prompts
    """
    
    def __init__(self, config_file="custom_prompts.json"):
        self.config_file = config_file
        self.prompts = PromptsConfig(config_file if os.path.exists(config_file) else None)
    
    def list_available_prompts(self):
        """List all available prompt types and templates"""
        print("=" * 60)
        print("AVAILABLE PROMPTS AND TEMPLATES")
        print("=" * 60)
        
        all_prompts = self.prompts.get_all_prompts()
        
        print("\n📝 SYSTEM PROMPTS:")
        for prompt_type in all_prompts.get("system_prompts", {}):
            print(f"  - {prompt_type}")
        
        print("\n📄 DOCUMENT TEMPLATES:")
        for template_type in all_prompts.get("document_templates", {}):
            print(f"  - {template_type}")
        
        print("\n💬 RESPONSE TEMPLATES:")
        for template_name in all_prompts.get("response_templates", {}):
            print(f"  - {template_name}")
    
    def show_prompt(self, category, prompt_name):
        """Show a specific prompt or template"""
        all_prompts = self.prompts.get_all_prompts()
        
        if category not in all_prompts:
            print(f"❌ Category '{category}' not found")
            return
        
        if prompt_name not in all_prompts[category]:
            print(f"❌ Prompt '{prompt_name}' not found in category '{category}'")
            return
        
        print(f"\n📝 {category.upper()} - {prompt_name}")
        print("=" * 60)
        print(all_prompts[category][prompt_name])
        print("=" * 60)
    
    def create_custom_prompt(self, category, prompt_name, content):
        """Create or update a custom prompt"""
        self.prompts.update_prompt(category, prompt_name, content)
        print(f"✅ Updated {category}.{prompt_name}")
    
    def save_prompts(self):
        """Save current prompts to file"""
        self.prompts.save_prompts_to_file(self.config_file)
        print(f"✅ Prompts saved to {self.config_file}")
    
    def test_prompt_with_analyzer(self, prompt_type="base_enhancement", 
                                 document_template="standard", test_query="How many records are there?"):
        """Test a prompt configuration with the analyzer"""
        print(f"\n🧪 TESTING PROMPT CONFIGURATION")
        print(f"Prompt Type: {prompt_type}")
        print(f"Document Template: {document_template}")
        print(f"Test Query: {test_query}")
        print("=" * 60)
        
        try:
            # Create analyzer with specific prompt configuration
            analyzer = RoomLogAnalyzer(
                use_database=True,
                prompt_type=prompt_type,
                document_template=document_template,
                prompts_config_file=self.config_file
            )
            
            # Load data and initialize
            df = analyzer.load_and_process_data(limit=5)  # Small sample for testing
            documents = analyzer.create_documents(df)
            analyzer.initialize_vector_store(documents)
            analyzer.initialize_qa_chain()
            
            # Test the query
            result = analyzer.ask(test_query)
            
            print("📤 QUERY:")
            print(f"  {test_query}")
            print("\n📥 RESPONSE:")
            if "error" in result:
                print(f"  ❌ Error: {result['error']}")
            else:
                print(f"  ✅ Answer: {result.get('answer', 'No answer')}")
                if result.get('sources'):
                    print(f"  📚 Sources: {len(result['sources'])} documents")
            
            print("\n🔍 SAMPLE DOCUMENT (using current template):")
            if documents:
                print(f"  {documents[0].page_content[:200]}...")
            
        except Exception as e:
            print(f"❌ Test failed: {e}")
    
    def compare_prompts(self, prompt_types, test_query="What is the average temperature?"):
        """Compare different prompt types with the same query"""
        print(f"\n🔄 COMPARING PROMPT TYPES")
        print(f"Test Query: {test_query}")
        print("=" * 60)
        
        for prompt_type in prompt_types:
            print(f"\n📝 Testing: {prompt_type}")
            print("-" * 40)
            
            try:
                # Show the prompt being used
                prompt_text = self.prompts.get_system_prompt(prompt_type)
                print(f"Prompt Preview: {prompt_text[:100]}...")
                
                # Test with analyzer (simplified for comparison)
                self.test_prompt_with_analyzer(prompt_type, "standard", test_query)
                
            except Exception as e:
                print(f"❌ Failed to test {prompt_type}: {e}")
    
    def interactive_prompt_editor(self):
        """Interactive prompt editing session"""
        print("\n🎛️  INTERACTIVE PROMPT EDITOR")
        print("=" * 60)
        
        while True:
            print("\nOptions:")
            print("1. List all prompts")
            print("2. Show specific prompt")
            print("3. Edit prompt")
            print("4. Test prompt")
            print("5. Save prompts")
            print("6. Exit")
            
            choice = input("\nEnter your choice (1-6): ").strip()
            
            if choice == "1":
                self.list_available_prompts()
            
            elif choice == "2":
                category = input("Enter category (system_prompts/document_templates/response_templates): ").strip()
                prompt_name = input("Enter prompt name: ").strip()
                self.show_prompt(category, prompt_name)
            
            elif choice == "3":
                category = input("Enter category: ").strip()
                prompt_name = input("Enter prompt name: ").strip()
                print("Enter prompt content (press Ctrl+D when done):")
                content_lines = []
                try:
                    while True:
                        line = input()
                        content_lines.append(line)
                except EOFError:
                    content = "\n".join(content_lines)
                    self.create_custom_prompt(category, prompt_name, content)
            
            elif choice == "4":
                prompt_type = input("Enter prompt type (default: base_enhancement): ").strip() or "base_enhancement"
                template = input("Enter document template (default: standard): ").strip() or "standard"
                query = input("Enter test query (default: How many records?): ").strip() or "How many records are there?"
                self.test_prompt_with_analyzer(prompt_type, template, query)
            
            elif choice == "5":
                self.save_prompts()
            
            elif choice == "6":
                print("👋 Goodbye!")
                break
            
            else:
                print("❌ Invalid choice. Please try again.")

def main():
    """Main function for command-line usage"""
    import argparse
    
    parser = argparse.ArgumentParser(description="LLM Prompt Manager")
    parser.add_argument("--config", default="custom_prompts.json", help="Prompts configuration file")
    parser.add_argument("--list", action="store_true", help="List all available prompts")
    parser.add_argument("--show", nargs=2, metavar=("CATEGORY", "NAME"), help="Show specific prompt")
    parser.add_argument("--test", nargs="*", help="Test prompt configuration [prompt_type] [template] [query]")
    parser.add_argument("--compare", nargs="+", help="Compare multiple prompt types")
    parser.add_argument("--interactive", action="store_true", help="Start interactive editor")
    
    args = parser.parse_args()
    
    manager = PromptManager(args.config)
    
    if args.list:
        manager.list_available_prompts()
    
    elif args.show:
        manager.show_prompt(args.show[0], args.show[1])
    
    elif args.test is not None:
        prompt_type = args.test[0] if len(args.test) > 0 else "base_enhancement"
        template = args.test[1] if len(args.test) > 1 else "standard"
        query = args.test[2] if len(args.test) > 2 else "How many records are there?"
        manager.test_prompt_with_analyzer(prompt_type, template, query)
    
    elif args.compare:
        manager.compare_prompts(args.compare)
    
    elif args.interactive:
        manager.interactive_prompt_editor()
    
    else:
        print("LLM Prompt Manager")
        print("Use --help for available options")
        manager.list_available_prompts()

if __name__ == "__main__":
    main()