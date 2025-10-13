# test_anomaly_direct.py
import logging
import pandas as pd
from main import initialize_analyzer
from anomaly_detector import AdvancedAnomalyDetector

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def test_direct_anomaly_detection():
    """Test the anomaly detection system directly"""
    print("🧪 DIRECT Anomaly Detection Test")
    print("=" * 60)
    
    try:
        # Initialize analyzer
        analyzer = initialize_analyzer()
        if not analyzer:
            print("❌ Failed to initialize analyzer")
            return
        
        print("✅ Analyzer initialized")
        
        # Test the anomaly detector directly
        if hasattr(analyzer, 'anomaly_detector') and analyzer.anomaly_detector:
            detector = analyzer.anomaly_detector
            print("✅ Anomaly detector found")
            
            # Test 1: Load alert data
            print("\n📊 Test 1: Loading alert data...")
            alerts_df = detector.load_alerts_data(days_back=30)
            print(f"   Loaded {len(alerts_df)} alerts from core_alert table")
            print(f"   Alert types: {alerts_df['alert_type'].value_counts().to_dict()}")
            print(f"   Severity distribution: {alerts_df['severity_level'].value_counts().to_dict()}")
            print(f"   Resolution status: {alerts_df['is_resolved'].value_counts().to_dict()}")
            
            # Test 2: Analyze patterns
            print("\n📈 Test 2: Analyzing patterns...")
            analysis = detector.analyze_alert_patterns(alerts_df)
            if "error" not in analysis:
                print(f"   Total alerts: {analysis['summary']['total_alerts']}")
                print(f"   Unresolved alerts: {analysis['summary']['unresolved_alerts']}")
                print(f"   Alert type distribution: {analysis['summary']['alert_type_distribution']}")
            else:
                print(f"   ❌ Pattern analysis failed: {analysis['error']}")
            
            # Test 3: Detect data anomalies
            print("\n🔍 Test 3: Detecting data anomalies...")
            anomalies = detector.detect_data_anomalies(alerts_df)
            print(f"   Detected {len(anomalies)} data anomalies")
            for i, anomaly in enumerate(anomalies, 1):
                print(f"   {i}. {anomaly['description']}")
                print(f"      → {anomaly['recommendation']}")
            
            # Test 4: Generate insights
            print("\n💡 Test 4: Generating insights...")
            insights = detector.generate_insights(alerts_df)
            print(f"   Generated {len(insights)} insights")
            for i, insight in enumerate(insights[:3], 1):
                print(f"   {i}. {insight['title']}: {insight['description']}")
            
            # Test 5: Comprehensive report
            print("\n📋 Test 5: Comprehensive anomaly report...")
            report = detector.get_comprehensive_anomaly_report(days_back=30)
            if "error" in report:
                print(f"   ❌ Report generation failed: {report['error']}")
            else:
                print("   ✅ Report generated successfully")
                print(f"   Summary length: {len(report['summary'])} characters")
                print(f"   Data anomalies: {len(report.get('data_anomalies', []))}")
                print(f"   Insights: {len(report.get('insights', []))}")
                print(f"   Emerging patterns: {len(report.get('emerging_patterns', []))}")
                
                # Show the actual summary
                print("\n" + "="*50)
                print("ACTUAL ANOMALY REPORT SUMMARY:")
                print("="*50)
                print(report["summary"])
            
        else:
            print("❌ No anomaly detector found in analyzer")
            
    except Exception as e:
        print(f"❌ Error in direct anomaly detection test: {e}")
        import traceback
        traceback.print_exc()

def test_specific_queries():
    """Test specific queries that should trigger anomaly detection"""
    print("\n\n🔍 TESTING SPECIFIC QUERIES")
    print("=" * 60)
    
    try:
        analyzer = initialize_analyzer()
        if not analyzer:
            return
            
        test_queries = [
            "Analyze the alert data from core_alert table",
            "What patterns do you see in the alert data?",
            "Detect anomalies in the core_alert data",
            "Show me anomaly patterns in the alert system",
            "Generate an anomaly report for the alert data",
            "What alert anomalies should I be concerned about?",
            "Analyze alert patterns and detect any anomalies",
            "Show me the anomaly detection report",
            "What unusual patterns are in the alert data?",
            "Detect any abnormalities in the core_alert table"
        ]
        
        for query in test_queries:
            print(f"\n📝 Query: {query}")
            print("-" * 40)
            
            result = analyzer.ask(query)
            
            if 'error' in result:
                print(f"❌ Error: {result['error']}")
            else:
                answer = result.get('answer', 'No answer')
                # Check if it's using the actual anomaly detector
                if "Advanced Anomaly Analysis Report" in answer or "anomaly" in answer.lower():
                    print("✅ USING ANOMALY DETECTOR")
                    # Show first part of the answer
                    lines = answer.split('\n')
                    for line in lines[:10]:  # Show first 10 lines
                        if line.strip():
                            print(f"   {line}")
                    if len(lines) > 10:
                        print("   ... (truncated)")
                else:
                    print("❌ NOT USING ANOMALY DETECTOR")
                    print(f"   Response: {answer[:200]}...")
                    
    except Exception as e:
        print(f"❌ Error in query test: {e}")

if __name__ == "__main__":
    test_direct_anomaly_detection()
    test_specific_queries()