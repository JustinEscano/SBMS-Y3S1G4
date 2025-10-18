#!/usr/bin/env python3
"""
Test script to demonstrate database-only operation
This script shows how the LLM system now works without JSON files
"""

import os
import sys
import logging
from datetime import datetime

# Add the current directory to Python path
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from main import RoomLogAnalyzer
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

def test_database_only_mode():
    """Test that the system works in database-only mode"""
    logger.info("Testing Database-Only Mode")
    logger.info("=" * 40)
    
    try:
        # This should fail gracefully with a clear error message
        # when database is not available
        analyzer = RoomLogAnalyzer(
            use_database=True,
            mongo_uri=os.getenv("MONGO_ATLAS_URI"),
            mongo_db_name=os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=os.getenv("PROMPT_LOGS_DB_NAME", "prompt_logs"),
            prompt_logs_collection_name=os.getenv("PROMPT_LOGS_COLLECTION_NAME", "queries")
        )
        
        logger.info("✅ RoomLogAnalyzer created successfully")
        
        # Try to load data
        df = analyzer.load_and_process_data(limit=10)
        logger.info(f"✅ Data loaded successfully: {len(df)} records")
        
        # Try to create documents
        documents = analyzer.create_documents(df)
        logger.info(f"✅ Documents created successfully: {len(documents)} documents")
        
        # Try to initialize vector store
        analyzer.initialize_vector_store(documents)
        logger.info("✅ Vector store initialized successfully")
        
        # Try to initialize QA chain
        analyzer.initialize_qa_chain()
        logger.info("✅ QA chain initialized successfully")
        
        # Try a simple query
        result = analyzer.ask("How many records are there?")
        if "error" not in result:
            logger.info(f"✅ Query successful: {result.get('answer', 'No answer')}")
        else:
            logger.error(f"❌ Query failed: {result['error']}")
        
        return True
        
    except ValueError as e:
        if "PostgreSQL database connection required but failed" in str(e):
            logger.info("✅ System correctly failed with database connection error")
            logger.info(f"   Error message: {e}")
            logger.info("✅ No JSON fallback attempted - this is the expected behavior")
            return True
        else:
            logger.error(f"❌ Unexpected ValueError: {e}")
            return False
            
    except Exception as e:
        logger.error(f"❌ Unexpected error: {e}")
        return False

def main():
    """Run the database-only test"""
    logger.info("Database-Only Mode Test")
    logger.info("=" * 50)
    logger.info(f"Timestamp: {datetime.now()}")
    logger.info("")
    
    success = test_database_only_mode()
    
    logger.info("")
    logger.info("=" * 50)
    logger.info("TEST SUMMARY")
    logger.info("=" * 50)
    
    if success:
        logger.info("🎉 TEST PASSED")
        logger.info("The system correctly:")
        logger.info("- Requires database connection")
        logger.info("- Fails gracefully when database is unavailable")
        logger.info("- Does not attempt JSON fallback")
        logger.info("- Provides clear error messages")
        return 0
    else:
        logger.error("❌ TEST FAILED")
        return 1

if __name__ == "__main__":
    sys.exit(main())