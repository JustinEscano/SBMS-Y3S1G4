import json
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
    def __init__(self, json_file_path="room_logs.json", chroma_dir="./chroma_room_logs"):
        self.json_file_path = json_file_path
        self.chroma_dir = chroma_dir
        self.vector_store = None
        self.qa_chain = None
        self.processed_hashes = set()
        self.df = None  # Cache the dataframe
        
        # Load existing processed hashes if they exist
        self._load_processed_hashes()
    
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
    
    def load_and_process_data(self):
        """Load and process the room logs data"""
        if self.df is not None:
            return self.df
            
        try:
            with open(self.json_file_path, "r") as file:
                data = json.load(file)
            
            # Flatten the logs into DataFrame, parse timestamps, and filter for occupied logs
            df = pd.json_normalize(data["logs"])
            df["timestamp"] = pd.to_datetime(df["timestamp"])
            df = df[df["occupancy_status"] == "occupied"]
            
            # CRITICAL FIX: Ensure numeric types for correct calculations
            numeric_cols = [
                "occupancy_count", "energy_consumption_kwh",
                "power_consumption_watts.lighting", "power_consumption_watts.hvac_fan",
                "power_consumption_watts.standby_misc", "power_consumption_watts.total",
                "equipment_usage.lights_on_hours", "equipment_usage.air_conditioner_on_hours",
                "equipment_usage.projector_on_hours", "equipment_usage.computer_on_hours",
                "environmental_data.temperature_celsius", "environmental_data.humidity_percent"
            ]
            for col in numeric_cols:
                if col in df.columns:
                    df[col] = pd.to_numeric(df[col], errors="coerce")
            
            # Remove duplicates based on all relevant fields
            dedup_columns = [
                "timestamp", "occupancy_count", "energy_consumption_kwh",
                "power_consumption_watts.lighting", "power_consumption_watts.hvac_fan",
                "power_consumption_watts.standby_misc", "power_consumption_watts.total",
                "equipment_usage.lights_on_hours", "equipment_usage.air_conditioner_on_hours",
                "equipment_usage.projector_on_hours", "equipment_usage.computer_on_hours",
                "environmental_data.temperature_celsius", "environmental_data.humidity_percent"
            ]
            df = df.drop_duplicates(subset=dedup_columns)
            
            logger.info(f"Loaded {len(df)} unique occupied room records after deduplication")
            self.df = df
            return df
            
        except Exception as e:
            logger.error(f"Error loading data: {e}")
            raise
    
    def _create_document_from_row(self, row):
        """Create a Document object from a DataFrame row"""
        try:
            timestamp_str = row['timestamp'].strftime("%Y-%m-%d %H:%M:%S")
        except:
            timestamp_str = str(row['timestamp'])
        
        page_content = (
            f"At {timestamp_str}, the room was occupied with "
            f"{row['occupancy_count']} people. Energy consumption: {row['energy_consumption_kwh']} kWh. "
            f"Lighting power: {row['power_consumption_watts.lighting']}W, "
            f"HVAC power: {row['power_consumption_watts.hvac_fan']}W, "
            f"Standby power: {row['power_consumption_watts.standby_misc']}W, "
            f"Total power: {row['power_consumption_watts.total']}W. "
            f"Lights usage: {row['equipment_usage.lights_on_hours']} hours, "
            f"AC usage: {row['equipment_usage.air_conditioner_on_hours']} hours, "
            f"Projector usage: {row['equipment_usage.projector_on_hours']} hours, "
            f"Computers usage: {row['equipment_usage.computer_on_hours']} hours. "
            f"Temperature: {row['environmental_data.temperature_celsius']}°C, "
            f"Humidity: {row['environmental_data.humidity_percent']}%."
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
            # Generate a unique hash for this document
            doc_hash = self._generate_document_hash(row)
            
            # Skip if we've already processed this document
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
            # Optionally reset the vector store
            if reset and os.path.exists(self.chroma_dir):
                logger.info("Resetting vector store")
                shutil.rmtree(self.chroma_dir)
                self.processed_hashes.clear()
                self._save_processed_hashes()
            
            # Check if vector store already exists
            if os.path.exists(self.chroma_dir) and os.listdir(self.chroma_dir) and not reset:
                logger.info("Loading existing vector store")
                embedding = OllamaEmbeddings(model="nomic-embed-text")
                vector_store = Chroma(
                    persist_directory=self.chroma_dir, 
                    embedding_function=embedding,
                    collection_name="room_logs"
                )
                
                # Check existing documents for duplicates
                existing_docs = vector_store.get()
                existing_hashes = {doc['doc_hash'] for doc in existing_docs['metadatas'] if 'doc_hash' in doc}
                new_documents = [doc for doc in documents if doc.metadata['doc_hash'] not in existing_hashes]
                
                # Add new documents if any
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
                    documents=document, 
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
        # Define column mapping
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
            "standby": "power_consumption_watts.standby_misc"
        }
        
        # Define operation mapping
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
        
        # Extract operations and columns
        operations = []
        columns = []
        
        # Split by 'and', '&', or comma
        parts = re.split(r'\s+and\s+|\s*&\s*|\s*,\s*', q_lower)
        
        for part in parts:
            part = part.strip()
            if not part:
                continue
                
            # Find operation and column
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
                # For average, get sample sources
                sample_rows = df.sample(min(3, len(df)))
                sources = self._get_source_documents_for_rows(sample_rows)
                all_sources.extend(sources)
                results.append(f"The {op_word} {col.split('.')[-1]} is {value:.2f}")
                continue
            else:
                continue
            
            # Get rows where this value occurs
            matching_rows = df[df[col] == value]
            
            # Get timestamps
            timestamps = []
            for _, row in matching_rows.iterrows():
                try:
                    timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                except:
                    timestamps.append(str(row["timestamp"]))
            
            # Get source documents
            sources = self._get_source_documents_for_rows(matching_rows.head(2))  # Limit to 2 per operation
            all_sources.extend(sources)
            
            # Short column name for display
            col_display = col.split('.')[-1]
            results.append(f"The {op_word} {col_display} is {value} at {', '.join(timestamps[:2])}{'...' if len(timestamps) > 2 else ''}")
        
        if results:
            return {
                "answer": ". ".join(results) + ".",
                "sources": all_sources[:6]  # Limit total sources to 6
            }
        
        return None

    def _handle_deterministic_query(self, query):
        """Handle specific queries deterministically to avoid hallucinations"""
        q_lower = query.lower().strip()
        
        # Load data
        df = self.load_and_process_data()
        if df.empty:
            return None
        
        # Handle count queries
        if "how many" in q_lower and ("record" in q_lower or "data" in q_lower or "log" in q_lower):
            count = len(df)
            # Return a sample of source documents
            sample_df = df.sample(min(3, len(df)))
            sources = self._get_source_documents_for_rows(sample_df)
            return {
                "answer": f"There are {count} occupied room records in the dataset.",
                "sources": sources
            }
        
        # First try to handle mixed queries
        mixed_result = self._handle_mixed_query(q_lower, df)
        if mixed_result:
            return mixed_result
        
        # Then try single operation queries
        has_lowest = "lowest" in q_lower or "minimum" in q_lower or "min " in q_lower
        has_highest = "highest" in q_lower or "maximum" in q_lower or "max " in q_lower
        
        if has_lowest and has_highest:
            # This is a combined query for the same column
            return self._handle_min_max_query(q_lower, df, "combined")
        elif has_lowest:
            return self._handle_min_max_query(q_lower, df, "min")
        elif has_highest:
            return self._handle_min_max_query(q_lower, df, "max")
        elif "average" in q_lower or "mean" in q_lower:
            return self._handle_avg_query(q_lower, df)
        
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
            "standby": "power_consumption_watts.standby_misc",
            "misc": "power_consumption_watts.standby_misc",
            "energy": "energy_consumption_kwh",
            "temperature": "environmental_data.temperature_celsius",
            "temp": "environmental_data.temperature_celsius",
            "humidity": "environmental_data.humidity_percent",
            "occupancy": "occupancy_count"
        }
        
        for key, col in col_map.items():
            if key in q_lower and col in df.columns:
                if operation == "combined":
                    min_value = df[col].min()
                    max_value = df[col].max()
                    
                    min_rows = df[df[col] == min_value]
                    max_rows = df[df[col] == max_value]
                    
                    min_timestamps = []
                    for _, row in min_rows.iterrows():
                        try:
                            min_timestamps.append(row["timestamp"].strftime("%Y-%m-%d %H:%M:%S"))
                        except:
                            min_timestamps.append(str(row["timestamp"]))
                    
                    max_timestamps = []
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
            "occupancy": "occupancy_count"
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
        """Add context and instructions to reduce hallucinations"""
        enhanced_query = f"""
        Based EXCLUSIVELY on the room energy consumption data provided, answer the following question.
        If the information is not available in the data, say "I cannot find this information in the data."
        Do not make up or assume any information.
        
        Question: {query}
        
        Important instructions:
        1. Only use numbers and facts from the provided documents
        2. If unsure, say you don't know
        3. Be precise and factual
        """
        return enhanced_query
    
    def ask(self, query):
        """Ask a question about the room logs"""
        if not self.qa_chain:
            raise ValueError("QA chain not initialized. Call initialize_qa_chain() first.")

        try:
            # First try deterministic handling
            deterministic_result = self._handle_deterministic_query(query)
            if deterministic_result:
                logger.info(f"Used deterministic handler for query: '{query}'")
                return deterministic_result

            # Otherwise use the retrieval QA chain with enhanced prompt
            enhanced_query = self._enhance_query_for_llm(query)
            result = self.qa_chain({"query": enhanced_query})
            logger.info(f"Query: '{query}' - Response generated using LLM")

            # Validate LLM response for obvious hallucinations
            llm_answer = result.get("result", "")
            validated_answer = self._validate_llm_response(llm_answer, query)

            # Deduplicate source documents by doc_hash
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

            return {
                "answer": validated_answer,
                "sources": unique_source_docs
            }

        except Exception as e:
            logger.error(f"Error processing query '{query}': {e}")
            return {"error": str(e)}
    
    def _validate_llm_response(self, response, query):
        """Basic validation to catch obvious hallucinations"""
        # Check for unrealistic numbers in power-related queries
        if any(word in query.lower() for word in ['power', 'energy', 'watt', 'kwh']):
            numbers = re.findall(r'\d+\.?\d*', response)
            for num in numbers:
                try:
                    num_val = float(num)
                    # If power value is unrealistically high
                    if num_val > 10000:  # 10kW is unrealistic for a room
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
        analyzer = RoomLogAnalyzer()
        
        # Load and process data
        df = analyzer.load_and_process_data()
        
        # Create documents from the data
        documents = analyzer.create_documents(df)
        
        # Initialize vector store with documents
        analyzer.initialize_vector_store(documents, reset=reset_vector_store)
        
        # Initialize QA chain
        analyzer.initialize_qa_chain()
        
        logger.info("Analyzer initialized successfully")
        return True
    except Exception as e:
        logger.error(f"Error initializing analyzer: {e}")
        return False

def ask(query):
    """Public function to ask questions - this is what you import from app.py"""
    global analyzer
    if analyzer is None:
        # Try to initialize if not already done
        if not initialize_analyzer():
            return {"error": "Analyzer not initialized"}
    
    try:
        result = analyzer.ask(query)
        return result
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        return {"error": str(e)}

# Initialize when this module is imported
initialize_analyzer(reset_vector_store=False)  # PS: Set True once to reset (If set to True while fetching data it won't work) after that set to False again for fetching data.