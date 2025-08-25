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
        try:
            with open(self.json_file_path, "r") as file:
                data = json.load(file)
            
            # Flatten the logs into DataFrame, parse timestamps, and filter for occupied logs
            df = pd.json_normalize(data["logs"])
            df["timestamp"] = pd.to_datetime(df["timestamp"])
            df = df[df["occupancy_status"] == "occupied"]
            
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
            return df
            
        except Exception as e:
            logger.error(f"Error loading data: {e}")
            raise
    
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
            
            # Create the document content
            page_content = (
                f"At {row['timestamp']}, the room was occupied with "
                f"{row['occupancy_count']} people. Energy: {row['energy_consumption_kwh']} kWh. "
                f"Lighting: {row['power_consumption_watts.lighting']}W, "
                f"HVAC: {row['power_consumption_watts.hvac_fan']}W, "
                f"Standby: {row['power_consumption_watts.standby_misc']}W, "
                f"Total Power: {row['power_consumption_watts.total']}W. "
                f"Lights on: {row['equipment_usage.lights_on_hours']}h, "
                f"AC on: {row['equipment_usage.air_conditioner_on_hours']}h, "
                f"Projector: {row['equipment_usage.projector_on_hours']}h, "
                f"Computers: {row['equipment_usage.computer_on_hours']}h. "
                f"Temp: {row['environmental_data.temperature_celsius']}°C, "
                f"Humidity: {row['environmental_data.humidity_percent']}%. "
            )
            
            # Create the document
            doc = Document(
                page_content=page_content, 
                metadata={
                    "timestamp": row["timestamp"].isoformat(),
                    "occupancy_count": row["occupancy_count"],
                    "doc_hash": doc_hash
                }
            )
            
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
            llm = OllamaLLM(model="llama3:latest")
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
    
    def ask(self, query):
        """Ask a question about the room logs"""
        if not self.qa_chain:
            raise ValueError("QA chain not initialized. Call initialize_qa_chain() first.")
        
        try:
            result = self.qa_chain({"query": query})
            logger.info(f"Query: '{query}' - Response generated successfully")
            
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
                "result": result["result"],
                "source_documents": unique_source_docs
            }
        except Exception as e:
            logger.error(f"Error processing query '{query}': {e}")
            raise

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
initialize_analyzer(reset_vector_store=False)  # Do not reset; use existing data