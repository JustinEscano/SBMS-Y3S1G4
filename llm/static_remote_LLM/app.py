from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from main import ask  # Import the ask function from main.py
import logging

# Set up logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Room Logs RAG API",
    description="API for querying room occupancy and energy consumption data",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Pydantic models for request/response
class QueryRequest(BaseModel):
    query: str

class SourceDocument(BaseModel):
    page_content: str
    metadata: dict

class QueryResponse(BaseModel):
    result: str
    source_documents: List[SourceDocument]
    error: Optional[str] = None

@app.post("/rag", response_model=QueryResponse)
async def rag_endpoint(request: QueryRequest):
    """
    Query the room logs RAG system with a natural language question.
    
    Example queries:
    - "What was the average occupancy count?"
    - "When was the energy consumption highest?"
    - "How does occupancy relate to energy usage?"
    """
    try:
        logger.info(f"Received query: {request.query}")
        result = ask(request.query)
        
        # Check if there was an error
        if "error" in result:
            raise HTTPException(status_code=500, detail=result["error"])
        
        return QueryResponse(**result)
        
    except Exception as e:
        logger.error(f"Error processing query: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    """Health check endpoint to verify the API is running"""
    return {"status": "healthy", "message": "RAG API is running"}

@app.get("/")
async def root():
    """Root endpoint with API information"""
    return {
        "message": "Room Logs RAG API",
        "endpoints": {
            "POST /rag": "Query the RAG system",
            "GET /health": "Health check",
            "GET /": "This information"
        }
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)