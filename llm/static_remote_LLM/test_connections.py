# test_connection.py
import os
from dotenv import load_dotenv
from pymongo import MongoClient

load_dotenv()

def test_connection():
    try:
        client = MongoClient(os.getenv("MONGO_ATLAS_URI"))
        client.admin.command('ping')
        print("✅ MongoDB Atlas connection successful!")
        
        # Check if database exists
        db = client["LLM_logs"]
        print(f"✅ Database 'LLM_logs' accessible")
        
        # Check if collection exists
        collection = db["logs"]
        print(f"✅ Collection 'logs' accessible")
        
        return True
        
    except Exception as e:
        print(f"❌ Connection failed: {e}")
        return False

if __name__ == "__main__":
    test_connection()