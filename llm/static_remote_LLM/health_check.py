#!/usr/bin/env python3
"""
Health check script for the LLM system
Tests database connectivity and basic functionality
"""

import os
import sys
import logging
from datetime import datetime

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import RoomLogAnalyzer
from database_adapter import DatabaseAdapter
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_postgresql_connection():
    """Test PostgreSQL database connection"""
    try:
        logger.info("Testing PostgreSQL connection...")
        db_adapter = DatabaseAdapter()
        df = db_adapter.get_sensor_data_as_dataframe(limit=5)
        if df is not None and not df.empty:
            logger.info(f"✅ PostgreSQL connection successful - Retrieved {len(df)} records")
            return True
        else:
            logger.error("�� PostgreSQL connection failed - No data retrieved")
            return False
    except Exception as e:
        logger.error(f"❌ PostgreSQL connection failed: {e}")
        return False

def test_mongodb_connection():
    """Test MongoDB Atlas connection"""
    try:
        logger.info("Testing MongoDB Atlas connection...")
        mongo_uri = os.getenv("MONGO_ATLAS_URI")
        if not mongo_uri:
            logger.warning("⚠️ MongoDB URI not provided - skipping MongoDB test")
            return True
        
        client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        client.admin.command('ping')
        logger.info("✅ MongoDB Atlas connection successful")
        return True
    except Exception as e:
        logger.error(f"❌ MongoDB Atlas connection failed: {e}")
        return False

def test_llm_initialization():
    """Test LLM system initialization"""
    try:
        logger.info("Testing LLM system initialization...")
        analyzer = RoomLogAnalyzer(
            use_database=True,
            mongo_uri=os.getenv("MONGO_ATLAS_URI"),
            mongo_db_name=os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=os.getenv("PROMPT_LOGS_DB_NAME", "prompt_logs"),
            prompt_logs_collection_name=os.getenv("PROMPT_LOGS_COLLECTION_NAME", "queries")
        )
        
        # Test data loading
        df = analyzer.load_and_process_data(limit=10)
        if df is None or df.empty:
            logger.error("❌ LLM initialization failed - No data loaded")
            return False
        
        # Test document creation
        documents = analyzer.create_documents(df)
        if not documents:
            logger.error("❌ LLM initialization failed - No documents created")
            return False
        
        # Test vector store initialization
        analyzer.initialize_vector_store(documents)
        if analyzer.vector_store is None:
            logger.error("❌ LLM initialization failed - Vector store not initialized")
            return False
        
        # Test QA chain initialization
        analyzer.initialize_qa_chain()
        if analyzer.qa_chain is None:
            logger.error("❌ LLM initialization failed - QA chain not initialized")
            return False
        
        logger.info("✅ LLM system initialization successful")
        return True
        
    except Exception as e:
        logger.error(f"❌ LLM initialization failed: {e}")
        return False

def test_simple_query():
    """Test a simple query"""
    try:
        logger.info("Testing simple query...")
        from main import ask
        
        result = ask("How many records are there?")
        if "error" in result:
            logger.error(f"❌ Query test failed: {result['error']}")
            return False
        
        logger.info(f"✅ Query test successful: {result.get('answer', 'No answer')}")
        return True
        
    except Exception as e:
        logger.error(f"❌ Query test failed: {e}")
        return False

def main():
    """Run all health checks"""
    logger.info("=" * 50)
    logger.info("LLM SYSTEM HEALTH CHECK")
    logger.info("=" * 50)
    logger.info(f"Timestamp: {datetime.now()}")
    logger.info("")
    
    tests = [
        ("PostgreSQL Connection", test_postgresql_connection),
        ("MongoDB Connection", test_mongodb_connection),
        ("LLM Initialization", test_llm_initialization),
        ("Simple Query", test_simple_query)
    ]
    
    results = {}
    for test_name, test_func in tests:
        logger.info(f"Running {test_name}...")
        results[test_name] = test_func()
        logger.info("")
    
    # Summary
    logger.info("=" * 50)
    logger.info("HEALTH CHECK SUMMARY")
    logger.info("=" * 50)
    
    all_passed = True
    for test_name, passed in results.items():
        status = "✅ PASS" if passed else "❌ FAIL"
        logger.info(f"{test_name}: {status}")
        if not passed:
            all_passed = False
    
    logger.info("")
    if all_passed:
        logger.info("🎉 ALL TESTS PASSED - System is healthy!")
        return 0
    else:
        logger.error("⚠️ SOME TESTS FAILED - System needs attention!")
        return 1

if __name__ == "__main__":
    sys.exit(main())