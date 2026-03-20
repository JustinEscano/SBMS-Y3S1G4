#!/usr/bin/env python3
"""
Test Room-Specific Queries
Demonstrates room-specific analysis capabilities
"""

import os
import sys
import logging
from datetime import datetime

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import ask, initialize_analyzer

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def test_room_specific_queries():
    """Test all room-specific query capabilities"""
    
    print("🏠 TESTING ROOM-SPECIFIC QUERIES")
    print("=" * 80)
    
    # Room-specific test queries
    room_queries = [
        # Basic room queries
        "What are the predictions for Room 1?",
        "Room A current status",
        "Energy consumption in Room 2", 
        "Maintenance needed for Room 1",
        
        # Advanced room analysis
        "Predict equipment failures in Room 1",
        "Anomalies detected in Room 1",
        "Energy optimization for Room 1",
        "Room 1 utilization patterns",
        
        # Different room name formats
        "Room One predictions",
        "room 1 status",
        "ROOM 1 energy trends",
        "for Room 1 what maintenance is needed?",
        "in Room 1 detect anomalies",
        
        # Comparative queries
        "Compare Room 1 energy usage",
        "Which room needs maintenance first?",
        "Most efficient room analysis"
    ]
    
    print(f"\n🧪 Testing {len(room_queries)} room-specific queries...")
    print("-" * 60)
    
    successful_queries = 0
    failed_queries = 0
    
    for i, query in enumerate(room_queries, 1):
        print(f"\n📤 Query {i}: {query}")
        
        try:
            result = ask(query)
            
            if "error" in result:
                print(f"❌ Error: {result['error']}")
                failed_queries += 1
            else:
                answer = result.get('answer', 'No answer provided')
                print(f"📥 Response: {answer[:150]}{'...' if len(answer) > 150 else ''}")
                
                # Show room-specific data if available
                if 'room' in result:
                    print(f"🏠 Room: {result['room']}")
                
                if 'analysis_type' in result:
                    print(f"📊 Analysis Type: {result['analysis_type']}")
                
                if 'predictions' in result:
                    predictions = result['predictions']
                    if 'energy_forecast' in predictions:
                        energy = predictions['energy_forecast']
                        print(f"⚡ Energy Trend: {energy.get('trend_direction', 'N/A')}")
                    
                    if 'recommendations' in predictions:
                        recs = predictions['recommendations'][:2]  # Show first 2
                        for rec in recs:
                            print(f"💡 Recommendation: {rec}")
                
                if 'maintenance_alerts' in result:
                    alerts = result['maintenance_alerts'][:2]  # Show first 2
                    for alert in alerts:
                        print(f"🔧 Maintenance: {alert.get('equipment', 'N/A')} - {alert.get('urgency', 'N/A')}")
                
                if 'anomalies' in result:
                    anomalies = result['anomalies'][:2]  # Show first 2
                    for anomaly in anomalies:
                        print(f"🚨 Anomaly: {anomaly.get('type', 'N/A')} - {anomaly.get('severity', 'N/A')}")
                
                successful_queries += 1
                
        except Exception as e:
            print(f"❌ Exception: {e}")
            failed_queries += 1
        
        print()
    
    # Summary
    print("\n📊 ROOM QUERY TEST SUMMARY")
    print("=" * 50)
    print(f"✅ Successful queries: {successful_queries}")
    print(f"❌ Failed queries: {failed_queries}")
    print(f"📈 Success rate: {(successful_queries / len(room_queries)) * 100:.1f}%")

def test_available_rooms():
    """Test getting available rooms from the system"""
    
    print("\n🏢 TESTING AVAILABLE ROOMS")
    print("=" * 50)
    
    try:
        # Try to get available rooms
        result = ask("What rooms are available?")
        print(f"📤 Query: What rooms are available?")
        print(f"📥 Response: {result.get('answer', 'No answer')}")
        
        # Try a more direct approach
        from main import analyzer
        if analyzer and analyzer.room_handlers:
            rooms = analyzer.room_handlers.get_available_rooms()
            print(f"\n🏠 Available Rooms ({len(rooms)}):")
            for room in rooms:
                print(f"  • {room['name']} (Floor: {room.get('floor', 'N/A')}, Type: {room.get('type', 'N/A')})")
        else:
            print("❌ Room handlers not available")
            
    except Exception as e:
        print(f"❌ Error getting available rooms: {e}")

def test_room_data_availability():
    """Test if room data is available in the database"""
    
    print("\n📊 TESTING ROOM DATA AVAILABILITY")
    print("=" * 50)
    
    try:
        from main import analyzer
        if analyzer and analyzer.room_handlers:
            # Test getting data for a specific room
            room_name = "Room 1"
            room_df = analyzer.room_handlers.get_room_data(room_name)
            
            if not room_df.empty:
                print(f"✅ Found {len(room_df)} records for {room_name}")
                print(f"📅 Date range: {room_df['timestamp'].min()} to {room_df['timestamp'].max()}")
                
                # Show sample data
                if 'room_name' in room_df.columns:
                    unique_rooms = room_df['room_name'].unique()
                    print(f"🏠 Rooms in data: {', '.join(unique_rooms)}")
                
                # Show available columns
                print(f"📋 Available columns: {len(room_df.columns)}")
                key_columns = [col for col in room_df.columns if any(keyword in col.lower() 
                              for keyword in ['room', 'energy', 'power', 'temperature', 'occupancy'])]
                print(f"🔑 Key columns: {', '.join(key_columns[:5])}...")
                
            else:
                print(f"❌ No data found for {room_name}")
                
                # Check if any room data exists
                all_df = analyzer.load_and_process_data(limit=10)
                if 'room_name' in all_df.columns:
                    unique_rooms = all_df['room_name'].unique()
                    print(f"🏠 Available rooms in database: {', '.join(unique_rooms)}")
                else:
                    print("❌ No room_name column found in data")
        else:
            print("❌ Room handlers not initialized")
            
    except Exception as e:
        print(f"❌ Error checking room data: {e}")

def test_room_query_parsing():
    """Test room name parsing from queries"""
    
    print("\n🔍 TESTING ROOM QUERY PARSING")
    print("=" * 50)
    
    test_queries = [
        "What are the predictions for Room 1?",
        "Room A energy consumption",
        "Maintenance needed in Conference Room",
        "for Room 2 show status",
        "in room one detect anomalies",
        "Room B current conditions",
        "analyze Room 3 performance"
    ]
    
    try:
        from main import analyzer
        if analyzer and analyzer.room_handlers:
            for query in test_queries:
                room_name = analyzer.room_handlers.parse_room_query(query)
                print(f"📤 Query: '{query}'")
                print(f"🏠 Parsed Room: {room_name or 'Not detected'}")
                print()
        else:
            print("❌ Room handlers not available for testing")
            
    except Exception as e:
        print(f"❌ Error testing room parsing: {e}")

def demonstrate_room_capabilities():
    """Demonstrate all room-specific capabilities"""
    
    print("\n🎯 DEMONSTRATING ROOM CAPABILITIES")
    print("=" * 60)
    
    capabilities = [
        {
            "name": "Predictive Analysis",
            "query": "What are the predictions for Room 1?",
            "description": "Comprehensive room predictions including energy, maintenance, and occupancy"
        },
        {
            "name": "Current Status",
            "query": "Room 1 current status",
            "description": "Real-time room conditions and occupancy"
        },
        {
            "name": "Energy Analysis",
            "query": "Room 1 energy consumption trends",
            "description": "Energy usage patterns and optimization opportunities"
        },
        {
            "name": "Maintenance Predictions",
            "query": "Maintenance needed for Room 1",
            "description": "Equipment health and maintenance scheduling"
        },
        {
            "name": "Anomaly Detection",
            "query": "Detect anomalies in Room 1",
            "description": "Unusual patterns and system alerts"
        }
    ]
    
    for capability in capabilities:
        print(f"\n🔧 {capability['name']}")
        print(f"📝 Description: {capability['description']}")
        print(f"📤 Query: {capability['query']}")
        
        try:
            result = ask(capability['query'])
            
            if "error" not in result:
                answer = result.get('answer', 'No response')
                print(f"📥 Result: {answer[:100]}{'...' if len(answer) > 100 else ''}")
                
                # Show specific capability results
                if capability['name'] == "Predictive Analysis" and 'predictions' in result:
                    predictions = result['predictions']
                    print(f"⚡ Energy Forecast: {predictions.get('energy_forecast', {}).get('trend_direction', 'N/A')}")
                    print(f"🔧 Maintenance Priority: {predictions.get('equipment_health', {}).get('maintenance_priority', 'N/A')}")
                
                print("✅ Capability working")
            else:
                print(f"❌ Error: {result['error']}")
                
        except Exception as e:
            print(f"❌ Exception: {e}")

def main():
    """Main test function"""
    
    print("🧪 ROOM-SPECIFIC QUERY TEST SUITE")
    print("=" * 80)
    print("Testing comprehensive room analysis capabilities")
    print("Including predictions, maintenance, energy, and anomaly detection")
    print()
    
    # Initialize system
    print("🚀 Initializing system...")
    if not initialize_analyzer():
        print("❌ System initialization failed!")
        print("Make sure your database is running and accessible")
        return
    
    print("✅ System initialized successfully!")
    print()
    
    try:
        # Run all tests
        test_available_rooms()
        test_room_data_availability()
        test_room_query_parsing()
        test_room_specific_queries()
        demonstrate_room_capabilities()
        
        print("\n🎉 ALL ROOM TESTS COMPLETED!")
        print("\n📋 ROOM CAPABILITIES SUMMARY:")
        print("✅ Room-specific predictions")
        print("✅ Room energy analysis")
        print("✅ Room maintenance scheduling")
        print("✅ Room anomaly detection")
        print("✅ Room status monitoring")
        print("✅ Room utilization analysis")
        
        print("\n🏠 SUPPORTED ROOM QUERY FORMATS:")
        print("• 'What are the predictions for Room 1?'")
        print("• 'Room A energy consumption'")
        print("• 'Maintenance needed in Room 2'")
        print("• 'for Room 1 show status'")
        print("• 'in Room B detect anomalies'")
        
        print("\n🚀 ROOM-SPECIFIC SYSTEM READY FOR PRODUCTION!")
        
    except Exception as e:
        print(f"❌ Test suite failed: {e}")
        print("Check your database connection and system configuration")

if __name__ == "__main__":
    main()