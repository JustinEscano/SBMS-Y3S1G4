from fastapi import FastAPI, Request
from main import ask

app = FastAPI()

@app.post("/rag")
async def rag_endpoint(request: Request):
    data = await request.json()
    query = data.get("query", "")
    if not query:
        return {"error": "Missing query."}
    
    result = ask(query)
    return {
        "answer": result.get("result", ""),
        "sources": [
            {"content": doc.page_content, "metadata": doc.metadata}
            for doc in result.get("source_documents", [])
        ]
    }
