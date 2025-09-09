import pandas as pd
import os
import hashlib
from datetime import datetime
from langchain_core.documents import Document
from langchain.chains import RetrievalQA
from langchain_ollama import OllamaEmbeddings
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma
import logging
import shutil
import re
from database_adapter import DatabaseAdapter
from pymongo import MongoClient
from dotenv import load_dotenv
from prompts_config import PromptsConfig
from advanced_llm_handlers import AdvancedLLMHandlers
from room_specific_handlers import RoomSpecificHandlers

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("room_analysis.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class RoomLogAnalyzer:
    def __init__(self, chroma_dir=None, use_database=True,
                 mongo_uri=None, mongo_db_name=None, mongo_collection_name=None,
                 prompt_logs_db_name=None, prompt_logs_collection_name=None,
                 prompts_config_file=None, prompt_type="base_enhancement",
                 document_template="standard"):
        # Dynamically set paths relative to the script location
        script_dir = os.path.dirname(os.path.abspath(__file__))
        self.chroma_dir = chroma_dir or os.path.join(script_dir, "chroma_room_logs")
        self.use_database = use_database
        self.vector_store = None
        self.qa_chain = None
        self.processed_hashes = set()
        self.df = None  # Cache the dataframe
        self.db_adapter = None
        self.mongo_client = None
        self.mongo_db = None
        self.mongo_collection = None
        
        # Prompt logging setup
        self.prompt_logs_db = None
        self.prompt_logs_collection = None
        
        # Initialize prompts configuration
        config_path = prompts_config_file or os.path.join(script_dir, "custom_prompts.json")
        self.prompts = PromptsConfig(config_path if os.path.exists(config_path) else None)
        self.prompt_type = prompt_type
        self.document_template = document_template
        
        logger.info(f"Using prompt type: {prompt_type}")
        logger.info(f"Using document template: {document_template}")
        
        # Initialize advanced handlers
        self.advanced_handlers = AdvancedLLMHandlers(self.prompts)
        
        # Room handlers will be initialized after database setup
        self.room_handlers = None
        
        # Load environment variables if not provided
        if mongo_uri is None:
            mongo_uri = os.getenv("MONGO_ATLAS_URI")
        if mongo_db_name is None:
            mongo_db_name = os.getenv("MONGO_DB_NAME", "LLM_logs")
        if mongo_collection_name is None:
            mongo_collection_name = os.getenv("MONGO_COLLECTION_NAME", "logs")
        if prompt_logs_db_name is None:
            prompt_logs_db_name = os.getenv("PROMPT_LOGS_DB_NAME", "prompt_logs")
        if prompt_logs_collection_name is None:
            prompt_logs_collection_name = os.getenv("PROMPT_LOGS_COLLECTION_NAME", "queries")
        
        # Initialize database adapters
        if self.use_database:
            try:
                self.db_adapter = DatabaseAdapter()
                logger.info("PostgreSQL database adapter initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize PostgreSQL adapter: {e}")
                raise ValueError(f"PostgreSQL database connection required but failed: {e}")
            
            try:
                if mongo_uri:
                    self.mongo_client = MongoClient(mongo_uri)
                    self.mongo_db = self.mongo_client[mongo_db_name]
                    self.mongo_collection = self.mongo_db[mongo_collection_name]
                    
                    # Initialize prompt logs collection
                    self.prompt_logs_db = self.mongo_client[prompt_logs_db_name]
                    self.prompt_logs_collection = self.prompt_logs_db[prompt_logs_collection_name]
                    
                    logger.info(f"MongoDB Atlas connection initialized successfully")
                    logger.info(f"Main data: database: {mongo_db_name}, collection: {mongo_collection_name}")
                    logger.info(f"Prompt logs: database: {prompt_logs_db_name}, collection: {prompt_logs_collection_name}")
                else:
                    logger.warning("MongoDB URI not provided, continuing without MongoDB logging")
            except Exception as e:
                logger.error(f"Failed to initialize MongoDB Atlas: {e}")
                logger.warning("Continuing without MongoDB logging functionality")
        
        # Load existing processed hashes if they exist
        self._load_processed_hashes()
        
        # Initialize room-specific handlers after database setup
        if self.use_database and self.db_adapter:
            try:
                self.room_handlers = RoomSpecificHandlers(self.prompts, self.db_adapter)
                logger.info("Room-specific handlers initialized successfully")
            except Exception as e:
                logger.error(f"Failed to initialize room handlers: {e}")
                self.room_handlers = None
    
    def log_prompt_to_mongodb(self, query, response, sources=None, error=None):
        """Log a prompt and its response to MongoDB"""
        try:
            if not self.use_database or self.prompt_logs_collection is None:
                logger.error("MongoDB not initialized; cannot log prompt")
                return False
            
            prompt_log = {
                "timestamp": datetime.utcnow(),
                "query": query,
                "response": response,
                "sources_count": len(sources) if sources else 0,
                "error": error,
                "metadata": {
                    "model": "incept5/llama3.1-claude:latest",
                    "retrieval_method": "vector_store"
                }
            }
            
            # Add source document hashes if available
            if sources:
                source_hashes = []
                for source in sources:
                    if 'metadata' in source and 'doc_hash' in source['metadata']:
                        source_hashes.append(source['metadata']['doc_hash'])
                prompt_log["source_document_hashes"] = source_hashes
            
            result = self.prompt_logs_collection.insert_one(prompt_log)
            logger.info(f"Logged prompt to MongoDB with ID: {result.inserted_id}")
            return True
            
        except Exception as e:
            logger.error(f"Error logging prompt to MongoDB: {e}")
            return False
    
    def _load_processed_hashes(self):
        """Load hashes of already processed documents to avoid duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        if os.path.exists(hash_file):
            try:
                with open(hash_file, 'r') as f:
                    self.processed_hashes = set(line.strip() for line in f)
                logger.info(f"Loaded {len(self.processed_hashes)} existing document hashes")
            except Exception as e:
                logger.error(f"Error loading processed hashes: {e}")
    
    def _save_processed_hashes(self):
        """Save hashes of processed documents to avoid future duplication"""
        hash_file = os.path.join(self.chroma_dir, "processed_hashes.txt")
        try:
            os.makedirs(os.path.dirname(hash_file), exist_ok=True)
            with open(hash_file, 'w') as f:
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
        """Log a single data record to MongoDB"""
        try:
            if not self.use_database or self.mongo_collection is None:
                logger.error("MongoDB not initialized; cannot log data")
                return False
            
            doc_hash = self._generate_document_hash(data)
            if doc_hash in self.processed_hashes:
                logger.info(f"Skipping duplicate document with hash {doc_hash}")
                return False
            
            mongo_doc = data.copy()
            
            # Handle timestamp conversion safely
            if 'timestamp' in mongo_doc:
                try:
                    mongo_doc['timestamp'] = pd.to_datetime(mongo_doc['timestamp'])
                except:
                    # If conversion fails, keep original but log warning
                    logger.warning(f"Could not convert timestamp: {mongo_doc['timestamp']}")
            
            mongo_doc['doc_hash'] = doc_hash
            mongo_doc['created_at'] = datetime.utcnow()
            
            self.mongo_collection.insert_one(mongo_doc)
            self.processed_hashes.add(doc_hash)
            self._save_processed_hashes()
            logger.info(f"Logged data to MongoDB with hash {doc_hash}")
            return True
        except Exception as e:
            logger.error(f"Error logging to MongoDB: {e}")
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
                logger.error("Database not initialized; cannot load data")
                raise ValueError("Database connection required but not available")
            
            logger.info("Loading data from PostgreSQL")
            df = self.load_from_postgresql(limit=limit)
            
            if df is None or df.empty:
                logger.error("No data loaded from PostgreSQL")
                raise ValueError("No data available from PostgreSQL database")
            
            logger.info(f"Loaded {len(df)} unique occupied room records from PostgreSQL")
            self.df = df
            
            # Log to MongoDB if available
            if self.use_database and self.mongo_collection is not None:
                logged_count = 0
                for _, row in df.iterrows():
                    if self.log_to_mongodb(row.to_dict()):
                        logged_count += 1
                logger.info(f"Logged {logged_count} records to MongoDB")
            
            return df
        
        except Exception as e:
            logger.error(f"Error loading data: {e}")
            raise
    
    def _create_document_from_row(self, row):
        """Create a Document object from a DataFrame row using configurable template"""
        try:
            timestamp_str = row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        except:
            timestamp_str = str(row['timestamp'])
        
        # Get document template from prompts config
        template = self.prompts.get_document_template(self.document_template)
        
        # Format the template with row data
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
            "ac": "power_consumption_watts.hvac_fan",
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

    def _handle_deterministic_query(self, query):
        """Handle specific queries deterministically to avoid hallucinations"""
        q_lower = query.lower().strip()
        df = self.load_and_process_data()
        if df is None or df.empty:
            logger.error("DataFrame is empty or None; cannot process query")
            return None
        
        logger.info(f"Processing query: '{q_lower}'")
        
        # Check for room-specific queries first
        if self.room_handlers and any(keyword in q_lower for keyword in ["room", "for room", "in room"]):
            try:
                room_result = self.room_handlers.handle_room_specific_query(query)
                if room_result and "error" not in room_result:
                    logger.info(f"Used room-specific handler for query: '{query}'")
                    return room_result
                elif "error" in room_result:
                    logger.warning(f"Room-specific handler error: {room_result['error']}")
            except Exception as e:
                logger.error(f"Error in room-specific handler: {e}")
        
        # Check for advanced query types
        if any(keyword in q_lower for keyword in ["most used room", "room usage", "room utilization"]):
            return self.advanced_handlers.handle_most_used_room_query(df)
        
        if any(keyword in q_lower for keyword in ["energy trend", "energy pattern", "consumption trend"]):
            return self.advanced_handlers.handle_energy_trends_query(df)
        
        if any(keyword in q_lower for keyword in ["weekly summary", "weekly report", "summary"]):
            return self.advanced_handlers.generate_weekly_summary(df)
        
        if any(keyword in q_lower for keyword in ["anomaly", "unusual", "abnormal", "alert"]):
            anomalies = self.advanced_handlers.detect_anomalies(df)
            if anomalies:
                anomaly_descriptions = [f"{a.anomaly_type}: {a.description}" for a in anomalies[:3]]
                return {
                    "answer": f"Detected {len(anomalies)} anomalies: {'; '.join(anomaly_descriptions)}",
                    "anomalies": [{"type": a.anomaly_type, "severity": a.severity, "description": a.description} for a in anomalies]
                }
            else:
                return {"answer": "No anomalies detected in the current data."}
        
        if any(keyword in q_lower for keyword in ["maintenance", "repair", "service", "predict"]):
            anomalies = self.advanced_handlers.detect_anomalies(df)
            maintenance_alerts = self.advanced_handlers.generate_maintenance_suggestions(df, anomalies)
            if maintenance_alerts:
                alert_descriptions = [f"{m.equipment}: {m.issue} (Urgency: {m.urgency})" for m in maintenance_alerts[:3]]
                return {
                    "answer": f"Generated {len(maintenance_alerts)} maintenance suggestions: {'; '.join(alert_descriptions)}",
                    "maintenance_alerts": [{"equipment": m.equipment, "issue": m.issue, "urgency": m.urgency, "action": m.action} for m in maintenance_alerts]
                }
            else:
                return {"answer": "No immediate maintenance needs detected."}
        
        if any(keyword in q_lower for keyword in ["context", "current", "situation"]):
            return self.advanced_handlers.handle_context_aware_query(query, df)
        
        if any(keyword in q_lower for keyword in ["all readings", "all logs", "all records", "all room_logs"]):
            timestamps = []
            for _, row in df.iterrows():
                try:
                    timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                except:
                    timestamps.append(str(row["timestamp"]))
            sources = self._get_source_documents_for_rows(df.sample(min(3, len(df))))
            logger.info(f"Matched all readings query; returning {len(timestamps)} timestamps")
            return {
                "answer": f"The room logs contain {len(timestamps)} occupied readings: {', '.join(timestamps)}.",
                "sources": sources
            }
        
        if "how many" in q_lower and any(keyword in q_lower for keyword in ["record", "data", "log"]):
            count = len(df)
            sample_df = df.sample(min(3, len(df)))
            sources = self._get_source_documents_for_rows(sample_df)
            logger.info(f"Matched count query; returning {count} records")
            return {
                "answer": f"There are {count} occupied room records in the dataset.",
                "sources": sources
            }
        
        if "how many" in q_lower and "people" in q_lower:
            total_people = int(df["occupancy_count"].sum())
            sample_df = df.sample(min(3, len(df)))
            sources = self._get_source_documents_for_rows(sample_df)
            logger.info(f"Matched people query; returning total of {total_people} people")
            return {
                "answer": f"There are a total of {total_people} people across all occupied room records.",
                "sources": sources
            }
        
        if "power consumption breakdown" in q_lower or "power breakdown" in q_lower:
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
                        logger.info(f"Matched power breakdown query for timestamp {target_timestamp}")
                        return {
                            "answer": f"At {target_timestamp}, the power consumption breakdown is: {breakdown}.",
                            "sources": sources
                        }
                except ValueError:
                    logger.warning(f"Invalid timestamp format in query: {target_timestamp}")
            logger.warning("No valid timestamp found for power breakdown query")
            return None
        
        mixed_result = self._handle_mixed_query(q_lower, df)
        if mixed_result:
            logger.info("Matched mixed query")
            return mixed_result
        
        has_lowest = "lowest" in q_lower or "minimum" in q_lower or "min " in q_lower
        has_highest = "highest" in q_lower or "maximum" in q_lower or "max " in q_lower
        
        if has_lowest and has_highest:
            logger.info("Matched combined min/max query")
            return self._handle_min_max_query(q_lower, df, "combined")
        elif has_lowest:
            logger.info("Matched min query")
            return self._handle_min_max_query(q_lower, df, "min")
        elif has_highest:
            logger.info("Matched max query")
            return self._handle_min_max_query(q_lower, df, "max")
        elif "average" in q_lower or "mean" in q_lower:
            logger.info("Matched average query")
            return self._handle_avg_query(q_lower, df)
        
        logger.warning(f"No deterministic match for query: '{q_lower}'; falling back to LLM")
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
                    min_timestamps = [row["timestamp"].strftime("%Y-%m-%d %H:%M:%S") for _, row in min_rows.iterrows() if hasattr(row["timestamp"], 'strftime')]
                    max_timestamps = [row["timestamp"].strftime("%Y-%m-%d %H:%M:%S") for _, row in max_rows.iterrows() if hasattr(row["timestamp"], 'strftime')]
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
                timestamps = [row["timestamp"].strftime("%Y-%m-%d %H:%M:%S") for _, row in matching_rows.iterrows() if hasattr(row["timestamp"], 'strftime')]
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
    
    def _enhance_query_for_llm(self, query):
        """Add context and instructions to reduce hallucinations using configurable prompts"""
        system_prompt = self.prompts.get_system_prompt(self.prompt_type)
        return system_prompt.format(query=query)
    
    def ask(self, query):
        """Ask a question about the room logs"""
        if not self.qa_chain:
            raise ValueError("QA chain not initialized. Call initialize_qa_chain() first.")

        try:
            df = self.load_and_process_data()
            documents = self.create_documents(df)
            if documents:
                logger.info(f"Adding {len(documents)} new documents due to data changes")
                if self.vector_store is None:
                    self.initialize_vector_store(documents)
                else:
                    self.vector_store.add_documents(documents)
                    self.vector_store.persist()
                self._save_processed_hashes()

            deterministic_result = self._handle_deterministic_query(query)
            if deterministic_result:
                logger.info(f"Used deterministic handler for query: '{query}'")
                # Log the prompt and response
                self.log_prompt_to_mongodb(
                    query=query,
                    response=deterministic_result["answer"],
                    sources=deterministic_result.get("sources", [])
                )
                return deterministic_result

            enhanced_query = self._enhance_query_for_llm(query)
            result = self.qa_chain({"query": enhanced_query})
            logger.info(f"Query: '{query}' - Response generated using LLM")

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

            # Log the prompt and response
            self.log_prompt_to_mongodb(
                query=query,
                response=validated_answer,
                sources=unique_source_docs
            )

            return response

        except Exception as e:
            logger.error(f"Error processing query '{query}': {e}")
            # Log the error
            self.log_prompt_to_mongodb(
                query=query,
                response=None,
                error=str(e)
            )
            return {"error": str(e)}
    
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
    """Initialize the analyzer - call this once at application startup"""
    global analyzer
    try:
        logger.info("Starting analyzer initialization with MongoDB Atlas")
        analyzer = RoomLogAnalyzer(
            use_database=True,
            mongo_uri=os.getenv("MONGO_ATLAS_URI"),
            mongo_db_name=os.getenv("MONGO_DB_NAME", "LLM_logs"),
            mongo_collection_name=os.getenv("MONGO_COLLECTION_NAME", "logs"),
            prompt_logs_db_name=os.getenv("PROMPT_LOGS_DB_NAME", "prompt_logs"),
            prompt_logs_collection_name=os.getenv("PROMPT_LOGS_COLLECTION_NAME", "queries")
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
        return False

def ask(query):
    """Public function to ask questions - this is what you import from app.py"""
    global analyzer
    if analyzer is None:
        if not initialize_analyzer():
            return {"error": "Analyzer not initialized"}
    try:
        result = analyzer.ask(query)
        return result
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return {"error": str(e)}

# Initialize when this module is imported
if __name__ == "__main__":
    # Test MongoDB connection on startup
    from pymongo import MongoClient
    import os
    
    mongo_uri = os.getenv("MONGO_ATLAS_URI")
    if mongo_uri:
        try:
            client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
            client.admin.command('ping')
            logger.info("✅ MongoDB Atlas connection test: Successful")
        except Exception as e:
            logger.error(f"❌ MongoDB Atlas connection test failed: {e}")
    
    initialize_analyzer(reset_vector_store=False)
