import json
import pandas as pd
from langchain_core.documents import Document
from langchain.chains import RetrievalQA
from langchain_ollama import OllamaEmbeddings
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma


# Loads the data log in the JSON file.
with open("room_logs.json", "r") as file:
    data = json.load(file)

# Flattens the logs into DataFrame, parses timestamps, and filters for occupied logs.   
df = pd.json_normalize(data["logs"])
df["timestamp"]= pd.to_datetime(df["timestamp"])
df = df[df["occupancy_status"] == "occupied"]

# Converts each log row into a readable summary strings.
def summarize_log(row):
    return (
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
        f"Humidity: {row['environmental_data.humidity_percent']}%."
    )

# Turns each summary into a LangChain Document for embeddings.
documents = [Document(page_content=summarize_log(row), metadata={"timestamp": row["timestamp"].isoformat()}) for _, row in df.iterrows()]

# Embeds the documents using Ollama, stores them in ChromaDB, and persist the database.
embedding = OllamaEmbeddings(model="nomic-embed-text")
chroma_dir = "./chroma_room_logs"

vector_store = Chroma.from_documents(documents=documents, embedding=embedding, persist_directory=chroma_dir, collection_name="room_logs")
vector_store.persist()

# Sets up the Ollama LLM and retrieval
llm = OllamaLLM(model="llama3.2:3b")
qa_chain = RetrievalQA.from_chain_type(llm=llm, retriever=vector_store.as_retriever(),chain_type="stuff", return_source_documents=True)

def ask(query:str):
    return qa_chain({"query": query})