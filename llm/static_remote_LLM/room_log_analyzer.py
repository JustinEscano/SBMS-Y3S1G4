import logging
from langchain.chains import RetrievalQA
from langchain.prompts import PromptTemplate

logger = logging.getLogger(__name__)

class RoomLogAnalyzer:
    def __init__(self, table_name="core_sensorlog"):
        self.table_name = table_name
        self.vector_store = None
        self.retriever = None
        self.qa_chain = None

    def initialize_vector_store(self, documents, reset=False):
        """Initialize vector store (FAISS example)."""
        if not documents:
            raise ValueError("No documents available to build vector store")

        try:
            from langchain_community.vectorstores import FAISS
            from langchain_ollama import OllamaEmbeddings

            embeddings = OllamaEmbeddings(model="nomic-embed-text")
            self.vector_store = FAISS.from_documents(documents, embeddings)
            self.retriever = self.vector_store.as_retriever()

            logger.info("✅ Vector store initialized successfully")

        except Exception as e:
            logger.error(f"Failed to initialize vector store: {e}", exc_info=True)
            raise

    def initialize_qa_chain(self):
        """Initialize the RetrievalQA chain with retriever + LLM."""
        if not self.retriever:
            raise ValueError("Retriever not initialized. Run initialize_vector_store first.")

        try:
            # Prompt template
            prompt = PromptTemplate(
                template=(
                    "You are a helpful assistant for analyzing room logs.\n"
                    "Use the context below to answer the question.\n\n"
                    "Context:\n{context}\n\n"
                    "Question: {question}\nAnswer:"
                ),
                input_variables=["context", "question"]
            )

            # ✅ FIX: updated import path
            from langchain_openai import ChatOpenAI

            llm = ChatOpenAI(model="gpt-3.5-turbo", temperature=0)

            self.qa_chain = RetrievalQA.from_chain_type(
                llm=llm,
                retriever=self.retriever,
                chain_type="stuff",
                chain_type_kwargs={"prompt": prompt},
                return_source_documents=True,
            )

            logger.info("✅ QA chain initialized successfully")

        except Exception as e:
            logger.error(f"Failed to initialize QA chain: {e}", exc_info=True)
            raise
