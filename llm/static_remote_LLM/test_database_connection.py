#!/usr/bin/env python3
"""
Test script to verify database connection and LLM integration
"""

import sys
import os

# Add current directory to path
sys.path.append(os.path.dirname(__file__))

from database_adapter import DatabaseAdapter
from main import ask, initialize_analyzer

def test_database_connection():
    """Test the database connection"""
    print("=== Testing Database Connection ===")
    
    try:
        # Test database adapter
        db_adapter = DatabaseAdapter()
        print("✓ Database adapter initialized successfully")
        
        # Test getting sensor data
        df = db_adapter.get_sensor_data_as_dataframe(limit=10)
        print(f"✓ Retrieved {len(df)} sensor records from database")
        
        if not df.empty:
            print("Sample data columns:", list(df.columns))
            print("Sample record:")
            print(df.iloc[0].to_dict())
        
        # Test getting equipment list
        equipment = db_adapter.get_equipment_list()
        print(f"✓ Retrieved {len(equipment)} equipment records")
        
        # Test getting rooms list
        rooms = db_adapter.get_rooms_list()
        print(f"✓ Retrieved {len(rooms)} room records")
        
        # Test getting latest sensor readings
        readings = db_adapter.get_latest_sensor_readings(limit=5)
        print(f"✓ Retrieved {len(readings)} latest sensor readings")
        
        db_adapter.close_connection()
        print("✓ Database connection closed successfully")
        
        return True
        
    except Exception as e:
        print(f"✗ Database connection failed: {e}")
        return False

def test_llm_integration():
    """Test the LLM integration with database"""
    print("\n=== Testing LLM Integration ===")
    
    try:
        # Initialize the analyzer
        print("Initializing LLM analyzer...")
        success = initialize_analyzer(reset_vector_store=False)
        
        if not success:
            print("✗ Failed to initialize LLM analyzer")
            return False
        
        print("✓ LLM analyzer initialized successfully")
        
        # Test a simple query
        print("\nTesting query: 'How many records are there?'")
        result = ask("How many records are there?")
        
        if "error" in result:
            print(f"✗ Query failed: {result['error']}")
            return False
        
        print(f"✓ Query successful: {result['answer']}")
        
        # Test another query
        print("\nTesting query: 'What is the average temperature?'")
        result = ask("What is the average temperature?")
        
        if "error" in result:
            print(f"✗ Query failed: {result['error']}")
            return False
        
        print(f"✓ Query successful: {result['answer']}")
        
        return True
        
    except Exception as e:
        print(f"✗ LLM integration failed: {e}")
        return False

def main():
    """Main test function"""
    print("Smart Building Management System - Database Integration Test")
    print("=" * 60)
    
    # Test database connection
    db_success = test_database_connection()
    
    if db_success:
        # Test LLM integration
        llm_success = test_llm_integration()
        
        if llm_success:
            print("\n" + "=" * 60)
            print("🎉 All tests passed! Your LLM is now connected to PostgreSQL!")
            print("=" * 60)
            print("\nYou can now:")
            print("1. Ask questions about your sensor data")
            print("2. Query equipment and room information")
            print("3. Get insights from your building management data")
            print("\nExample queries to try:")
            print("- 'What is the highest temperature recorded?'")
            print("- 'Show me the average energy consumption'")
            print("- 'How many rooms have motion detected?'")
        else:
            print("\n" + "=" * 60)
            print("⚠️  Database connection works, but LLM integration failed")
            print("Check your Ollama installation and model availability")
    else:
        print("\n" + "=" * 60)
        print("❌ Database connection failed")
        print("Please check your PostgreSQL connection settings")

if __name__ == "__main__":
    main()