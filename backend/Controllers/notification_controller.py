"""
Purpose:
    CRUD operations for notifications + optional push delivery via FCM.
"""
from fastapi import HTTPException
from Models.notification_model import NotificationModel
from database import db
from datetime import datetime
from bson import ObjectId
from firebase.firebase_client import send_push_notification, USER_FCM_TOKEN


async def create_notification(notification):
    """
    Create a notification in MongoDB and (optionally) send an FCM push.

    Args:
        notification: NotificationModel or dict payload.

    Returns:
        API response with created notification data.
    """
    if hasattr(notification, "dict"):
        notification_dict = notification.dict()
    else:
        notification_dict = notification

    # Timestamps
    now = datetime.utcnow()
    notification_dict["created_at"] = now
    notification_dict["updated_at"] = now

    # link to user_id and form_id based on deviceId
    link = await db.devices.find_one(
        {"deviceId": notification_dict["deviceId"], "power": True}
    )

    if not link:
        raise HTTPException(status_code=400, detail="Device not linked to any user")

    notification_dict["user_id"] = link.get("user_id")
    notification_dict["form_id"] = link.get("form_id")

    # Insert into DB
    result = await db.notifications.insert_one(notification_dict)
    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error inserting notification")

    notification_dict["id"] = str(result.inserted_id)
    notification_dict.pop("_id", None)

    # Send FCM push notification using user's stored fcm_token (best-effort)
    try:
        user_id = (notification_dict.get("user_id") or "").strip()
        user_token = None

        if user_id:
            # devices.user_id is expected to be stored as string of Mongo ObjectId
            try:
                user_oid = ObjectId(user_id)
                user_doc = await db.users.find_one({"_id": user_oid})
                if user_doc:
                    user_token = user_doc.get("fcm_token")
            except Exception:
                # user_id not a valid ObjectId string
                user_token = None

        if user_token:
            title = notification_dict.get("title", "Smart Glasses Alert")
            body = notification_dict.get("message", "")

            send_push_notification(
                user_token,
                title,
                body,
                {
                    "metric_name": notification_dict.get("metric_name", ""),
                    "critical_value": str(notification_dict.get("critical_value", "")),
                    "user_id": notification_dict.get("user_id", ""),
                    "form_id": notification_dict.get("form_id", ""),
                },
            )
            print("📨 Push notification sent to Firebase!")
        else:
            print("⚠️ No FCM token found for this user. Skipping push.")
    except Exception as e:
        print("❌ Error sending push:", e)

    return {
        "message": "Notification created successfully",
        "data": notification_dict,
    }

async def update_notification_read_status(notification_id: str, is_read: bool, user_id: str, form_id: str):
    """
    Update isRead field for a notification.

    Args:
        notification_id: MongoDB document id as string.
        is_read: New read state (True/False).
        user_id: ID of the user to verify ownership.
        form_id: ID of the form to verify ownership.
    Returns:
        API response with updated notification data.
    """

    try:
        obj_id = ObjectId(notification_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification id")

    result = await db.notifications.update_one(
        {"_id": obj_id, "user_id": user_id, "form_id": form_id},
        {"$set": {"isRead": is_read, "updated_at": datetime.utcnow()}}
    )
    
    if result.matched_count == 0:
            # Either not found, or not owned by this user/form
            raise HTTPException(status_code=404, detail="Notification not found")

    updated = await db.notifications.find_one({"_id": obj_id, "user_id": user_id, "form_id": form_id})
    if not updated:
        raise HTTPException(status_code=404, detail="Notification not found")


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


async def get_user_notifications(user_id: str, form_id: str):
    """
    Return notifications for a specific user + form, sorted by created_at desc.
    """
    notifications = []

    cursor = (
        db.notifications
        .find({"user_id": user_id, "form_id": form_id})
        .sort("created_at", -1)
    )

    async for doc in cursor:
        doc["id"] = str(doc["_id"])
        doc.pop("_id", None)

        if isinstance(doc.get("created_at"), datetime):
            doc["created_at"] = doc["created_at"].isoformat()
        if isinstance(doc.get("updated_at"), datetime):
            doc["updated_at"] = doc["updated_at"].isoformat()

        notifications.append(doc)

    return notifications


async def delete_notification(notification_id: str, user_id: str, form_id: str):
    """
    Delete a notification by id scoped to user_id + form_id.
    """
    try:
        oid = ObjectId(notification_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification id")

    # only delete if belongs to this user + form
    result = await db.notifications.delete_one(
        {"_id": oid, "user_id": user_id, "form_id": form_id}
    )

    if result.deleted_count == 0:
        raise HTTPException(status_code=404, detail="Notification not found")

    return {"message": "Notification deleted successfully", "id": notification_id}