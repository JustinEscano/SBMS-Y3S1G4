import pandas as pd
import os
import hashlib
import time
import json
import shutil
import re
from datetime import datetime
from langchain_core.documents import Document
from langchain.chains import RetrievalQA
from langchain_ollama import OllamaEmbeddings
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma
import logging
from database_adapter import DatabaseAdapter
from pymongo import MongoClient
from dotenv import load_dotenv
from prompts_config import PromptsConfig
from advanced_llm_handlers import AdvancedLLMHandlers
from room_specific_handlers import RoomSpecificHandlers
import sys
from pathlib import Path

# FIXED: Correct path resolution
BASE_DIR = Path(__file__).resolve().parent  # Points to llm/static_remote_LLM/
PROJECT_ROOT = BASE_DIR.parent.parent  # Points to SBMS-Y3S1G4/

print(f"DEBUG: BASE_DIR: {BASE_DIR}")
print(f"DEBUG: PROJECT_ROOT: {PROJECT_ROOT}")

# Add SBMS-Y3S1G4/api/ to sys.path
sys.path.append(str(PROJECT_ROOT / 'api'))

# Set DJANGO_SETTINGS_MODULE
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')

# FIXED: Load environment variables from .env in the correct project directory
env_path = PROJECT_ROOT / ".env"
print(f"DEBUG: Looking for .env at: {env_path}")
print(f"DEBUG: .env exists: {os.path.exists(env_path)}")

if os.path.exists(env_path):
    load_dotenv(dotenv_path=env_path)
    print(f"DEBUG: Successfully loaded .env from {env_path}")
else:
    # Try alternative locations
    alternative_paths = [
        PROJECT_ROOT / ".env",
        BASE_DIR / ".env", 
        Path.cwd() / ".env",
        Path.home() / "Documents" / "GitHub" / "SBMS-Y3S1G4" / ".env"
    ]
    
    for alt_path in alternative_paths:
        print(f"DEBUG: Trying alternative path: {alt_path}")
        if os.path.exists(alt_path):
            load_dotenv(dotenv_path=alt_path)
            print(f"DEBUG: Successfully loaded .env from {alt_path}")
            break
    else:
        print("DEBUG: No .env file found in any location")

print(f"DEBUG: MONGO_ATLAS_URI: {os.getenv('MONGO_ATLAS_URI')}")

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(os.path.dirname(__file__), "room_analysis.log"), encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def debug_environment():
    """Debug function to check environment variables"""
    print("=== ENVIRONMENT DEBUG ===")
    print(f"Current file: {__file__}")
    print(f"BASE_DIR: {BASE_DIR}")
    print(f"PROJECT_ROOT: {PROJECT_ROOT}")
    print(f"Current working directory: {os.getcwd()}")
    print(f"MONGO_ATLAS_URI exists: {bool(os.getenv('MONGO_ATLAS_URI'))}")
    
    # List files in project root to verify structure
    try:
        files_in_root = os.listdir(PROJECT_ROOT)
        print(f"Files in project root: {files_in_root}")
    except Exception as e:
        print(f"Could not list project root: {e}")

class RoomLogAnalyzer:
    def __init__(self, chroma_dir=None, use_database=True,
                 mongo_uri=None, mongo_db_name=None, mongo_collection_name=None,
                 prompt_logs_db_name=None, prompt_logs_collection_name=None,
                 prompts_config_file=None, prompt_type="base_enhancement",
                 document_template="standard"):
        # Run environment debug
        debug_environment()
        
        # Dynamically set paths relative to llm/static_remote_LLM/
        script_dir = os.path.dirname(os.path.abspath(__file__))
        self.chroma_dir = chroma_dir or os.path.join(script_dir, "chroma_room_logs")
        self.use_database = use_database
        self.vector_store = None
        self.qa_chain = None
        self.processed_hashes = set()
        self.df = None
        self.db_adapter = None
        self.mongo_client = None
        self.mongo_db = None
        self.mongo_collection = None
        self.prompt_logs_db = None
        self.prompt_logs_collection = None

        # Connection settings with retry logic
        self.mongo_connection_timeout = 10000  # 10 seconds
        self.mongo_socket_timeout = 30000  # 30 seconds
        self.max_retries = 3

        # Initialize prompts configuration
        config_path = prompts_config_file or os.path.join(script_dir, "custom_prompts.json")
        self.prompts = PromptsConfig(config_path if os.path.exists(config_path) else None)
        self.prompt_type = prompt_type
        self.document_template = document_template
        logger.info(f"Using prompt type: {prompt_type}")
        logger.info(f"Using document template: {document_template}")

        # Load environment variables if not provided
        if mongo_uri is None:
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            print(f"DEBUG: Retrieved MONGO_ATLAS_URI from env: {bool(mongo_uri)}")
            
        if mongo_db_name is None:
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
        if mongo_collection_name is None:
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
        if prompt_logs_db_name is None:
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
        if prompt_logs_collection_name is None:
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")

        logger.info(f"Initializing MongoDB with DB: {prompt_logs_db_name}, Collection: {prompt_logs_collection_name}")

        # Initialize database adapters
        if self.use_database:
            try:
                self.db_adapter = DatabaseAdapter()
                logger.info("PostgreSQL database adapter initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize PostgreSQL adapter: {e}")
                self.db_adapter = None
                logger.warning("Continuing without PostgreSQL database connection")

            # Initialize MongoDB with retry logic
            if mongo_uri:
                print(f"DEBUG: Initializing MongoDB with URI: {mongo_uri[:50]}...")  # Show first 50 chars
                self.initialize_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name, 
                                                 prompt_logs_db_name, prompt_logs_collection_name)
            else:
                logger.error("MONGO_ATLAS_URI not provided in environment variables")
                print("DEBUG: MONGO_ATLAS_URI is None - check .env file")
                self.prompt_logs_collection = None

        # FIXED: Initialize advanced handlers with database adapter
        self.advanced_handlers = AdvancedLLMHandlers(self.prompts, self.db_adapter)
        self.room_handlers = None

        self._load_processed_hashes()

        if self.use_database and self.db_adapter:
            try:
                self.room_handlers = RoomSpecificHandlers(self.prompts, self.db_adapter)
                logger.info("Room-specific handlers initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize room handlers: {e}")
                self.room_handlers = None
        else:
            logger.warning("No database adapter available, room-specific handlers not initialized")

    def initialize_mongodb_connection(self, mongo_uri, mongo_db_name, mongo_collection_name, 
                                     prompt_logs_db_name, prompt_logs_collection_name):
        """Initialize MongoDB connection with enhanced debugging"""
        print(f"DEBUG: initialize_mongodb_connection called")
        print(f"DEBUG: mongo_uri provided: {bool(mongo_uri)}")
        
        if not mongo_uri:
            logger.error("No MongoDB URI provided")
            print("DEBUG: No MongoDB URI - cannot connect")
            return False
            
        for attempt in range(self.max_retries):
            try:
                print(f"DEBUG: Attempt {attempt + 1} to connect to MongoDB")
                
                # Test connection
                self.mongo_client = MongoClient(
                    mongo_uri,
                    serverSelectionTimeoutMS=5000,
                    socketTimeoutMS=10000,
                    retryWrites=True,
                    connectTimeoutMS=10000
                )
                
                # Test the connection
                print("DEBUG: Attempting to ping MongoDB...")
                ping_result = self.mongo_client.admin.command('ping')
                print(f"DEBUG: MongoDB ping successful: {ping_result}")
                
                # Initialize databases and collections
                self.mongo_db = self.mongo_client[mongo_db_name]
                self.mongo_collection = self.mongo_db[mongo_collection_name]
                self.prompt_logs_db = self.mongo_client[prompt_logs_db_name]
                self.prompt_logs_collection = self.prompt_logs_db[prompt_logs_collection_name]
                
                print(f"DEBUG: Collections initialized:")
                print(f"  - mongo_collection: {self.mongo_collection.name}")
                print(f"  - prompt_logs_collection: {self.prompt_logs_collection.name}")
                
                # Test a simple insert to prompt_logs_collection
                test_doc = {
                    "test_timestamp": datetime.utcnow(),
                    "message": "Connection test for chat logs",
                    "analyzer_init": True
                }
                test_result = self.prompt_logs_collection.insert_one(test_doc)
                print(f"DEBUG: Test insert to prompt_logs_collection successful, ID: {test_result.inserted_id}")
                
                # Clean up test document
                self.prompt_logs_collection.delete_one({"_id": test_result.inserted_id})
                print("DEBUG: Test document cleaned up from prompt_logs_collection")
                
                logger.info(f"MongoDB Atlas connected successfully on attempt {attempt + 1}")
                return True
                
            except Exception as e:
                logger.error(f"MongoDB connection attempt {attempt + 1} failed: {e}")
                print(f"DEBUG: Connection attempt {attempt + 1} failed: {str(e)}")
                
                if attempt < self.max_retries - 1:
                    wait_time = 2 ** attempt
                    print(f"DEBUG: Retrying in {wait_time} seconds...")
                    time.sleep(wait_time)
                else:
                    logger.error("All MongoDB connection attempts failed")
                    self.mongo_client = None
                    self.prompt_logs_collection = None
                    return False

    def check_mongodb_health(self):
        """Check if MongoDB connection is healthy"""
        if not self.use_database or self.mongo_client is None:
            print("DEBUG: MongoDB health check failed: use_database=False or mongo_client=None")
            return False
        
        try:
            self.mongo_client.admin.command('ping')
            # Verify prompt_logs_collection specifically
            if self.prompt_logs_collection is None:
                print("DEBUG: prompt_logs_collection is None during health check")
                return False
            print("DEBUG: MongoDB health check successful")
            return True
        except Exception as e:
            logger.error(f"MongoDB health check failed: {e}")
            print(f"DEBUG: MongoDB health check failed: {str(e)}")
            return False

    def ensure_mongodb_connection(self):
        """Ensure MongoDB connection is active before logging"""
        if not self.check_mongodb_health():
            logger.warning("MongoDB connection lost, attempting to reconnect...")
            print("DEBUG: Attempting MongoDB reconnection")
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
            
            success = self.initialize_mongodb_connection(
                mongo_uri,
                mongo_db_name,
                mongo_collection_name,
                prompt_logs_db_name,
                prompt_logs_collection_name
            )
            if success:
                print("DEBUG: MongoDB reconnection successful")
            else:
                print("DEBUG: MongoDB reconnection failed")
            return success
        print("DEBUG: MongoDB connection already healthy")
        return True

    def _log_to_backup_file(self, log_data):
        """Log to a local file as backup when MongoDB fails"""
        try:
            backup_dir = os.path.join(os.path.dirname(__file__), "backup_logs")
            os.makedirs(backup_dir, exist_ok=True)
            
            backup_file = os.path.join(backup_dir, f"prompt_backup_{datetime.utcnow().strftime('%Y%m%d')}.json")
            print(f"DEBUG: Writing to backup file: {backup_file}")
            
            with open(backup_file, 'a', encoding='utf-8') as f:
                json.dump(log_data, f, ensure_ascii=False, default=str)
                f.write('\n')
                
            logger.info(f"Logged to backup file: {backup_file}")
            return True
        except Exception as e:
            logger.error(f"Failed to write to backup file: {e}")
            print(f"DEBUG: Backup file write error: {e}")
            return False

    def recover_backup_logs(self):
        """Recover logs from backup files to MongoDB when connection is restored"""
        try:
            backup_dir = os.path.join(os.path.dirname(__file__), "backup_logs")
            if not os.path.exists(backup_dir):
                return 0
                
            recovered_count = 0
            for backup_file in os.listdir(backup_dir):
                if backup_file.startswith("prompt_backup_") and backup_file.endswith(".json"):
                    file_path = os.path.join(backup_dir, backup_file)
                    with open(file_path, 'r', encoding='utf-8') as f:
                        for line in f:
                            try:
                                log_data = json.loads(line.strip())
                                # Convert string timestamp back to datetime
                                if 'timestamp' in log_data and isinstance(log_data['timestamp'], str):
                                    log_data['timestamp'] = datetime.fromisoformat(log_data['timestamp'])
                                
                                # Remove backup-specific fields
                                log_data.pop('mongo_error', None)
                                log_data.pop('log_type', None)
                                log_data.pop('backup_logged', None)
                                
                                # Insert to MongoDB
                                if self.prompt_logs_collection:
                                    self.prompt_logs_collection.insert_one(log_data)
                                    recovered_count += 1
                                    
                            except Exception as e:
                                logger.error(f"Error recovering log entry: {e}")
                                continue
                    
                    # Archive processed backup file
                    archived_dir = os.path.join(backup_dir, "archived")
                    os.makedirs(archived_dir, exist_ok=True)
                    archived_path = os.path.join(archived_dir, backup_file)
                    shutil.move(file_path, archived_path)
            
            logger.info(f"Recovered {recovered_count} logs from backup files")
            return recovered_count
            
        except Exception as e:
            logger.error(f"Error recovering backup logs: {e}")
            return 0

    def log_prompt_to_mongodb(self, query, response, user_id=None, username=None, session_id=None, client_ip=None, sources=None, error=None):
        """Enhanced logging with detailed debugging - saves to chat_logs.conversations"""
        print(f"=== MONGODB CHAT LOGGING DEBUG ===")
        print(f"DEBUG: log_prompt_to_mongodb called")
        print(f"DEBUG: use_database: {self.use_database}")
        print(f"DEBUG: prompt_logs_collection: {self.prompt_logs_collection}")
        print(f"DEBUG: query: {query}")
        print(f"DEBUG: response: {response[:100] if response else None}...")
        print(f"DEBUG: sources_count: {len(sources) if sources else 0}")
        
        # Always create backup log first
        backup_log = {
            "timestamp": datetime.utcnow().isoformat(),
            "query": query,
            "response": str(response) if response else None,
            "user_id": user_id or "anonymous",
            "username": username or "anonymous",
            "session_id": session_id,
            "client_ip": client_ip,
            "sources_count": len(sources) if sources else 0,
            "error": error,
            "log_type": "chat_interaction",
            "debug_note": "Backup chat log"
        }
        
        # Log to backup file
        backup_success = self._log_to_backup_file(backup_log)
        print(f"DEBUG: Backup file logging: {backup_success}")
        
        # Check if we should even attempt MongoDB
        if not self.use_database:
            print("DEBUG: use_database is False - skipping MongoDB")
            return False
            
        if self.prompt_logs_collection is None:
            print("DEBUG: prompt_logs_collection is None - attempting to reconnect")
            if not self.ensure_mongodb_connection():
                print("DEBUG: Reconnection failed - only backup file used")
                return False
        
        try:
            # Prepare the main log document
            prompt_log = {
                "timestamp": datetime.utcnow(),
                "query": query,
                "response": str(response).encode('utf-8').decode('utf-8') if response else None,  # Ensure UTF-8 for emojis
                "user_id": user_id or "anonymous",
                "username": username or "anonymous",
                "session_id": session_id,
                "client_ip": client_ip,
                "sources_count": len(sources) if sources else 0,
                "error": error,
                "metadata": {
                    "model": "incept5/llama3.1-claude:latest",
                    "retrieval_method": "vector_store",
                    "prompt_type": self.prompt_type,
                    "document_template": self.document_template,
                    "backup_logged": True,
                    "debug_timestamp": datetime.utcnow().isoformat()
                }
            }

            if sources:
                source_hashes = [source['metadata']['doc_hash'] for source in sources if 'metadata' in source and 'doc_hash' in source['metadata']]
                prompt_log["source_document_hashes"] = source_hashes

            print(f"DEBUG: Attempting to insert into MongoDB (chat_logs.conversations)...")
            result = self.prompt_logs_collection.insert_one(prompt_log)
            print(f"DEBUG: MongoDB insert successful! ID: {result.inserted_id}")
            logger.info(f"Successfully logged chat to chat_logs.conversations with ID: {result.inserted_id}")
            return True
            
        except Exception as e:
            print(f"DEBUG: MongoDB insert failed: {str(e)}")
            logger.error(f"Error logging chat to chat_logs.conversations: {e}")
            
            # Log the failure to backup with more details
            backup_log["mongo_error"] = str(e)
            backup_log["mongo_error_type"] = type(e).__name__
            self._log_to_backup_file(backup_log)
            return False

    def _load_processed_hashes(self):
        """Load hashes of already processed documents to avoid duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        if os.path.exists(hash_file):
            try:
                with open(hash_file, 'r', encoding='utf-8') as f:
                    self.processed_hashes = set(line.strip() for line in f)
                logger.info(f"Loaded {len(self.processed_hashes)} existing document hashes")
            except Exception as e:
                logger.error(f"Error loading processed hashes: {e}")

    def _save_processed_hashes(self):
        """Save hashes of processed documents to avoid future duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        try:
            os.makedirs(os.path.dirname(hash_file), exist_ok=True)
            with open(hash_file, 'w', encoding='utf-8') as f:
                for h in self.processed_hashes:
                    f.write(h + '\n')
        except Exception as e:
            logger.error(f"Error saving processed hashes: {e}")

    def _generate_document_hash(self, row):
        """Generate a unique hash for a document based on all relevant fields"""
        content = (
            f"{row['timestamp']}_"
            f"{row['occupancy_count']}_"
            f"{row['energy_consumption_kwh']}_"
            f"{row['power_consumption_watts.lighting']}_"
            f"{row['power_consumption_watts.hvac_fan']}_"
            f"{row.get('power_consumption_watts.air_conditioner_compressor', 0)}_"
            f"{row.get('power_consumption_watts.projector', 0)}_"
            f"{row.get('power_consumption_watts.computer', 0)}_"
            f"{row['power_consumption_watts.standby_misc']}_"
            f"{row['power_consumption_watts.total']}_"
            f"{row['equipment_usage.lights_on_hours']}_"
            f"{row['equipment_usage.air_conditioner_on_hours']}_"
            f"{row['equipment_usage.projector_on_hours']}_"
            f"{row['equipment_usage.computer_on_hours']}_"
            f"{row['environmental_data.temperature_celsius']}_"
            f"{row['environmental_data.humidity_percent']}"
        )
        return hashlib.md5(content.encode()).hexdigest()

    def log_to_mongodb(self, data):
        """Log a single data record to MongoDB (sensor logs in LLM_logs.logs)"""
        try:
            if not self.use_database or self.mongo_collection is None:
                logger.error("MongoDB not initialized; cannot log sensor data")
                return False

            doc_hash = self._generate_document_hash(data)
            if doc_hash in self.processed_hashes:
                logger.info(f"Skipping duplicate sensor document with hash {doc_hash}")
                return False

            mongo_doc = data.copy()
            if 'timestamp' in mongo_doc:
                try:
                    mongo_doc['timestamp'] = pd.to_datetime(mongo_doc['timestamp'])
                except:
                    logger.warning(f"Could not convert timestamp: {mongo_doc['timestamp']}")

            mongo_doc['doc_hash'] = doc_hash
            mongo_doc['created_at'] = datetime.utcnow()

            self.mongo_collection.insert_one(mongo_doc)
            self.processed_hashes.add(doc_hash)
            self._save_processed_hashes()
            logger.info(f"Logged sensor data to LLM_logs.logs with hash {doc_hash}")
            return True
        except Exception as e:
            logger.error(f"Error logging sensor data to MongoDB: {e}")
            return False

    def load_from_postgresql(self, limit=None):
        """Load data from PostgreSQL and return as a DataFrame"""
        try:
            if self.db_adapter is None:
                logger.error("PostgreSQL adapter not initialized; cannot load data")
                return None

            df = self.db_adapter.get_sensor_data_as_dataframe(limit=limit)
            if df is None:
                logger.warning("PostgreSQL returned no data")
                return None

            df = df[df["occupancy_status"] == "occupied"]

            numeric_cols = [
                "occupancy_count", "energy_consumption_kwh",
                "power_consumption_watts.lighting", "power_consumption_watts.hvac_fan",
                "power_consumption_watts.air_conditioner_compressor", "power_consumption_watts.projector",
                "power_consumption_watts.computer", "power_consumption_watts.standby_misc",
                "power_consumption_watts.total", "equipment_usage.lights_on_hours",
                "equipment_usage.air_conditioner_on_hours", "equipment_usage.projector_on_hours",
                "equipment_usage.computer_on_hours", "environmental_data.temperature_celsius",
                "environmental_data.humidity_percent"
            ]
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors="coerce")

            logger.info(f"Loaded {len(df)} unique occupied room records from PostgreSQL")
            return df
        except Exception as e:
            logger.error(f"Error loading from PostgreSQL: {e}")
            return None

    def load_and_process_data(self, force_reload=False, limit=None):
        """Load and process the room logs data from PostgreSQL and log to MongoDB"""
        try:
            if not self.use_database or self.db_adapter is None:
                logger.warning("Database not initialized; returning empty DataFrame")
                self.df = pd.DataFrame()
                return self.df

            logger.info("Loading data from PostgreSQL")
            df = self.load_from_postgresql(limit=limit)

            if df is None or df.empty:
                logger.error("No data loaded from PostgreSQL")
                self.df = pd.DataFrame()
                return self.df

            logger.info(f"Loaded {len(df)} unique occupied room records from PostgreSQL")
            self.df = df

            # Log new sensor data to MongoDB (but don't let this block prompt logging)
            if self.use_database and self.mongo_collection is not None:
                logged_count = 0
                for _, row in df.iterrows():
                    if self.log_to_mongodb(row.to_dict()):
                        logged_count += 1
                if logged_count > 0:
                    logger.info(f"Logged {logged_count} new sensor records to MongoDB")
                else:
                    logger.info("No new sensor records to log to MongoDB (all duplicates)")

            return df

        except Exception as e:
            logger.error(f"Error loading data: {e}")
            self.df = pd.DataFrame()
            return self.df

    def _create_document_from_row(self, row):
        """Create a Document object from a DataFrame row using configurable template"""
        try:
            timestamp_str = row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        except:
            timestamp_str = str(row['timestamp'])

        template = self.prompts.get_document_template(self.document_template)
        page_content = template.format(
            timestamp=timestamp_str,
            occupancy_status=row['occupancy_status'],
            occupancy_count=row['occupancy_count'],
            energy_consumption_kwh=row['energy_consumption_kwh'],
            lighting_power=row['power_consumption_watts.lighting'],
            hvac_power=row['power_consumption_watts.hvac_fan'],
            ac_compressor_power=row.get('power_consumption_watts.air_conditioner_compressor', 0),
            projector_power=row.get('power_consumption_watts.projector', 0),
            computer_power=row.get('power_consumption_watts.computer', 0),
            standby_power=row['power_consumption_watts.standby_misc'],
            total_power=row['power_consumption_watts.total'],
            lights_hours=row['equipment_usage.lights_on_hours'],
            ac_hours=row['equipment_usage.air_conditioner_on_hours'],
            projector_hours=row['equipment_usage.projector_on_hours'],
            computer_hours=row['equipment_usage.computer_on_hours'],
            temperature=row['environmental_data.temperature_celsius'],
            humidity=row['environmental_data.humidity_percent']
        )

        doc_hash = self._generate_document_hash(row)
        return Document(
            page_content=page_content,
            metadata={
                "timestamp": timestamp_str,
                "occupancy_count": int(row["occupancy_count"]),
                "energy_kwh": float(row["energy_consumption_kwh"]),
                "power_total": float(row["power_consumption_watts.total"]),
                "temperature": float(row["environmental_data.temperature_celsius"]),
                "humidity": float(row["environmental_data.humidity_percent"]),
                "doc_hash": doc_hash
            }
        )

    def create_documents(self, df):
        """Convert DataFrame rows into LangChain Documents with deduplication"""
        documents = []
        new_document_count = 0

        for _, row in df.iterrows():
            doc_hash = self._generate_document_hash(row)
            if doc_hash in self.processed_hashes:
                logger.info(f"Skipping duplicate document with hash {doc_hash}")
                continue

            doc = self._create_document_from_row(row)
            documents.append(doc)
            self.processed_hashes.add(doc_hash)
            new_document_count += 1

        logger.info(f"Created {new_document_count} new documents, skipped {len(df) - new_document_count} duplicates")
        return documents

    def initialize_vector_store(self, documents, reset=False):
        """Initialize or load the vector store with documents"""
        try:
            if reset and os.path.exists(self.chroma_dir):
                logger.info("Resetting vector store")
                shutil.rmtree(self.chroma_dir)
                self.processed_hashes.clear()
                self._save_processed_hashes()

            if os.path.exists(self.chroma_dir) and os.listdir(self.chroma_dir) and not reset:
                logger.info("Loading existing vector store")
                embedding = OllamaEmbeddings(model="nomic-embed-text")
                vector_store = Chroma(
                    persist_directory=self.chroma_dir,
                    embedding_function=embedding,
                    collection_name="room_logs"
                )
                existing_docs = vector_store.get()
                existing_hashes = {doc.get('doc_hash') for doc in existing_docs['metadatas'] if isinstance(doc, dict) and 'doc_hash' in doc}
                new_documents = [doc for doc in documents if doc.metadata['doc_hash'] not in existing_hashes]
                if new_documents:
                    logger.info(f"Adding {len(new_documents)} new documents to existing vector store")
                    vector_store.add_documents(new_documents)
                    vector_store.persist()
                else:
                    logger.info("No new documents to add to vector store")
            else:
                logger.info("Creating new vector store")
                embedding = OllamaEmbeddings(model="nomic-embed-text")
                vector_store = Chroma.from_documents(
                    documents=documents,
                    embedding=embedding,
                    persist_directory=self.chroma_dir,
                    collection_name="room_logs"
                )
                vector_store.persist()

            self.vector_store = vector_store
            self._save_processed_hashes()

        except Exception as e:
            logger.error(f"Error initializing vector store: {e}")
            raise

    def initialize_qa_chain(self):
        """Initialize the QA chain with the LLM"""
        try:
            if not self.vector_store:
                raise ValueError("Vector store not initialized")
            llm = OllamaLLM(model="incept5/llama3.1-claude:latest")
            self.qa_chain = RetrievalQA.from_chain_type(
                llm=llm,
                retriever=self.vector_store.as_retriever(),
                chain_type="stuff",
                return_source_documents=True
            )
            logger.info("QA chain initialized successfully")
        except Exception as e:
            logger.error(f"Error initializing QA chain: {e}")
            raise

    def _get_source_documents_for_rows(self, rows):
        """Convert DataFrame rows to source documents for response"""
        source_docs = []
        for _, row in rows.iterrows():
            doc = self._create_document_from_row(row)
            source_docs.append({
                "page_content": doc.page_content,
                "metadata": dict(doc.metadata)
            })
        return source_docs

    def _parse_mixed_query(self, q_lower):
        """Parse mixed queries like 'highest temperature and highest energy'"""
        col_map = {
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "energy": "energy_consumption_kwh",
            "power": "power_consumption_watts.total",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "lighting": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "fan": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "air conditioner": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc",
            "misc": "power_consumption_watts.standby_misc"
        }

        op_map = {
            "highest": "max",
            "maximum": "max",
            "max": "max",
            "lowest": "min",
            "minimum": "min",
            "min": "min",
            "average": "mean",
            "mean": "mean",
            "avg": "mean"
        }

        operations = []
        parts = re.split(r'\s+and\s+|\s*&\s*|\s*,\s*', q_lower)

        for part in parts:
            part = part.strip()
            if not part:
                continue

            found_op = None
            found_col = None

            for op_word, op_func in op_map.items():
                if op_word in part:
                    found_op = op_func
                    break

            for col_word, col_name in col_map.items():
                if col_word in part:
                    found_col = col_name
                    break

            if found_op and found_col:
                operations.append((found_op, found_col))

        return operations

    def _handle_mixed_query(self, q_lower, df):
        """Handle mixed queries with multiple operations on different columns"""
        operations = self._parse_mixed_query(q_lower)

        if not operations:
            return None

        results = []
        all_sources = []

        for op, col in operations:
            if col not in df.columns:
                continue

            if op == "max":
                value = df[col].max()
                op_word = "highest"
            elif op == "min":
                value = df[col].min()
                op_word = "lowest"
            elif op == "mean":
                value = df[col].mean()
                op_word = "average"
                sample_rows = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_rows)
                all_sources.extend(sources)
                results.append(f"The {op_word} {col.split('.')[-1]} is {value:.2f}")
                continue
            else:
                continue

            matching_rows = df[df[col] == value]
            timestamps = []
            for _, row in matching_rows.iterrows():
                try:
                    timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                except:
                    timestamps.append(str(row["timestamp"]))

            sources = self._get_source_documents_for_rows(matching_rows.head(2))
            all_sources.extend(sources)
            col_display = col.split('.')[-1]
            results.append(f"The {op_word} {col_display} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}")

        if results:
            return {
                "answer": ". ".join(results) + ".",
                "sources": all_sources[:6]
            }

        return None

    def _handle_min_max_query(self, q_lower, df, operation):
        """Handle minimum/maximum queries for single columns"""
        col_map = {
            "total": "power_consumption_watts.total",
            "lighting": "power_consumption_watts.lighting",
            "light": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "fan": "power_consumption_watts.hvac_fan",
            "ac": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "air conditioner": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc",
            "misc": "power_consumption_watts.standby_misc",
            "energy": "energy_consumption_kwh",
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "projector": "equipment_usage.projector_on_hours",
            "projectors": "equipment_usage.projector_on_hours"
        }

        for key, col in col_map.items():
            if key in q_lower and col in df.columns:
                if operation == "combined":
                    min_value = df[col].min()
                    max_value = df[col].max()
                    min_rows = df[df[col] == min_value]
                    max_rows = df[df[col] == max_value]
                    min_timestamps = []
                    max_timestamps = []
                    for _, row in min_rows.iterrows():
                        try:
                            min_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except:
                            min_timestamps.append(str(row["timestamp"]))
                    for _, row in max_rows.iterrows():
                        try:
                            max_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except:
                            max_timestamps.append(str(row["timestamp"]))
                    sources = self._get_source_documents_for_rows(pd.concat([min_rows.head(2), max_rows.head(2)]))
                    return {
                        "answer": f"The lowest {key} is {min_value} at {', '.join(min_timestamps[:2])}. "
                                 f"The highest {key} is {max_value} at {', '.join(max_timestamps[:2])}.",
                        "sources": sources
                    }
                elif operation == "min":
                    value = df[col].min()
                    op_word = "lowest"
                else:
                    value = df[col].max()
                    op_word = "highest"

                matching_rows = df[df[col] == value]
                timestamps = []
                for _, row in matching_rows.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except:
                        timestamps.append(str(row["timestamp"]))
                sources = self._get_source_documents_for_rows(matching_rows.head(3))
                return {
                    "answer": f"The {op_word} {key} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}.",
                    "sources": sources
                }

        return None

    def _handle_avg_query(self, q_lower, df):
        """Handle average queries deterministically"""
        col_map = {
            "power": "power_consumption_watts.total",
            "energy": "energy_consumption_kwh",
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count",
            "lighting": "power_consumption_watts.lighting",
            "hvac": "power_consumption_watts.hvac_fan",
            "compressor": "power_consumption_watts.air_conditioner_compressor",
            "projector power": "power_consumption_watts.projector",
            "computer": "power_consumption_watts.computer",
            "standby": "power_consumption_watts.standby_misc"
        }

        for key, col in col_map.items():
            if key in q_lower and col in df.columns:
                avg_value = df[col].mean()
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                return {
                    "answer": f"The average {key} is {avg_value:.2f}.",
                    "sources": sources
                }

        return None

    def _handle_deterministic_query(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Handle specific queries deterministically to avoid hallucinations - FIXED LOGGING"""
        q_lower = query.lower().strip()
        df = self.load_and_process_data()
        if df is None or df.empty:
            logger.error("DataFrame is empty or None; cannot process query")
            # LOG THE ERROR
            self.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                error="No data available"
            )
            return {"answer": "No data available to process the query.", "sources": []}

        logger.info(f"Processing deterministic query: '{q_lower}'")
        print(f"DEBUG: Processing deterministic query: {q_lower}")

        # ROOM-SPECIFIC HANDLERS
        if self.room_handlers and any(keyword in q_lower for keyword in ["room", "for room", "in room"]):
            try:
                room_result = self.room_handlers.handle_room_specific_query(query)
                if room_result and "error" not in room_result:
                    logger.info(f"Used room-specific handler for query: '{query}'")
                    # PROMPT LOGGING: Always log deterministic results
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=room_result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=room_result.get("sources", [])
                    )
                    return room_result
                elif "error" in room_result:
                    logger.warning(f"Room-specific handler error: {room_result['error']}")
                    # LOG THE ERROR
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=room_result["error"]
                    )
                    return room_result
            except Exception as e:
                logger.error(f"Error in room-specific handler: {e}")
                print(f"DEBUG: Room-specific handler error: {e}")
                # LOG THE ERROR
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Room-specific handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # KPI QUERIES
        if any(keyword in q_lower for keyword in ["key performance indicators", "kpi", "performance metrics"]):
            try:
                logger.info(f"Matched KPI query: '{query}'")
                result = self.advanced_handlers.handle_kpi_query(df)
                if "error" in result:
                    logger.error(f"KPI query failed: {result['error']}")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"]
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in KPI handler: {e}")
                print(f"DEBUG: KPI handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"KPI handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # MOST USED ROOM QUERIES
        if any(keyword in q_lower for keyword in ["most used room", "room usage", "room utilization"]):
            try:
                logger.info(f"Matched most used room query: '{query}'")
                result = self.advanced_handlers.handle_most_used_room_query(df)
                if "error" in result:
                    logger.error(f"Most used room query failed: {result['error']}")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"]
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in most used room handler: {e}")
                print(f"DEBUG: Most used room handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Most used room handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # ENERGY TREND QUERIES
        if any(keyword in q_lower for keyword in ["energy trend", "energy pattern", "consumption trend", "analyze energy usage patterns", "energy usage patterns"]):
            try:
                logger.info(f"Matched energy trend query: '{query}'")
                result = self.advanced_handlers.handle_energy_trends_query(df)
                if "error" in result:
                    logger.error(f"Energy trend query failed: {result['error']}")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"]
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in energy trend handler: {e}")
                print(f"DEBUG: Energy trend handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Energy trend handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # WEEKLY SUMMARY QUERIES - FIXED
        if any(keyword in q_lower for keyword in ["weekly summary", "weekly report", "summary", "show me weekly summary", "generate weekly summary"]):
            try:
                logger.info(f"Attempting to generate weekly summary for query: '{query}'")
                result = self.advanced_handlers.generate_weekly_summary(df)
                if "error" in result:
                    logger.error(f"Weekly summary generation failed: {result['error']}")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"]
                    )
                    return result
                logger.info(f"Weekly summary generated: {result['answer'][:100]}...")
                print(f"DEBUG: Logging weekly summary for query: {query}")
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in weekly summary handler: {e}")
                print(f"DEBUG: Weekly summary handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Weekly summary handler failed: {str(e)}"
                )
                return {"error": f"Failed to generate weekly summary: {str(e)}"}

        # ANOMALY DETECTION QUERIES
        if any(keyword in q_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            try:
                logger.info(f"Matched anomaly detection query: '{query}'")
                anomalies = self.advanced_handlers.detect_anomalies(df)
                if anomalies:
                    anomaly_descriptions = [f"{a.anomaly_type}: {a.description}" for a in anomalies[:3]]
                    result = {
                        "answer": f"Detected {len(anomalies)} anomalies: {'; '.join(anomaly_descriptions)}",
                        "anomalies": [{"type": a.anomaly_type, "severity": a.severity, "description": a.description} for a in anomalies]
                    }
                else:
                    result = {"answer": "No anomalies detected in the current data.", "sources": []}
                
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in anomaly detection handler: {e}")
                print(f"DEBUG: Anomaly detection handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Anomaly detection handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # CONTEXT-AWARE QUERIES
        if any(keyword in q_lower for keyword in ["context", "current", "situation", "status"]):
            try:
                logger.info(f"Matched context-aware query: '{query}'")
                result = self.advanced_handlers.handle_context_aware_query(query, df)
                if "error" in result:
                    logger.error(f"Context-aware query failed: {result['error']}")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"]
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", [])
                )
                return result
            except Exception as e:
                logger.error(f"Error in context-aware handler: {e}")
                print(f"DEBUG: Context-aware handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Context-aware handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # ALL READINGS QUERIES
        if any(keyword in q_lower for keyword in ["all readings", "all logs", "all records", "all room_logs"]):
            try:
                logger.info(f"Matched all readings query: '{query}'")
                timestamps = []
                for _, row in df.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except:
                        timestamps.append(str(row["timestamp"]))
                sources = self._get_source_documents_for_rows(df.sample(min(3, len(df))))
                result = {
                    "answer": f"The room logs contain {len(timestamps)} occupied readings: {', '.join(timestamps[:5])}{'...' if len(timestamps) > 5 else ''}.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources
                )
                return result
            except Exception as e:
                logger.error(f"Error in all readings handler: {e}")
                print(f"DEBUG: All readings handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"All readings handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # RECORD COUNT QUERIES
        if "how many" in q_lower and any(keyword in q_lower for keyword in ["record", "data", "log"]):
            try:
                logger.info(f"Matched record count query: '{query}'")
                count = len(df)
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are {count} occupied room records in the dataset.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources
                )
                return result
            except Exception as e:
                logger.error(f"Error in record count handler: {e}")
                print(f"DEBUG: Record count handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Record count handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # PEOPLE COUNT QUERIES
        if "how many" in q_lower and "people" in q_lower:
            try:
                logger.info(f"Matched people count query: '{query}'")
                total_people = int(df["occupancy_count"].sum())
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are a total of {total_people} people across all occupied room records.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources
                )
                return result
            except Exception as e:
                logger.error(f"Error in people count handler: {e}")
                print(f"DEBUG: People count handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"People count handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # POWER CONSUMPTION BREAKDOWN QUERIES
        if "power consumption breakdown" in q_lower or "power breakdown" in q_lower:
            try:
                logger.info(f"Matched power breakdown query: '{query}'")
                timestamp_match = re.search(r'\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}', q_lower)
                if timestamp_match:
                    target_timestamp = timestamp_match.group(0)
                    try:
                        target_dt = pd.to_datetime(target_timestamp)
                        matching_rows = df[df["timestamp"] == target_dt]
                        if not matching_rows.empty:
                            row = matching_rows.iloc[0]
                            breakdown = (
                                f"Lighting: {row['power_consumption_watts.lighting']}W, "
                                f"HVAC Fan: {row['power_consumption_watts.hvac_fan']}W, "
                                f"Air Conditioner Compressor: {row.get('power_consumption_watts.air_conditioner_compressor', 0)}W, "
                                f"Projector: {row.get('power_consumption_watts.projector', 0)}W, "
                                f"Computer: {row.get('power_consumption_watts.computer', 0)}W, "
                                f"Standby Misc: {row['power_consumption_watts.standby_misc']}W, "
                                f"Total: {row['power_consumption_watts.total']}W"
                            )
                            sources = self._get_source_documents_for_rows(matching_rows)
                            result = {
                                "answer": f"At {target_timestamp}, the power consumption breakdown is: {breakdown}.",
                                "sources": sources
                            }
                            # PROMPT LOGGING: Always log deterministic results
                            self.log_prompt_to_mongodb(
                                query=query,
                                response=result["answer"],
                                user_id=user_id,
                                username=username,
                                session_id=session_id,
                                client_ip=client_ip,
                                sources=sources
                            )
                            return result
                    except ValueError:
                        logger.warning(f"Invalid timestamp format in query: {target_timestamp}")
                logger.warning("No valid timestamp found for power breakdown query")
                # LOG THE FAILURE
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error="No valid timestamp found for power breakdown"
                )
                return {"error": "No valid timestamp found for power breakdown query"}
            except Exception as e:
                logger.error(f"Error in power breakdown handler: {e}")
                print(f"DEBUG: Power breakdown handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Power breakdown handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # MIXED QUERIES
        mixed_result = self._handle_mixed_query(q_lower, df)
        if mixed_result:
            try:
                logger.info(f"Matched mixed query: '{query}'")
                # PROMPT LOGGING: Always log deterministic results
                self.log_prompt_to_mongodb(
                    query=query,
                    response=mixed_result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=mixed_result.get("sources", [])
                )
                return mixed_result
            except Exception as e:
                logger.error(f"Error in mixed query handler: {e}")
                print(f"DEBUG: Mixed query handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Mixed query handler failed: {str(e)}"
                )
                return {"error": str(e)}

        # MIN/MAX QUERIES
        has_lowest = "lowest" in q_lower or "minimum" in q_lower or "min " in q_lower
        has_highest = "highest" in q_lower or "maximum" in q_lower or "max " in q_lower

        if has_lowest and has_highest:
            try:
                logger.info(f"Matched combined min/max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "combined")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", [])
                    )
                    return result
                else:
                    logger.warning("No result for combined min/max query")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for combined min/max query"
                    )
                    return {"error": "No result for combined min/max query"}
            except Exception as e:
                logger.error(f"Error in combined min/max handler: {e}")
                print(f"DEBUG: Combined min/max handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Combined min/max handler failed: {str(e)}"
                )
                return {"error": str(e)}
        elif has_lowest:
            try:
                logger.info(f"Matched min query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "min")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", [])
                    )
                    return result
                else:
                    logger.warning("No result for min query")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for min query"
                    )
                    return {"error": "No result for min query"}
            except Exception as e:
                logger.error(f"Error in min handler: {e}")
                print(f"DEBUG: Min handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Min handler failed: {str(e)}"
                )
                return {"error": str(e)}
        elif has_highest:
            try:
                logger.info(f"Matched max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "max")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", [])
                    )
                    return result
                else:
                    logger.warning("No result for max query")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for max query"
                    )
                    return {"error": "No result for max query"}
            except Exception as e:
                logger.error(f"Error in max handler: {e}")
                print(f"DEBUG: Max handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Max handler failed: {str(e)}"
                )
                return {"error": str(e)}
        elif "average" in q_lower or "mean" in q_lower:
            try:
                logger.info(f"Matched average query: '{query}'")
                result = self._handle_avg_query(q_lower, df)
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", [])
                    )
                    return result
                else:
                    logger.warning("No result for average query")
                    self.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for average query"
                    )
                    return {"error": "No result for average query"}
            except Exception as e:
                logger.error(f"Error in average handler: {e}")
                print(f"DEBUG: Average handler error: {e}")
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Average handler failed: {str(e)}"
                )
                return {"error": str(e)}

        logger.warning(f"No deterministic match for query: '{q_lower}'; falling back to LLM")
        self.log_prompt_to_mongodb(
            query=query,
            response=None,
            user_id=user_id,
            username=username,
            session_id=session_id,
            client_ip=client_ip,
            error="No deterministic match, falling back to LLM"
        )
        return None

    def _enhance_query_for_llm(self, query):
        """Add context and instructions to reduce hallucinations using configurable prompts"""
        system_prompt = self.prompts.get_system_prompt(self.prompt_type)
        return system_prompt.format(query=query)

    def ask(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Ask a question about the room logs with robust logging - FIXED VERSION"""
        logger.info(f"Processing ask request for query: '{query}' with user_id: {user_id}, username: {username}")
        print(f"DEBUG: Entering ask with query: {query}")
        
        # Ensure MongoDB connection before processing
        if self.use_database:
            self.ensure_mongodb_connection()
        
        if not self.qa_chain:
            logger.error("QA chain not initialized")
            print("DEBUG: QA chain not initialized")
            # PROMPT LOGGING: Always log errors
            self.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error="QA chain not initialized"
            )
            return {"error": "QA chain not initialized. Please initialize the analyzer."}

        try:
            # Load data but don't let document duplication affect prompt logging
            df = self.load_and_process_data()
            print(f"DEBUG: DataFrame loaded, rows: {len(df) if df is not None else 0}")
            if df is None or df.empty:
                logger.warning("No data available for processing query")
                # PROMPT LOGGING: Always log no data scenario
                self.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id or "anonymous",
                    username=username or "anonymous",
                    session_id=session_id,
                    client_ip=client_ip,
                    error="No data available"
                )
                return {"answer": "No data available to process the query.", "sources": []}

            # Update vector store with any new documents, but continue even if no new documents
            documents = self.create_documents(df)
            if documents:
                logger.info(f"Adding {len(documents)} new documents due to data changes")
                if self.vector_store is None:
                    self.initialize_vector_store(documents)
                else:
                    self.vector_store.add_documents(documents)
                    self.vector_store.persist()
                self._save_processed_hashes()
            else:
                logger.info("No new documents to add to vector store - using existing knowledge")

            # Try deterministic handlers first
            deterministic_result = self._handle_deterministic_query(query, user_id, username, session_id, client_ip)
            if deterministic_result:
                logger.info(f"Used deterministic handler for query: '{query}'")
                print(f"DEBUG: Deterministic result: {deterministic_result['answer'][:50] if 'answer' in deterministic_result else 'Error'}...")
                # Note: Prompt logging already handled inside _handle_deterministic_query
                return deterministic_result

            # Fall back to LLM for complex queries
            enhanced_query = self._enhance_query_for_llm(query)
            result = self.qa_chain({"query": enhanced_query})
            logger.info(f"Query: '{query}' - Response generated using LLM")
            print(f"DEBUG: LLM result: {result.get('result', '')[:50]}...")

            llm_answer = result.get("result", "")
            validated_answer = self._validate_llm_response(llm_answer, query)

            seen_hashes = set()
            unique_source_docs = []
            for doc in result.get("source_documents", []):
                doc_hash = doc.metadata.get("doc_hash")
                if doc_hash not in seen_hashes:
                    unique_source_docs.append({
                        "page_content": doc.page_content,
                        "metadata": dict(doc.metadata)
                    })
                    seen_hashes.add(doc_hash)

            response = {
                "answer": validated_answer,
                "sources": unique_source_docs
            }

            print(f"DEBUG: Logging LLM response for query: {query}")
            # PROMPT LOGGING: Always log LLM responses
            self.log_prompt_to_mongodb(
                query=query,
                response=validated_answer,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                sources=unique_source_docs
            )
            return response

        except Exception as e:
            logger.error(f"Error processing query '{query}': {e}")
            print(f"DEBUG: Error in ask: {e}")
            # PROMPT LOGGING: Always log errors
            self.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error=f"Query processing failed: {str(e)}"
            )
            return {"error": f"Failed to process query: {str(e)}"}

    def _validate_llm_response(self, response, query):
        """Basic validation to catch obvious hallucinations"""
        if any(word in query.lower() for word in ['power', 'energy', 'watt', 'kwh']):
            numbers = re.findall(r'\d+\.?\d*', response)
            for num in numbers:
                try:
                    num_val = float(num)
                    if num_val > 10000:
                        return "I cannot provide a precise answer based on the available data. The numbers may not be accurate."
                except:
                    continue
        return response

# Initialize the analyzer globally
analyzer = None

def initialize_analyzer(reset_vector_store=False):
    global analyzer
    try:
        logger.info("Starting analyzer initialization with MongoDB Atlas")
        print(f"DEBUG: MONGO_ATLAS_URI: {os.getenv('MONGO_ATLAS_URI')}")
        
        # Test MongoDB connection first
        mongo_uri = os.getenv("MONGO_ATLAS_URI")
        if not mongo_uri:
            print("DEBUG: MONGO_ATLAS_URI is None - cannot initialize MongoDB")
            logger.error("MONGO_ATLAS_URI not found in environment")
            return False

        print("=== TESTING MONGODB CONNECTION ===")
        try:
            from pymongo import MongoClient
            client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            client.admin.command('ping')
            print("DEBUG: MongoDB connection test successful")
            client.close()
        except Exception as e:
            print(f"DEBUG: MongoDB connection test failed: {e}")
            return False

        # Set Django environment
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')
        import django
        django.setup()
        logger.info("Django environment initialized")

        analyzer = RoomLogAnalyzer(
            use_database=True,
            mongo_uri=mongo_uri,
            mongo_db_name=os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs"),
            prompt_logs_collection_name=os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
        )
        logger.info("RoomLogAnalyzer instance created")
        df = analyzer.load_and_process_data()
        logger.info(f"Data loaded, rows: {len(df) if df is not None else 0}")
        if df is None or df.empty:
            logger.warning("DataFrame is empty or None; check data sources")
            raise ValueError("No valid data to process")
        documents = analyzer.create_documents(df)
        logger.info(f"Documents created: {len(documents)}")
        analyzer.initialize_vector_store(documents, reset=reset_vector_store)
        logger.info("Vector store initialized")
        analyzer.initialize_qa_chain()
        logger.info("QA chain initialized")
        logger.info("Analyzer initialized successfully with MongoDB Atlas")
        return True
    except Exception as e:
        logger.error(f"Error initializing analyzer: {e}")
        print(f"DEBUG: Initialization error: {e}")
        return False

def ask(query, user_id=None, username=None, session_id=None, client_ip=None):
    """Public function to ask questions"""
    global analyzer
    logger.info(f"Calling ask with query: '{query}', user_id: {user_id}, username: {username}")
    print(f"DEBUG: Calling ask with query: {query}")
    if analyzer is None:
        if not initialize_analyzer():
            logger.error("Analyzer initialization failed")
            print("DEBUG: Analyzer initialization failed")
            return {"error": "Analyzer not initialized"}
    try:
        result = analyzer.ask(query, user_id=user_id, username=username, session_id=session_id, client_ip=client_ip)
        return result
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        print(f"DEBUG: Error processing query: {e}")
        return {"error": str(e)}

# Test block
if __name__ == "__main__":
    debug_environment()
    
    if initialize_analyzer(reset_vector_store=False):
        queries = [
            "What is the highest temperature?",
            "Show me the weekly summary", 
            "What is the room status?"
        ]
        for query in queries:
            result = ask(
                query=query,
                user_id="test_user",
                username="TestUser", 
                session_id="test_session",
                client_ip="127.0.0.1"
            )
            print(f"Query: {query}\nResult: {result}\n")