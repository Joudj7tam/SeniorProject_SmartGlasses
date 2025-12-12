from fastapi import HTTPException
from Models.notification_model import NotificationModel
from database import db
from datetime import datetime
from bson import ObjectId
from firebase.firebase_client import send_push_notification, USER_FCM_TOKEN


async def create_notification(notification):

    if hasattr(notification, "dict"):
        notification_dict = notification.dict()
    else:
        notification_dict = notification

    now = datetime.utcnow()
    notification_dict["created_at"] = now
    notification_dict["updated_at"] = now

    result = await db.notifications.insert_one(notification_dict)

    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error inserting notification")

    notification_dict["id"] = str(result.inserted_id)
    notification_dict.pop("_id", None)
    
    # === Send FCM Push Notification ===
    try:
        title = notification_dict.get("title", "Smart Glasses Alert")
        body = notification_dict.get("message", "")
        send_push_notification(
            USER_FCM_TOKEN,
            title,
            body,
            {
                "metric_name": notification_dict.get("metric_name", ""),
                "critical_value": str(notification_dict.get("critical_value", ""))
            }
        )
        print("📨 Push sent to Firebase!")
    except Exception as e:
        print("❌ Error sending push:", e)

    return {
        "message": "Notification created successfully",
        "data": notification_dict,
    }

async def update_notification_read_status(notification_id: str, is_read: bool):
    """تحديث قيمة isRead لإشعار معيّن"""

    try:
        obj_id = ObjectId(notification_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification id")

    result = await db.notifications.update_one(
        {"_id": obj_id},
        {"$set": {"isRead": is_read, "updated_at": datetime.utcnow()}}
    )

    if result.matched_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")

    updated = await db.notifications.find_one({"_id": obj_id})
    if not updated:
        raise HTTPException(status_code=404, detail="Notification not found")

    # ✅ توحيد التنسيق مع باقي الدوال
    updated["id"] = str(updated["_id"])
    updated.pop("_id", None)

    if isinstance(updated.get("created_at"), datetime):
        updated["created_at"] = updated["created_at"].isoformat()

    if isinstance(updated.get("updated_at"), datetime):
        updated["updated_at"] = updated["updated_at"].isoformat()

    return {
        "message": "Notification updated successfully",
        "data": updated,
    }


async def get_all_notifications():
    """إرجاع كل الإشعارات (ممكن لاحقًا نضيف فلترة بـ userId)."""
    notifications = []

    cursor = db.notifications.find().sort("created_at", -1)
    async for doc in cursor:
        doc["id"] = str(doc["_id"])
        doc.pop("_id", None)
        # تأكد إن التاريخ يتحول string
        if isinstance(doc.get("created_at"), datetime):
            doc["created_at"] = doc["created_at"].isoformat()
        if isinstance(doc.get("updated_at"), datetime):
            doc["updated_at"] = doc["updated_at"].isoformat()

        notifications.append(doc)

    return notifications


async def delete_notification(notification_id: str):
    try:
        oid = ObjectId(notification_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification id")

    result = await db.notifications.delete_one({"_id": oid})

    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")

    return {"message": "Notification deleted successfully", "id": notification_id}