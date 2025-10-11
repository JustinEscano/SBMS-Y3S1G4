import logging
import os
import json
import shutil
from datetime import datetime
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure, OperationFailure
from dotenv import load_dotenv
import time
import pandas as pd  # For timestamp conversion in log_to_mongodb
import hashlib  # For _generate_document_hash

class LoggingManager:
    def __init__(self, project_root, mongo_uri=None, mongo_db_name=None, mongo_collection_name=None,
                 prompt_logs_db_name=None, prompt_logs_collection_name=None, use_database=True):
        self.project_root = project_root
        self.use_database = use_database
        self.mongo_client = None
        self.mongo_db = None
        self.mongo_collection = None
        self.prompt_logs_db = None
        self.prompt_logs_collection = None
        self.mongo_connection_timeout = 10000  # 10 seconds
        self.mongo_socket_timeout = 30000  # 30 seconds
        self.max_retries = 3

        # Load env if needed (fallback to provided values)
        if mongo_uri is None:
            env_path = self.project_root / ".env"
            if os.path.exists(env_path):
                load_dotenv(dotenv_path=env_path)
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")

        # Set up general logging
        self._setup_general_logging()

        # Initialize MongoDB if using database
        if self.use_database and mongo_uri:
            self.initialize_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name,
                                               prompt_logs_db_name, prompt_logs_collection_name)
        else:
            self.logger.warning("MongoDB URI not provided or database use disabled; skipping MongoDB logging")

    def _setup_general_logging(self):
        """Set up general logging configuration"""
        script_dir = os.path.dirname(os.path.abspath(__file__))
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(script_dir, "room_analysis.log"), encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        # Optional: Add error-specific file handler
        error_handler = logging.FileHandler(os.path.join(script_dir, "errors.log"), encoding='utf-8')
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(logging.Formatter('%(asctime)s - %(levelname)s - %(message)s - %(filename)s:%(lineno)d'))
        logging.getLogger().addHandler(error_handler)

        self.logger = logging.getLogger(__name__)
        self.logger.info("LoggingManager initialized with general logging setup")

    def initialize_mongodb_connection(self, mongo_uri, mongo_db_name, mongo_collection_name,
                                      prompt_logs_db_name, prompt_logs_collection_name):
        """Initialize MongoDB connection with retry logic"""
        if not mongo_uri:
            self.logger.error("No MongoDB URI provided")
            return False

        for attempt in range(self.max_retries):
            try:
                self.mongo_client = MongoClient(
                    mongo_uri,
                    serverSelectionTimeoutMS=5000,
                    socketTimeoutMS=10000,
                    retryWrites=True,
                    connectTimeoutMS=10000
                )
                self.mongo_client.admin.command('ping')
                self.mongo_db = self.mongo_client[mongo_db_name]
                self.mongo_collection = self.mongo_db[mongo_collection_name]
                self.prompt_logs_db = self.mongo_client[prompt_logs_db_name]
                self.prompt_logs_collection = self.prompt_logs_db[prompt_logs_collection_name]

                # Test insert
                test_doc = {"test_timestamp": datetime.utcnow(), "message": "Connection test"}
                test_result = self.prompt_logs_collection.insert_one(test_doc)
                self.prompt_logs_collection.delete_one({"_id": test_result.inserted_id})

                self.logger.info(f"MongoDB connected on attempt {attempt + 1}")
                return True
            except (ConnectionFailure, OperationFailure) as e:
                self.logger.error(f"MongoDB connection attempt {attempt + 1} failed: {e}")
                if attempt < self.max_retries - 1:
                    time.sleep(2 ** attempt)
                else:
                    self.logger.error("All MongoDB connection attempts failed")
                    return False

    def check_mongodb_health(self):
        """Check if MongoDB connection is healthy"""
        if not self.use_database or self.mongo_client is None:
            return False
        try:
            self.mongo_client.admin.command('ping')
            return self.prompt_logs_collection is not None
        except (ConnectionFailure, OperationFailure) as e:
            self.logger.error(f"MongoDB health check failed: {e}")
            return False

    def ensure_mongodb_connection(self, mongo_uri, mongo_db_name, mongo_collection_name,
                                  prompt_logs_db_name, prompt_logs_collection_name):
        """Ensure MongoDB connection is active"""
        if not self.check_mongodb_health():
            self.logger.warning("MongoDB connection lost, attempting reconnect...")
            return self.initialize_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name,
                                                      prompt_logs_db_name, prompt_logs_collection_name)
        return True

    def _log_to_backup_file(self, log_data):
        """Log to a local file as backup"""
        try:
            backup_dir = os.path.join(os.path.dirname(__file__), "backup_logs")
            os.makedirs(backup_dir, exist_ok=True)
            backup_file = os.path.join(backup_dir, f"prompt_backup_{datetime.utcnow().strftime('%Y%m%d')}.json")
            with open(backup_file, 'a', encoding='utf-8') as f:
                json.dump(log_data, f, ensure_ascii=False, default=str)
                f.write('\n')
            self.logger.info(f"Logged to backup file: {backup_file}")
            return True
        except OSError as e:
            self.logger.error(f"Failed to write to backup file: {e}")
            return False

    def recover_backup_logs(self):
        """Recover logs from backup files to MongoDB"""
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
                                if 'timestamp' in log_data and isinstance(log_data['timestamp'], str):
                                    log_data['timestamp'] = datetime.fromisoformat(log_data['timestamp'])
                                log_data.pop('mongo_error', None)
                                log_data.pop('log_type', None)
                                log_data.pop('backup_logged', None)
                                if self.prompt_logs_collection is not None:  # Fixed line
                                    self.prompt_logs_collection.insert_one(log_data)
                                    recovered_count += 1
                            except json.JSONDecodeError as e:
                                self.logger.error(f"Error recovering log entry: {e}")
                    archived_dir = os.path.join(backup_dir, "archived")
                    os.makedirs(archived_dir, exist_ok=True)
                    shutil.move(file_path, os.path.join(archived_dir, backup_file))
            self.logger.info(f"Recovered {recovered_count} logs from backup files")
            return recovered_count
        except OSError as e:
            self.logger.error(f"Error recovering backup logs: {e}")
            return 0

    def log_prompt_to_mongodb(self, query, response, user_id=None, username=None, session_id=None,
                              client_ip=None, sources=None, error=None, prompt_type="base_enhancement",
                              document_template="standard"):
        """Log prompts to MongoDB with backup"""
        self.logger.debug("log_prompt_to_mongodb called")
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
        self._log_to_backup_file(backup_log)

        if not self.use_database:
            self.logger.debug("use_database is False - skipping MongoDB")
            return False

        if self.prompt_logs_collection is None:
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
            if not self.ensure_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name,
                                                  prompt_logs_db_name, prompt_logs_collection_name):
                self.logger.debug("Reconnection failed - only backup used")
                return False

        try:
            prompt_log = {
                "timestamp": datetime.utcnow(),
                "query": query,
                "response": str(response).encode('utf-8').decode('utf-8') if response else None,
                "user_id": user_id or "anonymous",
                "username": username or "anonymous",
                "session_id": session_id,
                "client_ip": client_ip,
                "sources_count": len(sources) if sources else 0,
                "error": error,
                "metadata": {
                    "model": "incept5/llama3.1-claude:latest",
                    "retrieval_method": "vector_store",
                    "prompt_type": prompt_type,
                    "document_template": document_template,
                    "backup_logged": True,
                    "debug_timestamp": datetime.utcnow().isoformat()
                }
            }
            if sources:
                source_hashes = [source['metadata']['doc_hash'] for source in sources if 'metadata' in source and 'doc_hash' in source['metadata']]
                prompt_log["source_document_hashes"] = source_hashes

            result = self.prompt_logs_collection.insert_one(prompt_log)
            self.logger.info(f"Logged chat to chat_logs.conversations with ID: {result.inserted_id}")
            return True
        except (ConnectionFailure, OperationFailure) as e:
            self.logger.error(f"Error logging chat: {e}")
            backup_log["mongo_error"] = str(e)
            backup_log["mongo_error_type"] = type(e).__name__
            self._log_to_backup_file(backup_log)
            return False

    def log_to_mongodb(self, data, processed_hashes, save_processed_hashes_func):
        """Log sensor data to MongoDB"""
        try:
            if not self.use_database or self.mongo_collection is None:
                self.logger.error("MongoDB not initialized; cannot log sensor data")
                return False

            doc_hash = self._generate_document_hash(data)
            if doc_hash in processed_hashes:
                self.logger.info(f"Skipping duplicate sensor document with hash {doc_hash}")
                return False

            mongo_doc = data.copy()
            if 'timestamp' in mongo_doc:
                try:
                    mongo_doc['timestamp'] = pd.to_datetime(mongo_doc['timestamp'])
                except ValueError:
                    self.logger.warning(f"Could not convert timestamp: {mongo_doc['timestamp']}")

            mongo_doc['doc_hash'] = doc_hash
            mongo_doc['created_at'] = datetime.utcnow()

            self.mongo_collection.insert_one(mongo_doc)
            processed_hashes.add(doc_hash)
            save_processed_hashes_func()
            self.logger.info(f"Logged sensor data with hash {doc_hash}")
            return True
        except (ConnectionFailure, OperationFailure) as e:
            self.logger.error(f"Error logging sensor data: {e}")
            return False

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