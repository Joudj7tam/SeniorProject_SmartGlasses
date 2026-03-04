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
        
    # link to user_id and form_id based on deviceId
    link = await db.devices.find_one({
        "deviceId": reading.deviceId,
        "power": True
    })

    if link:
        doc["user_id"] = link["user_id"]
        doc["form_id"] = link["form_id"]
    else:
        raise HTTPException(status_code=404, detail="Device not found or inactive")

    result = await db[collection_name].insert_one(doc)

    return {
        "success": True,
        "inserted_id": str(result.inserted_id)
    }
