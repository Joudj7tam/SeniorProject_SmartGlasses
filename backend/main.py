from fastapi import FastAPI
from Routes.notifications_router import router as notification_router
from Routes.readings_router import router as readings_router
from Routes.user_router import router as user_router
from Routes.eye_health_form_router import router as eye_health_form_router
from Routes.devices_router import router as devices_router
from fastapi import FastAPI
import asyncio
from monitoring.monitor import watch_database

app = FastAPI()

# Start the database watcher in the background
# @app.on_event("startup")
# async def startup_event():
#     asyncio.create_task(watch_database())

app.include_router(notification_router, prefix="/api/notifications")
app.include_router(readings_router, prefix="/api")
app.include_router(user_router, prefix="/api/users")
app.include_router(eye_health_form_router, prefix="/api/eye-health-form")
app.include_router(devices_router, prefix="/api/devices")

@app.get("/")
def home():
    return {"message": "API is running!"}