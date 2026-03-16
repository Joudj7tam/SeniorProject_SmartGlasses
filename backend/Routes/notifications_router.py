from datetime import datetime
from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from Controllers.notification_controller import (
    create_notification,
    get_user_notifications,
    delete_notification,
    update_notification_read_status,
    get_alert_count_chart,
    parse_selected_date
)
from Models.notification_model import NotificationModel

router = APIRouter()

# --------- موديل بسيط لطلب تحديث isRead ---------
class NotificationReadUpdate(BaseModel):
    isRead: bool


# --------- إضافة إشعار جديد ---------
@router.post("/add")
async def add_notification(notification: NotificationModel):
    return await create_notification(notification)


# --------- جلب كل الإشعارات ---------
@router.get("/")
async def list_notifications(user_id: str, form_id: str):
    """return all notifications for a user + form, sorted by created_at desc."""
    return await get_user_notifications(user_id, form_id)


# --------- حذف إشعار معيّن ---------
@router.delete("/{notification_id}")
async def remove_notification(notification_id: str, user_id: str, form_id: str):
    """حذف إشعار معيّن."""
    return await delete_notification(notification_id, user_id, form_id)


# --------- تحديث حالة isRead ---------
@router.patch("/{notification_id}/read")
async def mark_notification_read(notification_id: str, user_id: str, form_id: str, payload: NotificationReadUpdate):
    """
    تحديث حالة القراءة (isRead) لإشعار معيّن.
    body:
    {
      "isRead": true أو false
    }
    """
    return await update_notification_read_status(notification_id, payload.isRead, user_id, form_id)


# ---------------------------------------------------------
# Get Alert Count chart data
# ---------------------------------------------------------
@router.get("/alert-count")
async def fetch_alert_count(
    user_id: str,
    form_id: str,
    range_type: str,
    selected_date: str | None = None,
):
    parsed_date = parse_selected_date(selected_date)
    return await get_alert_count_chart(user_id, form_id, range_type, parsed_date)