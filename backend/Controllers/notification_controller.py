"""
Purpose:
    CRUD operations for notifications + optional push delivery via FCM.
"""
from fastapi import HTTPException
from Models.notification_model import NotificationModel
from database import db
from datetime import datetime, timedelta
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
    # لا تستبدلي created_at إذا جاء من السكربت
    if not notification_dict.get("created_at"):
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
    Update isRead field for a notification and unlock device if needed.

    Args:
        notification_id: MongoDB document id as string.
        is_read: New read state (True/False).
        user_id: ID of the user to verify ownership.
        form_id: ID of the form to verify ownership.
    """
    try:
        obj_id = ObjectId(notification_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid notification id")

    # جلب الإشعار من الداتابيس والتحقق من ملكيته
    notification = await db["notifications"].find_one(
        {"_id": obj_id, "user_id": user_id, "form_id": form_id}
    )
    if not notification:
        raise HTTPException(status_code=404, detail="Notification not found")

    # تحديث حالة القراءة
    await db["notifications"].update_one(
        {"_id": obj_id},
        {"$set": {"isRead": is_read, "updated_at": datetime.utcnow()}}
    )

    # فك القفل عن الجهاز فقط إذا:
    # 1️⃣ الإشعار من نوع sensor_error
    # 2️⃣ المستخدم علّمه كمقروء
    if is_read and notification.get("type") == "sensor_error":
        await db["devices"].update_one(
            {"deviceId": notification["deviceId"]},
            {"$set": {
                "errorLock": False,
                "updated_at": datetime.utcnow()
            }}
        )

    # تجهيز البيانات للرد
    notification["isRead"] = is_read
    notification["updated_at"] = datetime.utcnow().isoformat()
    notification["id"] = str(notification["_id"])
    notification.pop("_id", None)

    return {
        "message": "Notification updated successfully",
        "data": notification
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



# ---------------------------------------------------------
# Helper: build date filter based on range
# supported ranges:
# - day
# - week
# - month
# - year
# ---------------------------------------------------------
def build_date_filter(range_type: str, selected_date: datetime | None = None):
    now = datetime.utcnow()

    # if no selected date is provided, use current date/time
    base_date = selected_date or now

    if range_type == "day":
        # start of the selected day
        start_date = datetime(base_date.year, base_date.month, base_date.day)
        end_date = start_date + timedelta(days=1)

    elif range_type == "week":
        # get beginning of the week (Monday)
        start_date = datetime(base_date.year, base_date.month, base_date.day) - timedelta(days=base_date.weekday())
        end_date = start_date + timedelta(days=7)

    elif range_type == "month":
        # start of selected month
        start_date = datetime(base_date.year, base_date.month, 1)

        # next month
        if base_date.month == 12:
            end_date = datetime(base_date.year + 1, 1, 1)
        else:
            end_date = datetime(base_date.year, base_date.month + 1, 1)

    elif range_type == "year":
        # start of selected year
        start_date = datetime(base_date.year, 1, 1)
        end_date = datetime(base_date.year + 1, 1, 1)

    else:
        raise HTTPException(status_code=400, detail="Invalid range. Use day, week, month, or year.")

    return start_date, end_date

# ---------------------------------------------------------
# Helper: parse selected date from query param
# ---------------------------------------------------------
def parse_selected_date(selected_date: str | None = None) -> datetime | None:
    if not selected_date:
        return None

    try:
        return datetime.strptime(selected_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="Invalid selected_date format. Use YYYY-MM-DD."
        )
        


# ---------------------------------------------------------
# Get Alert Count chart data
# Returns count of notifications grouped by type
# ---------------------------------------------------------
async def get_alert_count_chart(user_id: str, form_id: str, range_type: str, selected_date: datetime | None = None):
    start_date, end_date = build_date_filter(range_type, selected_date)

    pipeline = [
        {
            # filter notifications by user, form, and date range
            "$match": {
                "user_id": user_id,
                "form_id": form_id,
                "created_at": {"$gte": start_date, "$lt": end_date},
            }
        },
        {
            # group by notification type and count documents
            "$group": {
                "_id": "$metric_name",
                "count": {"$sum": 1},
            }
        },
        {
            # sort by count descending
            "$sort": {"count": -1}
        }
    ]

    results = []
    async for doc in db.notifications.aggregate(pipeline):
        results.append({
            "label": doc["_id"] if doc["_id"] else "unknown",
            "value": doc["count"]
        })

    return {
        "chart": "alert_count",
        "range": range_type,
        "selected_date": selected_date.strftime("%Y-%m-%d") if selected_date else None,
        "data": results
    }