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
from database_adapter import DatabaseAdapter
from pymongo import MongoClient
from dotenv import load_dotenv
from prompts_config import PromptsConfig
from advanced_llm_handlers import AdvancedLLMHandlers
from room_specific_handlers import RoomSpecificHandlers
import sys
from pathlib import Path

from logging_manager import LoggingManager

# FIXED: Correct path resolution
BASE_DIR = Path(__file__).resolve().parent  # Points to llm/static_remote_LLM/
PROJECT_ROOT = BASE_DIR.parent.parent  # Points to SBMS-Y3S1G4/

# Instantiate global logger_manager for early debug logs
logger_manager = LoggingManager(project_root=PROJECT_ROOT)
logger = logger_manager.logger  # Global logger

logger.debug(f"BASE_DIR: {BASE_DIR}")
logger.debug(f"PROJECT_ROOT: {PROJECT_ROOT}")

# Add SBMS-Y3S1G4/api/ to sys.path
sys.path.append(str(PROJECT_ROOT / 'api'))

# Set DJANGO_SETTINGS_MODULE
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')

# FIXED: Load environment variables from .env in the correct project directory
env_path = PROJECT_ROOT / ".env"
logger.debug(f"Looking for .env at: {env_path}")
if os.path.exists(env_path):
    load_dotenv(dotenv_path=env_path)
    logger.debug(f"Successfully loaded .env from {env_path}")
else:
    # Reduced alternative paths for efficiency
    alternative_paths = [
        BASE_DIR / ".env", 
        Path.cwd() / ".env"
    ]
    for alt_path in alternative_paths:
        logger.debug(f"Trying alternative path: {alt_path}")
        if os.path.exists(alt_path):
            load_dotenv(dotenv_path=alt_path)
            logger.debug(f"Successfully loaded .env from {alt_path}")
            break
    else:
        logger.warning("No .env file found in any location")

logger.debug(f"MONGO_ATLAS_URI: {os.getenv('MONGO_ATLAS_URI')}")

def debug_environment(debug=False):
    """Debug function to check environment variables"""
    if not debug:
        return
    logger.debug("=== ENVIRONMENT DEBUG ===")
    logger.debug(f"Current file: {__file__}")
    logger.debug(f"BASE_DIR: {BASE_DIR}")
    logger.debug(f"PROJECT_ROOT: {PROJECT_ROOT}")
    logger.debug(f"Current working directory: {os.getcwd()}")
    logger.debug(f"MONGO_ATLAS_URI exists: {bool(os.getenv('MONGO_ATLAS_URI'))}")
    
    # List files in project root to verify structure
    try:
        files_in_root = os.listdir(PROJECT_ROOT)
        logger.debug(f"Files in project root: {files_in_root}")
    except OSError as e:
        logger.debug(f"Could not list project root: {e}")

class RoomLogAnalyzer:
    def __init__(self, chroma_dir=None, use_database=True,
                 mongo_uri=None, mongo_db_name=None, mongo_collection_name=None,
                 prompt_logs_db_name=None, prompt_logs_collection_name=None,
                 prompts_config_file=None, prompt_type="base_enhancement",
                 document_template="standard"):
        # Run environment debug only if needed
        debug_environment(debug=False)  # Set to True for debugging
        
        # Dynamically set paths relative to llm/static_remote_LLM/
        script_dir = os.path.dirname(os.path.abspath(__file__))
        self.chroma_dir = chroma_dir or os.path.join(script_dir, "chroma_room_logs")
        self.use_database = use_database
        self.vector_store = None
        self.qa_chain = None
        self.processed_hashes = set()
        self.df = None
        self.maintenance_df = None
        self.db_adapter = None

        # Initialize logging manager (replaces all logging init)
        self.logger_manager = LoggingManager(
            project_root=PROJECT_ROOT,
            use_database=use_database,
            mongo_uri=mongo_uri or os.getenv("MONGO_ATLAS_URI"),
            mongo_db_name=mongo_db_name or os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=mongo_collection_name or os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=prompt_logs_db_name or os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs"),
            prompt_logs_collection_name=prompt_logs_collection_name or os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
        )
        self.logger = self.logger_manager.logger  # Use this for class logging

        # Optional: Recover backups on init
        self.logger_manager.recover_backup_logs()

        # Initialize prompts configuration
        config_path = prompts_config_file or os.path.join(script_dir, "custom_prompts.json")
        self.prompts = PromptsConfig(config_path if os.path.exists(config_path) else None)
        self.prompt_type = prompt_type
        self.document_template = document_template
        self.logger.info(f"Using prompt type: {prompt_type}")
        self.logger.info(f"Using document template: {document_template}")

        # Initialize database adapters
        if self.use_database:
            try:
                self.db_adapter = DatabaseAdapter()
                self.logger.info("PostgreSQL database adapter initialized successfully")
            except Exception as e:
                self.logger.error(f"Failed to initialize PostgreSQL adapter: {e}")
                self.db_adapter = None
                self.logger.warning("Continuing without PostgreSQL database connection")

        # FIXED: Initialize advanced handlers with database adapter
        self.advanced_handlers = AdvancedLLMHandlers(self.prompts, self.db_adapter)
        self.room_handlers = None

        self._load_processed_hashes()

        if self.use_database and self.db_adapter:
            try:
                self.room_handlers = RoomSpecificHandlers(self.prompts, self.db_adapter)
                self.logger.info("Room-specific handlers initialized successfully")
            except Exception as e:
                self.logger.error(f"Failed to initialize room handlers: {e}")
                self.room_handlers = None
        else:
            self.logger.warning("No database adapter available, room-specific handlers not initialized")

    def _load_processed_hashes(self):
        """Load hashes of already processed documents to avoid duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        if os.path.exists(hash_file):
            try:
                with open(hash_file, 'r', encoding='utf-8') as f:
                    self.processed_hashes = set(line.strip() for line in f)
                self.logger.info(f"Loaded {len(self.processed_hashes)} existing document hashes")
            except OSError as e:
                self.logger.error(f"Error loading processed hashes: {e}")

    def _save_processed_hashes(self):
        """Save hashes of processed documents to avoid future duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        try:
            os.makedirs(os.path.dirname(hash_file), exist_ok=True)
            with open(hash_file, 'w', encoding='utf-8') as f:
                for h in self.processed_hashes:
                    f.write(h + '\n')
        except OSError as e:
            self.logger.error(f"Error saving processed hashes: {e}")

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

    def load_from_postgresql(self, limit=None):
        """Load data from PostgreSQL and return as a DataFrame"""
        try:
            if self.db_adapter is None:
                self.logger.error("PostgreSQL adapter not initialized; cannot load data")
                return None

            df = self.db_adapter.get_sensor_data_as_dataframe(limit=limit)
            if df is None:
                self.logger.warning("PostgreSQL returned no data")
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

            self.logger.info(f"Loaded {len(df)} unique occupied room records from PostgreSQL")
            return df
        except Exception as e:
            self.logger.error(f"Error loading from PostgreSQL: {e}")
            return None

    def load_maintenance_data(self, limit=None):
        """Load maintenance data from PostgreSQL"""
        try:
            if self.db_adapter is None:
                self.logger.error("PostgreSQL adapter not initialized; cannot load maintenance data")
                return None

            # Try using Django ORM first (more reliable)
            df = self.db_adapter.get_maintenance_requests_using_django(limit=limit)
            
            # If Django ORM fails, try direct SQL
            if df is None or df.empty:
                self.logger.info("Trying direct SQL for maintenance data")
                df = self.db_adapter.get_maintenance_requests_as_dataframe(limit=limit)

            if df is None or df.empty:
                self.logger.warning("No maintenance data loaded from PostgreSQL")
                return None

            self.logger.info(f"Loaded {len(df)} maintenance requests from PostgreSQL")
            if not df.empty:
                self.logger.info(f"Maintenance data sample: {df[['issue_description', 'status', 'requested_date']].head(2).to_dict('records')}")
            return df
        except Exception as e:
            self.logger.error(f"Error loading maintenance data: {e}")
            return None

    def _create_maintenance_document(self, row):
        """Create a document from maintenance request data"""
        try:
            # Format dates properly
            requested_date = row['requested_date']
            if hasattr(requested_date, 'strftime'):
                requested_date = requested_date.strftime("%Y-%m-%d")
            
            resolved_date = row['resolved_date']
            if resolved_date and hasattr(resolved_date, 'strftime'):
                resolved_date = resolved_date.strftime("%Y-%m-%d")
            else:
                resolved_date = "Not resolved"
                
            created_at = row['created_at']
            if hasattr(created_at, 'strftime'):
                created_at = created_at.strftime("%Y-%m-%d %H:%M:%S")

            template = """
            Maintenance Request: {issue_description}
            Status: {status}
            Scheduled Date: {requested_date}
            Resolved Date: {resolved_date}
            Created At: {created_at}
            Equipment ID: {equipment_id}
            Requested By: {requested_by}
            Assigned To: {assigned_to}
            Notes: {notes}
            """
            
            page_content = template.format(
                issue_description=row['issue_description'],
                status=row['status'],
                requested_date=requested_date,
                resolved_date=resolved_date,
                created_at=created_at,
                equipment_id=row.get('equipment_id', 'No equipment'),
                requested_by=row.get('requested_by_id', 'Unknown'),
                assigned_to=row.get('assigned_to_id', 'Not assigned'),
                notes=row.get('notes') or "No additional notes"
            )

            doc_hash = hashlib.md5(page_content.encode()).hexdigest()
            
            return Document(
                page_content=page_content,
                metadata={
                    "type": "maintenance",
                    "status": row['status'],
                    "requested_date": requested_date,
                    "resolved_date": resolved_date,
                    "equipment_id": row.get('equipment_id'),
                    "doc_hash": doc_hash
                }
            )
        except Exception as e:
            self.logger.error(f"Error creating maintenance document: {e}")
            return None

    def load_and_process_data(self, force_reload=False, limit=None, include_maintenance=True):
        """Load and process both sensor data and maintenance data"""
        if not force_reload and self.df is not None:
            self.logger.info("Using cached DataFrame")
            return self.df

        try:
            if not self.use_database or self.db_adapter is None:
                self.logger.warning("Database not initialized; returning empty DataFrame")
                self.df = pd.DataFrame()
                return self.df

            self.logger.info("Loading sensor data from PostgreSQL")
            sensor_df = self.load_from_postgresql(limit=limit)
            
            # Load maintenance data if requested
            maintenance_df = None
            if include_maintenance:
                self.logger.info("Loading maintenance data from PostgreSQL")
                maintenance_df = self.load_maintenance_data(limit=limit)

            # Combine or use sensor data as primary
            self.df = sensor_df if sensor_df is not None else pd.DataFrame()
            self.maintenance_df = maintenance_df

            # Log sensor data to MongoDB (existing code)
            if self.use_database and sensor_df is not None and not sensor_df.empty:
                new_docs = []
                for _, row in sensor_df.iterrows():
                    doc_hash = self._generate_document_hash(row)
                    if doc_hash not in self.processed_hashes:
                        mongo_doc = row.to_dict()
                        if 'timestamp' in mongo_doc:
                            try:
                                mongo_doc['timestamp'] = pd.to_datetime(mongo_doc['timestamp'])
                            except ValueError:
                                self.logger.warning(f"Could not convert timestamp: {mongo_doc['timestamp']}")
                        mongo_doc['doc_hash'] = doc_hash
                        mongo_doc['created_at'] = datetime.utcnow()
                        new_docs.append(mongo_doc)
                        self.processed_hashes.add(doc_hash)
                
                if new_docs:
                    for doc in new_docs:
                        self.logger_manager.log_to_mongodb(doc, self.processed_hashes, self._save_processed_hashes)
                    self.logger.info(f"Batch logged {len(new_docs)} new sensor records to MongoDB")
                    self._save_processed_hashes()
                else:
                    self.logger.info("No new sensor records to log to MongoDB (all duplicates)")

            return self.df

        except Exception as e:
            self.logger.error(f"Error loading data: {e}")
            self.df = pd.DataFrame()
            return self.df

    def _create_document_from_row(self, row):
        try:
            timestamp_str = row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        except AttributeError:
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

    def create_documents(self, df, include_maintenance=True):
        """Convert DataFrame rows into LangChain Documents with deduplication"""
        documents = []
        new_document_count = 0

        # Create sensor documents (existing code)
        for _, row in df.iterrows():
            doc_hash = self._generate_document_hash(row)
            if doc_hash in self.processed_hashes:
                self.logger.debug(f"Skipping duplicate sensor document with hash {doc_hash}")
                continue

            doc = self._create_document_from_row(row)
            documents.append(doc)
            self.processed_hashes.add(doc_hash)
            new_document_count += 1

        # Create maintenance documents
        if include_maintenance and hasattr(self, 'maintenance_df') and self.maintenance_df is not None:
            for _, row in self.maintenance_df.iterrows():
                doc = self._create_maintenance_document(row)
                if doc and doc.metadata['doc_hash'] not in self.processed_hashes:
                    documents.append(doc)
                    self.processed_hashes.add(doc.metadata['doc_hash'])
                    new_document_count += 1

        self.logger.info(f"Created {new_document_count} new documents ({len(documents) - new_document_count} maintenance), skipped {len(df) - new_document_count} duplicates")
        return documents

    def initialize_vector_store(self, documents, reset=False):
        """Initialize or load the vector store with documents"""
        try:
            if reset and os.path.exists(self.chroma_dir):
                self.logger.info("Resetting vector store")
                shutil.rmtree(self.chroma_dir)
                self.processed_hashes.clear()
                self._save_processed_hashes()

            if os.path.exists(self.chroma_dir) and os.listdir(self.chroma_dir) and not reset:
                self.logger.info("Loading existing vector store")
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
                    self.logger.info(f"Adding {len(new_documents)} new documents to existing vector store")
                    vector_store.add_documents(new_documents)
                    vector_store.persist()
                else:
                    self.logger.info("No new documents to add to vector store")
            else:
                self.logger.info("Creating new vector store")
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
            self.logger.error(f"Error initializing vector store: {e}")
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
            self.logger.info("QA chain initialized successfully")
        except ValueError as e:
            self.logger.error(f"Error initializing QA chain: {e}")
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
            rooms = []  # Added to collect rooms
            for _, row in matching_rows.iterrows():
                try:
                    timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                except AttributeError:
                    timestamps.append(str(row["timestamp"]))
                if 'room_name' in row:
                    rooms.append(row["room_name"])

            sources = self._get_source_documents_for_rows(matching_rows.head(2))
            all_sources.extend(sources)
            col_display = col.split('.')[-1]
            room_str = f" in room(s) {', '.join(set(rooms))}" if rooms else ""  # Added room info
            results.append(f"The {op_word} {col_display} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}{room_str}")

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
                    max_rows = df[col] == max_value
                    min_timestamps = []
                    min_rooms = []
                    max_timestamps = []
                    max_rooms = []
                    for _, row in min_rows.iterrows():
                        try:
                            min_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except AttributeError:
                            min_timestamps.append(str(row["timestamp"]))
                        if 'room_name' in row:
                            min_rooms.append(row["room_name"])
                    for _, row in max_rows.iterrows():
                        try:
                            max_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except AttributeError:
                            max_timestamps.append(str(row["timestamp"]))
                        if 'room_name' in row:
                            max_rooms.append(row["room_name"])
                    sources = self._get_source_documents_for_rows(pd.concat([min_rows.head(2), max_rows.head(2)]))
                    min_room_str = f" in room(s) {', '.join(set(min_rooms))}" if min_rooms else ""
                    max_room_str = f" in room(s) {', '.join(set(max_rooms))}" if max_rooms else ""
                    return {
                        "answer": f"The lowest {key} is {min_value} at {', '.join(min_timestamps[:2])}{min_room_str}. "
                                  f"The highest {key} is {max_value} at {', '.join(max_timestamps[:2])}{max_room_str}.",
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
                rooms = []  # Added
                for _, row in matching_rows.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except AttributeError:
                        timestamps.append(str(row["timestamp"]))
                    if 'room_name' in row:
                        rooms.append(row["room_name"])
                sources = self._get_source_documents_for_rows(matching_rows.head(3))
                room_str = f" in room(s) {', '.join(set(rooms))}" if rooms else ""  # Added
                return {
                    "answer": f"The {op_word} {key} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}{room_str}.",
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

    def _handle_maintenance_query(self, query, q_lower, user_id=None, username=None, session_id=None, client_ip=None):
        """Handle maintenance-related queries"""
        try:
            self.logger.info(f"Matched maintenance query: '{query}'")
            
            # Ensure maintenance data is loaded
            if not hasattr(self, 'maintenance_df') or self.maintenance_df is None or self.maintenance_df.empty:
                self.load_and_process_data(force_reload=True, include_maintenance=True)
                
            if not hasattr(self, 'maintenance_df') or self.maintenance_df is None or self.maintenance_df.empty:
                return {
                    "answer": "No maintenance data is currently available in the system.",
                    "sources": []
                }

            # Handle different types of maintenance queries
            if "pending" in q_lower or "open" in q_lower:
                pending_issues = self.maintenance_df[self.maintenance_df['status'] == 'pending']
                if not pending_issues.empty:
                    issues_list = []
                    for _, issue in pending_issues.head(5).iterrows():
                        issues_list.append(f"- {issue['issue_description']} (Scheduled: {issue['requested_date']})")
                    answer = f"There are {len(pending_issues)} pending maintenance issues:\n" + "\n".join(issues_list)
                    if len(pending_issues) > 5:
                        answer += f"\n... and {len(pending_issues) - 5} more issues."
                else:
                    answer = "No pending maintenance issues found."
                    
            elif "resolved" in q_lower or "fixed" in q_lower:
                resolved_issues = self.maintenance_df[self.maintenance_df['status'] == 'resolved']
                if not resolved_issues.empty:
                    answer = f"There are {len(resolved_issues)} resolved maintenance issues."
                else:
                    answer = "No resolved maintenance issues found."
                    
            else:
                # General maintenance query
                total_issues = len(self.maintenance_df)
                pending_count = len(self.maintenance_df[self.maintenance_df['status'] == 'pending'])
                resolved_count = len(self.maintenance_df[self.maintenance_df['status'] == 'resolved'])
                
                answer = f"There are {total_issues} maintenance requests: {pending_count} pending and {resolved_count} resolved."
                
                # Add some recent issues for context
                recent_issues = self.maintenance_df.head(3)
                if not recent_issues.empty:
                    answer += "\nRecent issues:"
                    for _, issue in recent_issues.iterrows():
                        status_icon = "⏳" if issue['status'] == 'pending' else "✅"
                        answer += f"\n{status_icon} {issue['issue_description']}"

            # Create source documents from maintenance data
            sample_maintenance = self.maintenance_df.head(2)
            sources = []
            for _, row in sample_maintenance.iterrows():
                doc = self._create_maintenance_document(row)
                if doc:
                    sources.append({
                        "page_content": doc.page_content,
                        "metadata": dict(doc.metadata)
                    })

            result = {
                "answer": answer,
                "sources": sources
            }
            
            # PROMPT LOGGING
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=result["answer"],
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                sources=result.get("sources", []),
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return result
            
        except Exception as e:
            self.logger.error(f"Error in maintenance handler: {e}")
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                error=f"Maintenance handler failed: {str(e)}",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"error": str(e)}

    def _handle_deterministic_query(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Handle specific queries deterministically to avoid hallucinations - FIXED LOGGING"""
        q_lower = query.lower().strip()
        df = self.load_and_process_data(include_maintenance=True)
        if df is None or df.empty:
            self.logger.error("DataFrame is empty or None; cannot process query")
            # LOG THE ERROR
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id,
                username=username,
                session_id=session_id,
                client_ip=client_ip,
                error="No data available",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"answer": "No data available to process the query.", "sources": []}

        self.logger.info(f"Processing deterministic query: '{q_lower}'")

        # MAINTENANCE QUERIES - ADDED THIS SECTION
        if any(keyword in q_lower for keyword in ["maintenance", "repair", "issue", "fault", "broken", "malfunction"]):
            maintenance_result = self._handle_maintenance_query(query, q_lower, user_id, username, session_id, client_ip)
            if maintenance_result:
                return maintenance_result

        # ROOM-SPECIFIC HANDLERS
        if self.room_handlers and any(keyword in q_lower for keyword in ["room", "for room", "in room"]):
            try:
                room_result = self.room_handlers.handle_room_specific_query(query)
                if room_result and "error" not in room_result:
                    self.logger.info(f"Used room-specific handler for query: '{query}'")
                    # PROMPT LOGGING: Always log deterministic results
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=room_result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=room_result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return room_result
                elif "error" in room_result:
                    self.logger.warning(f"Room-specific handler error: {room_result['error']}")
                    # LOG THE ERROR
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=room_result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return room_result
            except Exception as e:
                self.logger.error(f"Error in room-specific handler: {e}")
                # LOG THE ERROR
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Room-specific handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # KPI QUERIES
        if any(keyword in q_lower for keyword in ["key performance indicators", "kpi", "performance metrics"]):
            try:
                self.logger.info(f"Matched KPI query: '{query}'")
                result = self.advanced_handlers.handle_kpi_query(df)
                if "error" in result:
                    self.logger.error(f"KPI query failed: {result['error']}")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in KPI handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"KPI handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # MOST USED ROOM QUERIES
        if any(keyword in q_lower for keyword in ["most used room", "room usage", "room utilization"]):
            try:
                self.logger.info(f"Matched most used room query: '{query}'")
                result = self.advanced_handlers.handle_most_used_room_query(df)
                if "error" in result:
                    self.logger.error(f"Most used room query failed: {result['error']}")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in most used room handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Most used room handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # ENERGY TREND QUERIES
        if any(keyword in q_lower for keyword in ["energy trend", "energy pattern", "consumption trend", "analyze energy usage patterns", "energy usage patterns"]):
            try:
                self.logger.info(f"Matched energy trend query: '{query}'")
                result = self.advanced_handlers.handle_energy_trends_query(df)
                if "error" in result:
                    self.logger.error(f"Energy trend query failed: {result['error']}")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in energy trend handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Energy trend handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # WEEKLY SUMMARY QUERIES - FIXED
        if any(keyword in q_lower for keyword in ["weekly summary", "weekly report", "summary", "show me weekly summary", "generate weekly summary"]):
            try:
                self.logger.info(f"Attempting to generate weekly summary for query: '{query}'")
                result = self.advanced_handlers.generate_weekly_summary(df)
                if "error" in result:
                    self.logger.error(f"Weekly summary generation failed: {result['error']}")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                self.logger.info(f"Weekly summary generated: {result['answer'][:100]}...")
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in weekly summary handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Weekly summary handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": f"Failed to generate weekly summary: {str(e)}"}

        # ANOMALY DETECTION QUERIES
        if any(keyword in q_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            try:
                self.logger.info(f"Matched anomaly detection query: '{query}'")
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
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in anomaly detection handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Anomaly detection handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # CONTEXT-AWARE QUERIES
        if any(keyword in q_lower for keyword in ["context", "current", "situation", "status"]):
            try:
                self.logger.info(f"Matched context-aware query: '{query}'")
                result = self.advanced_handlers.handle_context_aware_query(query, df)
                if "error" in result:
                    self.logger.error(f"Context-aware query failed: {result['error']}")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error=result["error"],
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in context-aware handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Context-aware handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # ALL READINGS QUERIES
        if any(keyword in q_lower for keyword in ["all readings", "all logs", "all records", "all room_logs"]):
            try:
                self.logger.info(f"Matched all readings query: '{query}'")
                timestamps = []
                for _, row in df.iterrows():
                    try:
                        timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                    except AttributeError:
                        timestamps.append(str(row["timestamp"]))
                sources = self._get_source_documents_for_rows(df.sample(min(3, len(df))))
                result = {
                    "answer": f"The room logs contain {len(timestamps)} occupied readings: {', '.join(timestamps[:5])}{'...' if len(timestamps) > 5 else ''}.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in all readings handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"All readings handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # RECORD COUNT QUERIES
        if "how many" in q_lower and any(keyword in q_lower for keyword in ["record", "data", "log"]):
            try:
                self.logger.info(f"Matched record count query: '{query}'")
                count = len(df)
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are {count} occupied room records in the dataset.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in record count handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Record count handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # PEOPLE COUNT QUERIES
        if "how many" in q_lower and "people" in q_lower:
            try:
                self.logger.info(f"Matched people count query: '{query}'")
                total_people = int(df["occupancy_count"].sum())
                sample_df = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_df)
                result = {
                    "answer": f"There are a total of {total_people} people across all occupied room records.",
                    "sources": sources
                }
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=sources,
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return result
            except Exception as e:
                self.logger.error(f"Error in people count handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"People count handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # POWER CONSUMPTION BREAKDOWN QUERIES
        if "power consumption breakdown" in q_lower or "power breakdown" in q_lower:
            try:
                self.logger.info(f"Matched power breakdown query: '{query}'")
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
                            self.logger_manager.log_prompt_to_mongodb(
                                query=query,
                                response=result["answer"],
                                user_id=user_id,
                                username=username,
                                session_id=session_id,
                                client_ip=client_ip,
                                sources=sources,
                                prompt_type=self.prompt_type,
                                document_template=self.document_template
                            )
                            return result
                    except ValueError:
                        self.logger.warning(f"Invalid timestamp format in query: {target_timestamp}")
                self.logger.warning("No valid timestamp found for power breakdown query")
                # LOG THE FAILURE
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error="No valid timestamp found for power breakdown",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": "No valid timestamp found for power breakdown query"}
            except Exception as e:
                self.logger.error(f"Error in power breakdown handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Power breakdown handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # MIXED QUERIES
        mixed_result = self._handle_mixed_query(q_lower, df)
        if mixed_result:
            try:
                self.logger.info(f"Matched mixed query: '{query}'")
                # PROMPT LOGGING: Always log deterministic results
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=mixed_result["answer"],
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    sources=mixed_result.get("sources", []),
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return mixed_result
            except Exception as e:
                self.logger.error(f"Error in mixed query handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Mixed query handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        # MIN/MAX QUERIES
        has_lowest = "lowest" in q_lower or "minimum" in q_lower or "min " in q_lower
        has_highest = "highest" in q_lower or "maximum" in q_lower or "max " in q_lower

        if has_lowest and has_highest:
            try:
                self.logger.info(f"Matched combined min/max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "combined")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    self.logger.warning("No result for combined min/max query")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for combined min/max query",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"error": "No result for combined min/max query"}
            except Exception as e:
                self.logger.error(f"Error in combined min/max handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Combined min/max handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}
        elif has_lowest:
            try:
                self.logger.info(f"Matched min query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "min")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    self.logger.warning("No result for min query")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for min query",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"error": "No result for min query"}
            except Exception as e:
                self.logger.error(f"Error in min handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Min handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}
        elif has_highest:
            try:
                self.logger.info(f"Matched max query: '{query}'")
                result = self._handle_min_max_query(q_lower, df, "max")
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    self.logger.warning("No result for max query")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for max query",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"error": "No result for max query"}
            except Exception as e:
                self.logger.error(f"Error in max handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Max handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}
        elif "average" in q_lower or "mean" in q_lower:
            try:
                self.logger.info(f"Matched average query: '{query}'")
                result = self._handle_avg_query(q_lower, df)
                if result:
                    # PROMPT LOGGING: Always log deterministic results
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=result["answer"],
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        sources=result.get("sources", []),
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return result
                else:
                    self.logger.warning("No result for average query")
                    self.logger_manager.log_prompt_to_mongodb(
                        query=query,
                        response=None,
                        user_id=user_id,
                        username=username,
                        session_id=session_id,
                        client_ip=client_ip,
                        error="No result for average query",
                        prompt_type=self.prompt_type,
                        document_template=self.document_template
                    )
                    return {"error": "No result for average query"}
            except Exception as e:
                self.logger.error(f"Error in average handler: {e}")
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id,
                    username=username,
                    session_id=session_id,
                    client_ip=client_ip,
                    error=f"Average handler failed: {str(e)}",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"error": str(e)}

        self.logger.warning(f"No deterministic match for query: '{q_lower}'; falling back to LLM")
        self.logger_manager.log_prompt_to_mongodb(
            query=query,
            response=None,
            user_id=user_id,
            username=username,
            session_id=session_id,
            client_ip=client_ip,
            error="No deterministic match, falling back to LLM",
            prompt_type=self.prompt_type,
            document_template=self.document_template
        )
        return None

    def _enhance_query_for_llm(self, query):
        """Add context and instructions to reduce hallucinations using configurable prompts"""
        system_prompt = self.prompts.get_system_prompt(self.prompt_type)
        return system_prompt.format(query=query)

    def ask(self, query, user_id=None, username=None, session_id=None, client_ip=None):
        """Ask a question about the room logs with robust logging - FIXED VERSION"""
        self.logger.info(f"Processing ask request for query: '{query}' with user_id: {user_id}, username: {username}")
        
        # Ensure MongoDB connection before processing
        if self.use_database:
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "chat_logs")
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "conversations")
            self.logger_manager.ensure_mongodb_connection(mongo_uri, mongo_db_name, mongo_collection_name,
                                                          prompt_logs_db_name, prompt_logs_collection_name)
        
        if not self.qa_chain:
            self.logger.error("QA chain not initialized")
            # PROMPT LOGGING: Always log errors
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error="QA chain not initialized",
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return {"error": "QA chain not initialized. Please initialize the analyzer."}

        try:
            # Load data but don't let document duplication affect prompt logging
            df = self.load_and_process_data(include_maintenance=True)
            if df is None or df.empty:
                self.logger.warning("No data available for processing query")
                # PROMPT LOGGING: Always log no data scenario
                self.logger_manager.log_prompt_to_mongodb(
                    query=query,
                    response=None,
                    user_id=user_id or "anonymous",
                    username=username or "anonymous",
                    session_id=session_id,
                    client_ip=client_ip,
                    error="No data available",
                    prompt_type=self.prompt_type,
                    document_template=self.document_template
                )
                return {"answer": "No data available to process the query.", "sources": []}

            # Update vector store with any new documents, but continue even if no new documents
            documents = self.create_documents(df, include_maintenance=True)
            if documents:
                self.logger.info(f"Adding {len(documents)} new documents due to data changes")
                if self.vector_store is None:
                    self.initialize_vector_store(documents)
                else:
                    self.vector_store.add_documents(documents)
                    self.vector_store.persist()
                self._save_processed_hashes()
            else:
                self.logger.info("No new documents to add to vector store - using existing knowledge")

            # Try deterministic handlers first
            deterministic_result = self._handle_deterministic_query(query, user_id, username, session_id, client_ip)
            if deterministic_result:
                self.logger.info(f"Used deterministic handler for query: '{query}'")
                # Note: Prompt logging already handled inside _handle_deterministic_query
                return deterministic_result

            # Fall back to LLM for complex queries
            enhanced_query = self._enhance_query_for_llm(query)
            result = self.qa_chain({"query": enhanced_query})
            self.logger.info(f"Query: '{query}' - Response generated using LLM")

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

            # PROMPT LOGGING: Always log LLM responses
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=validated_answer,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                sources=unique_source_docs,
                prompt_type=self.prompt_type,
                document_template=self.document_template
            )
            return response

        except Exception as e:
            self.logger.error(f"Error processing query '{query}': {e}")
            # PROMPT LOGGING: Always log errors
            self.logger_manager.log_prompt_to_mongodb(
                query=query,
                response=None,
                user_id=user_id or "anonymous",
                username=username or "anonymous",
                session_id=session_id,
                client_ip=client_ip,
                error=f"Query processing failed: {str(e)}",
                prompt_type=self.prompt_type,
                document_template=self.document_template
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
                except ValueError:
                    continue
        return response

# Initialize the analyzer globally
analyzer = None

def initialize_analyzer(reset_vector_store=False):
    global analyzer
    try:
        logger.info("Starting analyzer initialization with MongoDB Atlas")
        
        # Test MongoDB connection first
        mongo_uri = os.getenv("MONGO_ATLAS_URI")
        if not mongo_uri:
            logger.error("MONGO_ATLAS_URI not found in environment")
            return False

        try:
            client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            client.admin.command('ping')
            client.close()
        except (ConnectionFailure, OperationFailure) as e:
            logger.error(f"MongoDB connection test failed: {e}")
            return False

        # Set Django environment
        os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'dbmsAPI.settings')
        import django
        django.setup()
        logger.info("Django environment initialized")

        analyzer = RoomLogAnalyzer(
            use_database=True,
        )
        logger.info("RoomLogAnalyzer instance created")
        df = analyzer.load_and_process_data(include_maintenance=True)
        logger.info(f"Data loaded, rows: {len(df) if df is not None else 0}")
        if df is None or df.empty:
            logger.warning("DataFrame is empty or None; check data sources")
            raise ValueError("No valid data to process")
        documents = analyzer.create_documents(df, include_maintenance=True)
        logger.info(f"Documents created: {len(documents)}")
        analyzer.initialize_vector_store(documents, reset=reset_vector_store)
        logger.info("Vector store initialized")
        analyzer.initialize_qa_chain()
        logger.info("QA chain initialized")
        logger.info("Analyzer initialized successfully with MongoDB Atlas")
        return True
    except ValueError as e:
        logger.error(f"Error initializing analyzer: {e}")
        return False

def ask(query, user_id=None, username=None, session_id=None, client_ip=None):
    """Public function to ask questions"""
    global analyzer
    logger.info(f"Calling ask with query: '{query}', user_id: {user_id}, username: {username}")
    if analyzer is None:
        if not initialize_analyzer():
            logger.error("Analyzer initialization failed")
            return {"error": "Analyzer not initialized"}
    try:
        result = analyzer.ask(query, user_id=user_id, username=username, session_id=session_id, client_ip=client_ip)
        return result
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return {"error": str(e)}

# Test block
if __name__ == "__main__":
    debug_environment(debug=True)
    
    if initialize_analyzer(reset_vector_store=False):
        queries = [
            "What is the highest temperature?",
            "Show me the weekly summary", 
            "What is the room status?",
            "Check for maintenance issues",
            "Show me pending maintenance requests"
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