import os
import shutil
import json
import pandas as pd
from langchain_core.documents import Document
from langchain.chains import RetrievalQA
from langchain_ollama import OllamaEmbeddings
from langchain_ollama import OllamaLLM
from langchain_community.vectorstores import Chroma


chroma_dir = "./chroma_room_logs"
if os.path.exists(chroma_dir):
    shutil.rmtree(chroma_dir)


with open("room_logs.json", "r") as file:
    data = json.load(file)

df = pd.json_normalize(data["logs"])
df["timestamp"]= pd.to_datetime(df["timestamp"])
df = df[df["occupancy_status"] == "occupied"]


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

documents = [
    Document(
        page_content=summarize_log(row),
        metadata={"timestamp": row["timestamp"].isoformat()}
    )
    for _, row in df.iterrows()
]


embedding = OllamaEmbeddings(model="nomic-embed-text")

vector_store = Chroma.from_documents(
    documents=documents,
    embedding=embedding,
    persist_directory=chroma_dir,
    collection_name="room_logs"
)
vector_store.persist()


llm = OllamaLLM(model="llama3:latest")
qa_chain = RetrievalQA.from_chain_type(
    llm=llm,
    retriever=vector_store.as_retriever(search_kwargs={"k": 3}),  # avoid too many dupes
    chain_type="stuff",
    return_source_documents=True
)

def ask(query: str):
    return qa_chain({"query": query})
