from fastapi import FastAPI
from Routes.notifications_router import router as notification_router
from Routes.readings_router import router as readings_router
from fastapi import FastAPI

app = FastAPI()

app.include_router(notification_router, prefix="/api/notifications")
app.include_router(readings_router, prefix="/api")
@app.get("/")
def home():
    return {"message": "API is running!"}