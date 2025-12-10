# without humidity and temperature values.
# monitor.py
# ================================================
# MongoDB watcher:
# - Collects raw sensor data
# - Uses MetricsEngine to calculate metrics
# - Passes metrics to rules engine
# ================================================

import asyncio
from database import db
from monitoring.metrics import MetricsEngine
from monitoring.rules import evaluate_rules

async def watch_database():
    print("👀 Watching MongoDB for new sensor data...")

    metrics_engine = MetricsEngine()
    pipeline = [{ "$match": { "operationType": "insert" }}]

    async with db.raw_readings.watch(pipeline) as stream:
        async for change in stream:
            doc = change["fullDocument"]
            data = doc.get("data", {})

            print("📥 New Data:", data)

            # ------------------------------
            # Extract blink information
            # ------------------------------
            blink_raw = data.get("blink", {}).get("rawValue", 0)
            blink_detected = (blink_raw == 1)
            metrics_engine.update_blink(blink_detected)

            # ------------------------------
            # Extract light data
            # ------------------------------
            rgb = data.get("rgb", {})
            r = rgb.get("r", 0)
            g = rgb.get("g", 0)
            b = rgb.get("b", 0)
            clear = rgb.get("clear", 0)

            lux = metrics_engine.calculate_lux(clear)
            blue_ratio = metrics_engine.calculate_blue_ratio(r, g, b)

            # ------------------------------
            # Prepare metrics for rules
            # ------------------------------
            ibi = metrics_engine.get_latest_ibi()
            blink_rate = metrics_engine.calculate_blink_rate()
            ibi_var = metrics_engine.ibi_variance()
            session_time = metrics_engine.get_session_time_minutes()

            metrics = {
                "ibi": ibi,
                "blink_rate": blink_rate,
                "ibi_variance": ibi_var,
                "lux": lux,
                "blue_ratio": blue_ratio,
                "session_time": session_time
            }

            # ------------------------------
            # Evaluate rules and send alerts
            # ------------------------------
            await evaluate_rules(metrics)

