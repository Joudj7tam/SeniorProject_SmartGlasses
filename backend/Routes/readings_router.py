from fastapi import APIRouter
from Controllers.readings_controller import create_reading
from Models.readings_model import ReadingModel

router = APIRouter()

@router.post("/readings")
async def add_reading(reading: ReadingModel):
    return await create_reading(reading)
