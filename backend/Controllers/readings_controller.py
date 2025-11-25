from database import db
from Models.readings_model import ReadingModel
from datetime import datetime
import os

collection_name = os.getenv("MONGODB_COLLECTION", "raw_readings")

async def create_reading(reading: ReadingModel):
    doc = reading.dict()

    if doc["timestamp"] is None:
        doc["timestamp"] = datetime.utcnow()

    result = await db[collection_name].insert_one(doc)

    return {
        "success": True,
        "inserted_id": str(result.inserted_id)
    }
