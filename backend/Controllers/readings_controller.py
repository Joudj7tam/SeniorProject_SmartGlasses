from database import db
from Models.readings_model import ReadingModel
from datetime import datetime
from fastapi import HTTPException
import os

collection_name = os.getenv("MONGODB_COLLECTION", "raw_readings")

async def create_reading(reading: ReadingModel):
    doc = reading.dict()

    if doc["timestamp"] is None:
        doc["timestamp"] = datetime.utcnow()

    # device must be linked and powered on
    device = await db.devices.find_one({
        "deviceId": reading.deviceId,
        "is_linked": True,
        "power": True
    })

    if not device:
        raise HTTPException(status_code=404, detail="Device not found, not linked, or inactive")

    doc["user_id"] = device["user_id"]
    doc["form_id"] = device["form_id"]

    result = await db[collection_name].insert_one(doc)

    return {
        "success": True,
        "inserted_id": str(result.inserted_id)
    }
    