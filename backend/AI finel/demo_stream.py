# demo_stream.py

# =========================================================
# FIX IMPORT PATHS
# =========================================================

import os
import sys

CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
BACKEND_DIR = os.path.dirname(CURRENT_DIR)
CONTROLLERS_DIR = os.path.join(BACKEND_DIR, "Controllers")

sys.path.append(CURRENT_DIR)
sys.path.append(BACKEND_DIR)
sys.path.append(CONTROLLERS_DIR)


# =========================================================
# NORMAL IMPORTS
# =========================================================

import asyncio
import argparse
import math
import random
from datetime import datetime, timedelta
from typing import Dict, Generator

from database import db

from inference import predict_alerts
from indices import compute_indices
from recommendation import build_recommendations
from smart_light import evaluate_light, apply_to_smart_light
from notification_manager import NotificationManager

from chart_metrics_controller import create_chart_metric
from notification_controller import create_notification

from led_controller import (
    apply_light_action_to_led,
    map_light_action_to_scene,
)


# =========================================================
# CONFIG
# =========================================================

# Current working device from MongoDB / app notifications:
DEVICE_ID = "DEV_1777598211477"

# LED controller IP from Magic Home / controller app:
LED_CONTROLLER_IP = "192.168.100.34"

# Set True now that hardware LED control works:
LED_INTEGRATION_ENABLED = True

# One reading represents 5 simulated minutes
SIMULATED_MINUTES_PER_READING = 5

# Real delay between readings
REAL_DELAY_SECONDS = 4

# Demo length
DEFAULT_TOTAL_READINGS = 30

# Old smart_light integration print/apply flag
SMART_LIGHT_INTEGRATION_ENABLED = False
FOLLOW_ROUTINE = True


# =========================================================
# PERSONAS
# =========================================================

PERSONAS = {
    "normal": {
        "persona_id": "normal",
        "display_name": "Normal Student / Office User",
        "profile": {
            "min_safe_blink_bpm": 12,
            "max_safe_blue": 550,
            "max_safe_focus_min": 45,
            "has_eye_surgery": 0,
            "has_dry_eye_condition": 0,
            "wears_protective_glasses": 0,
        },
        "baseline": {
            "blink_rate_bpm": 17,
            "blue_lux": 360,
            "ambient_lux": 520,
            "humidity": 45,
            "temperature": 24,
        },
        "fatigue": {
            "blink_drop_per_step": 0.18,
            "blue_increase_per_step": 7,
            "humidity_drop_per_step": 0.08,
            "temperature_increase_per_step": 0.03,
        },
    },

    "post_lasik": {
        "persona_id": "post_lasik",
        "display_name": "Post-LASIK User",
        "profile": {
            "min_safe_blink_bpm": 14,
            "max_safe_blue": 480,
            "max_safe_focus_min": 35,
            "has_eye_surgery": 1,
            "has_dry_eye_condition": 0,
            "wears_protective_glasses": 0,
        },
        "baseline": {
            "blink_rate_bpm": 15,
            "blue_lux": 390,
            "ambient_lux": 540,
            "humidity": 40,
            "temperature": 25,
        },
        "fatigue": {
            "blink_drop_per_step": 0.24,
            "blue_increase_per_step": 8,
            "humidity_drop_per_step": 0.12,
            "temperature_increase_per_step": 0.04,
        },
    },

    "dry_eye": {
        "persona_id": "dry_eye",
        "display_name": "Severe Dry-Eye / High-Risk User",
        "profile": {
            "min_safe_blink_bpm": 15,
            "max_safe_blue": 430,
            "max_safe_focus_min": 25,
            "has_eye_surgery": 0,
            "has_dry_eye_condition": 1,
            "wears_protective_glasses": 0,
        },
        "baseline": {
            "blink_rate_bpm": 14,
            "blue_lux": 410,
            "ambient_lux": 560,
            "humidity": 35,
            "temperature": 26,
        },
        "fatigue": {
            "blink_drop_per_step": 0.30,
            "blue_increase_per_step": 9,
            "humidity_drop_per_step": 0.16,
            "temperature_increase_per_step": 0.05,
        },
    },
}


# =========================================================
# HELPERS
# =========================================================

def clamp(value: float, low: float, high: float) -> float:
    return max(low, min(high, value))


def gaussian_noise(mean: float = 0.0, std: float = 1.0) -> float:
    return random.gauss(mean, std)


def maybe_spike(probability: float, magnitude_range: tuple[float, float]) -> float:
    if random.random() < probability:
        return random.uniform(*magnitude_range)

    return 0.0


async def get_linked_device_context(device_id: str) -> dict:
    """
    Finds ONLY the requested deviceId.

    Important:
    We do not auto-select another linked device,
    because that may belong to another user/account.
    """

    def is_true(value):
        return value is True or value == "true" or value == "True" or value == 1

    print("\n🔍 Looking for YOUR linked active device...")
    print(f"Requested DEVICE_ID = {device_id}")

    device = await db.devices.find_one({"deviceId": device_id})

    if not device:
        print("\n❌ DEMO SETUP ERROR")
        print(f"No device found with deviceId = {device_id}")
        print("This means DEVICE_ID in demo_stream.py does not match MongoDB.")
        return {}

    print("\n📌 Device found in MongoDB:")
    print(f"deviceId  = {device.get('deviceId')}")
    print(f"name      = {device.get('deviceName') or device.get('name')}")
    print(f"is_linked = {device.get('is_linked')}")
    print(f"power     = {device.get('power')}")
    print(f"user_id   = {device.get('user_id')}")
    print(f"form_id   = {device.get('form_id')}")

    if not is_true(device.get("is_linked")):
        print("\n❌ DEMO SETUP ERROR")
        print("Device exists, but is_linked is not true.")
        print("Go to the app → Settings → Link Selected Device.")
        return {}

    if not is_true(device.get("power")):
        print("\n❌ DEMO SETUP ERROR")
        print("Device exists, but power is not true.")
        print("Go to the app → Settings → turn Device Power ON.")
        return {}

    user_id = device.get("user_id")
    form_id = device.get("form_id")

    if not user_id or not form_id:
        print("\n❌ DEMO SETUP ERROR")
        print("Device is linked and powered, but user_id or form_id is missing.")
        return {}

    print("\n✅ YOUR linked active device is ready")
    print(f"deviceId  = {device.get('deviceId')}")
    print(f"user_id   = {user_id}")
    print(f"form_id   = {form_id}\n")

    return {
        "deviceId": device.get("deviceId"),
        "user_id": user_id,
        "form_id": form_id,
    }


def sensor_to_chart_metric(
    sensor: Dict,
    device_context: Dict,
    timestamp: datetime,
) -> Dict:
    blink_rate = round(float(sensor["blink_rate_bpm"]), 2)
    lux = round(float(sensor["ambient_lux"]), 2)

    blue_lux = float(sensor["blue_lux"])
    blue_ratio = blue_lux / max(lux + blue_lux, 1.0)
    blue_ratio = round(clamp(blue_ratio, 0.01, 0.95), 4)

    bucket_minutes = SIMULATED_MINUTES_PER_READING
    blink_count = int(round(blink_rate * bucket_minutes))

    avg_ibi = round(60.0 / max(blink_rate, 0.1), 2)
    latest_ibi = round(
        clamp(avg_ibi + random.uniform(-0.35, 0.35), 1.0, 12.0),
        2,
    )

    return {
        "deviceId": device_context["deviceId"],
        "user_id": device_context["user_id"],
        "form_id": device_context["form_id"],

        "timestamp": timestamp,

        "blink_count": blink_count,
        "blink_rate": blink_rate,
        "latest_ibi": latest_ibi,
        "avg_ibi": avg_ibi,

        "lux": lux,
        "blue_ratio": blue_ratio,

        "bucket_minutes": bucket_minutes,
    }


def generate_live_readings(
    persona_key: str,
    total_readings: int,
    start_time: datetime | None = None,
) -> Generator[tuple[int, datetime, Dict], None, None]:

    if persona_key not in PERSONAS:
        raise ValueError(
            f"Unknown persona '{persona_key}'. Choose from: {list(PERSONAS.keys())}"
        )

    persona = PERSONAS[persona_key]
    baseline = persona["baseline"]
    fatigue = persona["fatigue"]

    start_time = start_time or datetime.utcnow().replace(second=0, microsecond=0)
    focus_minutes = 0.0

    for step in range(total_readings):
        simulated_time = start_time + timedelta(
            minutes=step * SIMULATED_MINUTES_PER_READING
        )

        focus_minutes += SIMULATED_MINUTES_PER_READING
        wave = math.sin(step / 4.0)

        blink_rate = (
            baseline["blink_rate_bpm"]
            - fatigue["blink_drop_per_step"] * step
            + wave * 0.6
            + gaussian_noise(0, 0.8)
        )

        blue_lux = (
            baseline["blue_lux"]
            + fatigue["blue_increase_per_step"] * step
            + wave * 15
            + gaussian_noise(0, 25)
            + maybe_spike(probability=0.12, magnitude_range=(120, 260))
        )

        ambient_lux = (
            baseline["ambient_lux"]
            + wave * 45
            + gaussian_noise(0, 35)
            + maybe_spike(probability=0.08, magnitude_range=(180, 420))
        )

        humidity = (
            baseline["humidity"]
            - fatigue["humidity_drop_per_step"] * step
            + gaussian_noise(0, 1.8)
        )

        temperature = (
            baseline["temperature"]
            + fatigue["temperature_increase_per_step"] * step
            + gaussian_noise(0, 0.5)
        )

        sensor = {
            "blink_rate_bpm": round(clamp(blink_rate, 3, 26), 2),
            "blue_lux": round(clamp(blue_lux, 50, 1600), 2),
            "ambient_lux": round(clamp(ambient_lux, 50, 2000), 2),
            "focus_minutes": round(clamp(focus_minutes, 1, 180), 2),
            "humidity": round(clamp(humidity, 15, 75), 2),
            "temperature": round(clamp(temperature, 18, 35), 2),
        }

        yield step + 1, simulated_time, sensor


# =========================================================
# MAIN DEMO LOOP
# =========================================================

async def run_demo(
    persona_key: str,
    total_readings: int = DEFAULT_TOTAL_READINGS,
    delay_seconds: int = REAL_DELAY_SECONDS,
    persistence_required: int = 2,
    cooldown_minutes: int = 15,
):
    random.seed(42)

    persona = PERSONAS[persona_key]
    profile = persona["profile"]

    device_context = await get_linked_device_context(DEVICE_ID)

    if not device_context:
        print("Stopping demo because linked active device was not found.")
        return

    notification_manager = NotificationManager(
        persistence_required=persistence_required,
        cooldown_minutes=cooldown_minutes,
    )

    print("=" * 70)
    print("CLIPVIEW LIVE AI DEMO STREAM")
    print("=" * 70)
    print(f"Persona: {persona['display_name']}")
    print(f"Device ID: {device_context['deviceId']}")
    print(f"User ID: {device_context['user_id']}")
    print(f"Form ID: {device_context['form_id']}")
    print(f"LED IP: {LED_CONTROLLER_IP}")
    print(f"LED Enabled: {LED_INTEGRATION_ENABLED}")
    print(f"Total readings: {total_readings}")
    print(f"Each reading = {SIMULATED_MINUTES_PER_READING} simulated minutes")
    print(f"Real delay = {delay_seconds} seconds")
    print("=" * 70)

    last_led_scene = None

    for step, simulated_time, sensor in generate_live_readings(
        persona_key,
        total_readings,
    ):
        print(f"\n[{step}/{total_readings}] Simulated time: {simulated_time.isoformat()}")

        flags = predict_alerts(sensor, profile)
        indices = compute_indices(sensor, profile)
        recommendations = build_recommendations(flags, indices, sensor, profile)

        light_action = evaluate_light(
            sensor,
            profile,
            flags,
            hour=simulated_time.hour,
            user_intent=None,
            follow_routine=FOLLOW_ROUTINE,
        )

        chart_payload = sensor_to_chart_metric(
            sensor=sensor,
            device_context=device_context,
            timestamp=simulated_time,
        )

        try:
            chart_result = await create_chart_metric(chart_payload)
            chart_status = chart_result.get("message", "chart metric saved")
        except Exception as e:
            chart_status = f"FAILED: {e}"

        sent_notifications = await notification_manager.process_notifications(
            device_id=device_context["deviceId"],
            flags=flags,
            sensor=sensor,
            indices=indices,
            create_notification_func=create_notification,
            now=datetime.utcnow(),
        )

        apply_to_smart_light(light_action, SMART_LIGHT_INTEGRATION_ENABLED)

        scene_name = map_light_action_to_scene(light_action, flags)

        # To avoid sending LED command every single reading,
        # apply LED only when scene changes.
        if scene_name != last_led_scene:
            led_ok = apply_light_action_to_led(
                ip=LED_CONTROLLER_IP,
                light_action=light_action,
                flags=flags,
                enabled=LED_INTEGRATION_ENABLED,
            )
            last_led_scene = scene_name
        else:
            led_ok = True
            print(f"[LED] Scene unchanged ({scene_name}) → no new command sent.")

        print("Sensor:", sensor)
        print("Flags:", flags)

        print("Indices:")
        for key in ["DEI", "BLI", "EFI"]:
            item = indices[key]
            print(f"  - {key}: {item['score']}/100 ({item['level']}) ratio={item['ratio']}")

        print("Top recommendations:")
        for rec in recommendations[:3]:
            print(f"  - [{rec.get('code')}] P{rec.get('priority')}: {rec.get('message')}")

        print(
            f"Smart light: {light_action.intent} | "
            f"brightness={light_action.brightness_pct}% | "
            f"reason={light_action.reason}"
        )

        print(f"LED scene: {scene_name} | applied={led_ok}")
        print("Chart:", chart_status)

        if sent_notifications:
            print("Notifications sent:")
            for notification in sent_notifications:
                print(
                    f"  - {notification['metric_name']} | "
                    f"value={notification['critical_value']} | "
                    f"{notification['message']}"
                )
        else:
            print("Notifications sent: none")

        await asyncio.sleep(delay_seconds)

    print("\nDemo finished.")


# =========================================================
# CLI
# =========================================================

def parse_args():
    parser = argparse.ArgumentParser(description="ClipView live demo stream")

    parser.add_argument(
        "--persona",
        choices=list(PERSONAS.keys()),
        default="normal",
        help="Persona to simulate: normal, post_lasik, dry_eye",
    )

    parser.add_argument(
        "--readings",
        type=int,
        default=DEFAULT_TOTAL_READINGS,
        help="Number of live readings to generate",
    )

    parser.add_argument(
        "--delay",
        type=int,
        default=REAL_DELAY_SECONDS,
        help="Real seconds between readings",
    )

    parser.add_argument(
        "--persistence",
        type=int,
        default=2,
        help="Consecutive readings required before notification",
    )

    parser.add_argument(
        "--cooldown",
        type=int,
        default=15,
        help="Cooldown minutes per metric",
    )

    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()

    asyncio.run(
        run_demo(
            persona_key=args.persona,
            total_readings=args.readings,
            delay_seconds=args.delay,
            persistence_required=args.persistence,
            cooldown_minutes=args.cooldown,
        )
    )