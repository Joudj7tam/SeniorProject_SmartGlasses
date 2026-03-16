# monitor.py
# ================================================
# MongoDB watcher:
# - Watches raw sensor data
# - Detects incorrect data
# - Locks system temporarily
# - Triggers auto shutdown if no user response
# ================================================

import asyncio
from database import db
from monitoring.metrics import MetricsEngine
from monitoring.rules import evaluate_rules
from Controllers.chart_metrics_controller import create_chart_metric
from datetime import datetime

async def watch_database():
    print("👀 Watching MongoDB for new sensor data...")

    metrics_engine = MetricsEngine()
    last_chart_save_time = datetime.utcnow()
    pipeline = [{"$match": {"operationType": "insert"}}]

    async with db.raw_readings.watch(pipeline) as stream:
        async for change in stream:
            doc = change["fullDocument"]
            device_id = doc["deviceId"]
            data = doc.get("data", {})

            # ------------------------------
            # Load device state from devices collection
            # ------------------------------
            device = await db["devices"].find_one({"deviceId": device_id})

            # Device OFF → ignore data
            if device and device.get("power") == False:
                print("🔌 Device OFF → ignoring data")
                continue

            # Error lock active → ignore everything
            if device and device.get("errorLock", False):
                print("🔒 Error lock active → waiting for user response")
                continue

            # ------------------------------
            # Metrics calculation
            # ------------------------------
            blink_raw = data.get("ir", {}).get("rawValue", 0)
            metrics_engine.update_blink(blink_raw == 1)

            rgb = data.get("rgb", {})
            r, g, b = rgb.get("r", 0), rgb.get("g", 0), rgb.get("b", 0)
            clear = rgb.get("clear", 0)

            lux = metrics_engine.calculate_lux(clear)
            blue_ratio = metrics_engine.calculate_blue_ratio(r, g, b)

            metrics = {
                "ibi": metrics_engine.get_latest_ibi(),
                "blink_rate": metrics_engine.calculate_blink_rate(),
                "ibi_variance": metrics_engine.ibi_variance(),
                "lux": lux,
                "blue_ratio": blue_ratio,
                "session_time": metrics_engine.get_session_time_minutes()
            }

            # ------------------------------
            # Incorrect Data Detection
            # ------------------------------
            incorrect_detected = False
            reasons = []

            if metrics["blink_rate"] == 0 and metrics["session_time"] > 1:
                incorrect_detected = True
                reasons.append("No blinks detected")

            if metrics["ibi"] == 0 or metrics["ibi_variance"] == 0:
                incorrect_detected = True
                reasons.append("Abnormal IBI readings")

            if lux == 0 or lux > 2000:
                incorrect_detected = True
                reasons.append("Invalid light sensor readings")

            if not (0 <= blue_ratio <= 1):
                incorrect_detected = True
                reasons.append("Invalid RGB sensor readings")

            # ------------------------------
            # Handle incorrect data
            # ------------------------------
            if incorrect_detected:
                message = "Device may not be worn properly"
                if reasons:
                    message += f" ({', '.join(reasons)})"

                print("❌ Incorrect data detected:", reasons)
                
                device = await db["devices"].find_one({"deviceId": device_id})

                # Lock device temporarily
                await db["devices"].update_one(
                    {"deviceId": device_id},
                    {"$set": {
                        "power": True,          # ON to alert user
                        "errorLock": True,      # lock until user response
                        "lastUpdated": datetime.utcnow()
                    }}
                )
                
                result = await db["notifications"].insert_one({
                    "user_id" : device.get("user_id"),
                    "form_id" : device.get("form_id"),
                    "deviceId": device_id,
                    "title": "Incorrect Sensor Data",
                    "message": message,
                    "timestamp": doc.get("timestamp", datetime.utcnow()),
                    "isRead": False,
                    "type": "sensor_error"
                })

                asyncio.create_task(
                    auto_shutdown(result.inserted_id, device_id)
                )

                continue  # ⛔ stop here

            # ------------------------------
            # Normal behavior (rules)
            # ------------------------------
            await evaluate_rules(metrics)
            
            # ------------------------------
            # Save chart metrics every 5 minutes
            # ------------------------------
            now = datetime.utcnow()
            minutes_passed = (now - last_chart_save_time).total_seconds() / 60

            if minutes_passed >= 5:
                await create_chart_metric({
                    "deviceId": device_id,
                    "user_id": device.get("user_id") if device else None,
                    "form_id": device.get("form_id") if device else None,
                    "timestamp": now,
                    "blink_count": metrics_engine.blink_count,
                    "blink_rate": metrics["blink_rate"],
                    "latest_ibi": metrics["ibi"],
                    "avg_ibi": None,
                    "lux": metrics["lux"],
                    "blue_ratio": metrics["blue_ratio"],
                    "bucket_minutes": 5,
                })

                print("📊 Chart metrics snapshot saved")
                last_chart_save_time = now


async def auto_shutdown(notification_id, device_id):
    await asyncio.sleep(30)

    notification = await db["notifications"].find_one({"_id": notification_id})

    if notification and notification.get("isRead", False):
        print("✅ Notification read → cancel shutdown")
        return

    device = await db["devices"].find_one({"deviceId": device_id})

    if device and not device.get("errorLock", True):
        print("✅ Error resolved → no shutdown")
        return

    print("⏱ No response → auto shutdown")

    await db["devices"].update_one(
        {"deviceId": device_id},
        {"$set": {
            "power": False,            # 🔌 OFF
            "errorLock": False,
            "updated_at": datetime.utcnow()
        }}
    ) 

