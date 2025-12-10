from fastapi import FastAPI
from Routes.notifications_router import router as notification_router
from Routes.readings_router import router as readings_router
from fastapi import FastAPI
import asyncio
from monitoring.monitor import watch_database

app = FastAPI()

# Start the database watcher in the background
@app.on_event("startup")
async def startup_event():
    asyncio.create_task(watch_database())

app.include_router(notification_router, prefix="/api/notifications")
app.include_router(readings_router, prefix="/api")

@app.get("/")
def home():
    return {"message": "API is running!"}