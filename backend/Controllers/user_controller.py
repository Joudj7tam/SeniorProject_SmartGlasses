"""
Purpose:
    Operations for users.
"""

from fastapi import HTTPException
from Models.user_model import UserModel
from database import db
from firebase_admin import auth
from datetime import datetime
from bson import ObjectId

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
    
    
    # when user logs in, make the main form active and all other forms inactive
    main_form_id = user.get("main_form_id") 
    if main_form_id:
        now = datetime.utcnow()
        # 1) make all forms inactive first
        await db.eye_health_forms.update_many(
            {"main_account_id": user["_id"]},
            {"$set": {"is_active": False, "updated_at": now}}
        )

        # 2) activate the main form
        res = await db.eye_health_forms.update_one(
            {"_id": ObjectId(main_form_id), "main_account_id": user["_id"]},
            {"$set": {"is_active": True, "updated_at": now}}
        )
        
        if res.matched_count == 0:
            raise HTTPException(status_code=500, detail="Main form not found to activate")

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
    
    # 3- Unassign all devices linked to this user
    await db.devices.update_many(
        {"user_id": str(user_id)},
        {
            "$set": {
                "user_id": None,
                "form_id": None,
                "updated_at": datetime.utcnow()
            }
        }
    )
    
    # 4- delete user
    await db.users.delete_one({
        "_id": user_id
    })
    
    # 5- delete user from firebase auth
    try:
        auth.delete_user(firebase_uid)
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="User deleted from DB but failed to delete from Firebase"
        )

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


async def update_fcm_token(user_id: str, fcm_token: str):
    """
    Update user's FCM token (single-token (single device) strategy).
    """
    try:
        oid = ObjectId(user_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid user_id")

    now = datetime.utcnow()

    res = await db.users.update_one(
        {"_id": oid},
        {"$set": {"fcm_token": fcm_token, "updated_at": now}}
    )

    if res.matched_count == 0:
        raise HTTPException(status_code=404, detail="User not found")

    return {"message": "FCM token updated successfully"}