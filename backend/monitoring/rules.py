# without humidity and temperature values.
# rules.py
# =======================================================
# This file contains:
# - All thresholds
# - Cooldown times
# - Decision-making rules
# - Emoji severity levels
# - Notification formatting
# =======================================================

import time
from Controllers.notification_controller import create_notification

USER_ID = "test_user_001"

# --------------------------------------------------------
# Threshold constants — easy to modify later
# --------------------------------------------------------
THRESHOLDS = {
    "DRY_EYE_IBI": 3,        # IBI < 3 seconds → dry eye risk
    "EVAP_DRY_EYE_IBI": 12,  # IBI > 12 sec → evaporative dryness
    "HIGH_CONCENTRATION_IBI_MIN": 8,
    "HIGH_CONCENTRATION_IBI_MAX": 12,
    "LOW_BLINK_RATE": 4,     # blinks per min
    "BLUE_RATIO_HIGH": 0.30,
    "TOO_DARK_LUX": 150,
    "TOO_BRIGHT_LUX": 750,
    "COMFORT_LIGHT_MIN": 200,
    "COMFORT_LIGHT_MAX": 500,
    "LONG_EXPOSURE_MIN": 120  # minutes
}

# --------------------------------------------------------
# Cooldowns (seconds)
# --------------------------------------------------------
COOLDOWNS = {
    "dry_eye": 300,      # 5 minutes     
    "fatigue": 600,      # 10 minutes
    "light_low": 180,    # 3 minutes       
    "light_high": 180,   # 3 minutes       
    "blue_only": 300,    # 5 minutes    
    "blue_combined": 420 # 7 minutes     
}

# Store timestamps of last notifications
LAST_ALERT = {key: 0 for key in COOLDOWNS.keys()}

# --------------------------------------------------------
# Emoji levels
# --------------------------------------------------------
EMOJI = {
    "medium": "⚠️",
    "high": "🚨"
}

# --------------------------------------------------------
# Helper: Check cooldown
# --------------------------------------------------------
def is_in_cooldown(alert_type):
    now = time.time()
    last = LAST_ALERT.get(alert_type, 0)
    return (now - last) < COOLDOWNS[alert_type]

def record_cooldown(alert_type):
    LAST_ALERT[alert_type] = time.time()

# --------------------------------------------------------
# Helper: Send notification to DB
# --------------------------------------------------------
async def send_notification(alert_type, title, message, metric_name, critical_value):
    notification = {
        "userId": USER_ID,
        "title": title,
        "message": message,
        "metric_name": metric_name,
        "metric_value": critical_value,
        "isRead": False
    }
    await create_notification(notification)

# --------------------------------------------------------
# Main rules engine
# --------------------------------------------------------
async def evaluate_rules(metrics):

    ibi = metrics["ibi"]
    blink_rate = metrics["blink_rate"]
    lux = metrics["lux"]
    blue = metrics["blue_ratio"]
    session_time = metrics["session_time"]

    # ---------------------------------------------------------
    # 0) Composite Rules FIRST
    # ---------------------------------------------------------

    # Blue + dark
    if blue > THRESHOLDS["BLUE_RATIO_HIGH"] and lux < THRESHOLDS["TOO_DARK_LUX"]:
        if not is_in_cooldown("blue_combined"):
            await send_notification(
                "blue_combined",
                f"{EMOJI['high']} Blue Light in Dark Environment",
                "High blue light with low ambient light. Eye strain risk increased.",
                "blue_and_dark",
                blue,
            )
            record_cooldown("blue_combined")
        return

    # Long exposure + blue
    if session_time > THRESHOLDS["LONG_EXPOSURE_MIN"] and blue > THRESHOLDS["BLUE_RATIO_HIGH"]:
        if not is_in_cooldown("fatigue"):
            await send_notification(
                "fatigue",
                f"{EMOJI['high']} Prolonged Screen Exposure",
                "More than 2 hours of blue-heavy exposure detected.",
                "long_exposure",
                session_time,
            )
            record_cooldown("fatigue")
        return

    # ---------------------------------------------------------
    # 1) Dry Eye Alerts
    # ---------------------------------------------------------
    if ibi is not None:

        if ibi < THRESHOLDS["DRY_EYE_IBI"]:
            if not is_in_cooldown("dry_eye"):
                await send_notification(
                    "dry_eye",
                    f"{EMOJI['high']} Dry Eye Alert",
                    f"Inter-blink interval too short ({ibi:.1f}s). Possible dry eye.",
                    "IBI_short",
                    ibi
                )
                record_cooldown("dry_eye")

        if ibi > THRESHOLDS["EVAP_DRY_EYE_IBI"]:
            if not is_in_cooldown("dry_eye"):
                await send_notification(
                    "dry_eye",
                    f"{EMOJI['high']} Evaporative Dry Eye",
                    f"Long inter-blink interval ({ibi:.1f}s). Tear film evaporation risk.",
                    "IBI_long",
                    ibi
                )
                record_cooldown("dry_eye")

    # Low blink rate
    if blink_rate < THRESHOLDS["LOW_BLINK_RATE"]:
        if not is_in_cooldown("dry_eye"):
            await send_notification(
                "dry_eye",
                f"{EMOJI['high']} Low Blink Rate",
                f"Blink rate is low ({blink_rate:.1f} blinks/min). Eye dryness risk.",
                "low_blink_rate",
                blink_rate
            )
            record_cooldown("dry_eye")

    # ---------------------------------------------------------
    # 2) Fatigue (IBI concentration)
    # ---------------------------------------------------------
    if ibi is not None and THRESHOLDS["HIGH_CONCENTRATION_IBI_MIN"] <= ibi <= THRESHOLDS["HIGH_CONCENTRATION_IBI_MAX"]:
        if not is_in_cooldown("fatigue"):
            await send_notification(
                "fatigue",
                f"{EMOJI['medium']} Eye Fatigue Detected",
                f"High concentration detected (IBI: {ibi:.1f}s). Eye strain possible.",
                "fatigue_concentration",
                ibi
            )
            record_cooldown("fatigue")

    # ---------------------------------------------------------
    # 3) Ambient Light Alerts
    # ---------------------------------------------------------
    if lux < THRESHOLDS["TOO_DARK_LUX"]:
        if not is_in_cooldown("light_low"):
            await send_notification(
                "light_low",
                f"{EMOJI['medium']} Low Ambient Light",
                f"Ambient light is too low ({lux:.0f} lux). Screen strain increases.",
                "low_light",
                lux
            )
            record_cooldown("light_low")

    if lux > THRESHOLDS["TOO_BRIGHT_LUX"]:
        if not is_in_cooldown("light_high"):
            await send_notification(
                "light_high",
                f"{EMOJI['medium']} High Ambient Light",
                f"Ambient light too high ({lux:.0f} lux). Glare risk.",
                "high_light",
                lux
            )
            record_cooldown("light_high")

    # ---------------------------------------------------------
    # 4) Blue-only (ONLY if no composite was triggered)
    # ---------------------------------------------------------
    if blue > THRESHOLDS["BLUE_RATIO_HIGH"]:
        if not is_in_cooldown("blue_only"):
            await send_notification(
                "blue_only",
                f"{EMOJI['medium']} High Blue Light",
                f"High blue light ratio detected ({blue:.2f}).",
                "blue_light_only",
                blue
            )
            record_cooldown("blue_only")
