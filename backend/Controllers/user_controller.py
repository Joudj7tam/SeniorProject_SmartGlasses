"""
Purpose:
    Operations for users.
"""

from fastapi import HTTPException
from Models.user_model import UserModel
from database import db
from firebase_admin import auth
from datetime import datetime

# --------------- Create main account ---------------
async def create_main_account(user: UserModel):

    # 1- chack if user already exists
    existing = await db.users.find_one({"firebase_uid": user.firebase_uid})
    if existing:
        raise HTTPException(status_code=400, detail="User already exists")
    
    user_dict = user.dict()
    now = datetime.utcnow()

    # 2- date and time fields
    user_dict["created_at"] = now
    user_dict["updated_at"] = now
    
    # 3- insert user into database
    result = await db.users.insert_one(user_dict)
    if not result.inserted_id:
        raise HTTPException(status_code=500, detail="Error creating main account")

    user_dict["id"] = str(result.inserted_id)
    user_dict.pop("_id", None)

    return {
        "message": "account created successfully",
        "data": user_dict
    }

# --------------- Login user ---------------
async def login(id_token: str):
    try:
        decoded_token = auth.verify_id_token(id_token)
        firebase_uid = decoded_token["uid"]
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid token")

    user = await db.users.find_one({"firebase_uid": firebase_uid})
    if not user:
        raise HTTPException(status_code=404, detail="User not registered")

    user["id"] = str(user["_id"])
    user.pop("_id", None)

    return {
        "message": "Login successful",
        "user": user
    }


# --------------- Delete main account and all sub accounts ---------------
async def delete_main_account(firebase_uid: str):
    
    # 1- validate account exists
    user = await db.users.find_one({"firebase_uid": firebase_uid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user_id = user["_id"]

    # 2- delete all forms related to this user
    await db.eye_health_forms.delete_many({
        "main_account_id": user_id
    })
    
     # 3- delete user
    await db.users.delete_one({
        "_id": user_id
    })

    return {"message": "User and all related sub-accounts deleted successfully"}


# --------------- Get user by Firebase UID ---------------
async def get_user_by_firebase_uid(firebase_uid: str):
    """
    Get user by Firebase UID.
    """

    user = await db.users.find_one({"firebase_uid": firebase_uid})
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    user["id"] = str(user["_id"])
    user.pop("_id", None)

    return user