from fastapi import HTTPException
from Models.notification_model import NotificationModel
from database import db
from datetime import datetime

async def create_notification(notification: dict):
    notification_dict = notification.dict()
    notification_dict["created_at"] = datetime.utcnow()
    notification_dict["updated_at"] = datetime.utcnow()

    result = await db.notifications.insert_one(notification_dict)

    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error inserting notification")

    notification_dict["_id"] = str(result.inserted_id)

    return {
        "message": "Notification created successfully",
        "data": notification_dict
    }
