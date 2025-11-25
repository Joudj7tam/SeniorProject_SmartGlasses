from fastapi import APIRouter
from Controllers.notification_controller import create_notification
from Models.notification_model import NotificationModel

router = APIRouter()

@router.post("/add")
async def add_notification(notification: NotificationModel):
    return await create_notification(notification)
