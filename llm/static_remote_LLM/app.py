from fastapi import FastAPI, Request, HTTPException
import logging
from main import ask

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("app.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

app = FastAPI()

@app.post("/rag")
async def rag_endpoint(request: Request):
    try:
        data = await request.json()
        query = data.get("query", "")
        if not query:
            logger.error("Missing query in request")
            raise HTTPException(status_code=400, detail="Missing query.")
        
        logger.info(f"Received query: {query}")
        result = ask(query)
        
        # Check for error in result
        if "error" in result:
            logger.error(f"Error from main.ask: {result['error']}")
            raise HTTPException(status_code=500, detail=result["error"])
        
        # Ensure sources are formatted correctly
        sources = [
            {"content": doc["page_content"], "metadata": doc["metadata"]}
            for doc in result.get("sources", [])
        ]
        
        response = {
            "answer": result.get("answer", ""),
            "sources": sources
        }
        logger.info(f"Response: {response}")
        return response
    
    except Exception as e:
        logger.error(f"Error processing request: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Error processing request: {str(e)}")