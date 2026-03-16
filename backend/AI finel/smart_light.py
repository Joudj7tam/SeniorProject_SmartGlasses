# smart_light.py
from dataclasses import dataclass
from datetime import datetime
from typing import Optional, Dict, Tuple

# -----------------------------
# Smart-Light "Action" output
# -----------------------------
@dataclass
class LightAction:
    mode: str                 # AUTO / TASK_OVERRIDE
    intent: str               # SLEEP / RELAX / WORK / STUDY / DEFAULT
    rgb: Tuple[int, int, int]
    brightness_pct: int
    duration_min: int         # for override; 0 means not timed
    reason: str               # short explanation


def _time_phase(hour: int) -> str:
    # You can adjust these boundaries later
    if hour >= 22 or hour < 6:
        return "NIGHT"
    if 18 <= hour < 22:
        return "EVENING"
    if 6 <= hour < 10:
        return "MORNING"
    return "DAY"


def _auto_intent_from_phase(phase: str) -> str:
    if phase == "NIGHT":
        return "SLEEP"
    if phase == "EVENING":
        return "RELAX"
    # MORNING/DAY
    return "WORK"


def evaluate_light(
    sensor: Dict,
    profile: Dict,
    flags: Dict,
    *,
    hour: Optional[int] = None,
    user_intent: Optional[str] = None,   # e.g., "WORK" / "STUDY" / "RELAX" / "SLEEP"
    follow_routine: bool = True,
    override_duration_min: int = 90
) -> LightAction:
    """
    Smart-Light evaluation rules (FR Smart-Light):
    - Uses existing AI flags + current sensor readings
    - Adds: time phase + optional user intent override
    - Returns a LightAction that you can PRINT now or SEND to LED later
    """
    # ---- context ----
    if hour is None:
        hour = datetime.now().hour
    phase = _time_phase(hour)

    # intent selection
    mode = "AUTO"
    if user_intent:
        mode = "TASK_OVERRIDE"
        intent = user_intent.upper()
    else:
        intent = _auto_intent_from_phase(phase) if follow_routine else "DEFAULT"

    # ---- sensor readings we already have in your project ----
    blue_lux = float(sensor.get("blue_lux", 0))
    ambient_lux = float(sensor.get("ambient_lux", 0))

    # ---- personalization thresholds (already in your profile) ----
    max_safe_blue = float(profile.get("max_safe_blue", 500))

    blue_excess = blue_lux - max_safe_blue

    # -----------------------------
    # Priority rules (important!)
    # -----------------------------

    # P1: Night protection (minimize blue at night)
    if phase == "NIGHT":
        # If blue is high at night OR no override -> sleep-safe
        if flags.get("blue_high") == 1 or blue_excess > 0:
            # If user explicitly says WORK/STUDY at night: keep it warm-neutral but brighter (still low-blue)
            if intent in {"WORK", "STUDY"}:
                return LightAction(
                    mode=mode,
                    intent=intent,
                    rgb=(255, 220, 180),          # warm neutral
                    brightness_pct=65,
                    duration_min=override_duration_min,
                    reason="Night + high blue risk, but user is working → warm-neutral (low blue) with enough brightness."
                )
            # Otherwise: sleep-safe amber
            return LightAction(
                mode=mode,
                intent="SLEEP",
                rgb=(255, 170, 60),               # amber
                brightness_pct=20,
                duration_min=0,
                reason="Night + high blue exposure → amber + dim to reduce melatonin disruption."
            )

    # P2: Glare / too-bright comfort
    if ambient_lux > 1400:
        return LightAction(
            mode=mode,
            intent=intent,
            rgb=(255, 255, 255),
            brightness_pct=35,
            duration_min=override_duration_min if mode == "TASK_OVERRIDE" else 0,
            reason="Very bright environment (glare risk) → reduce brightness."
        )

    # P3: Overfocus / low blink recovery
    if flags.get("focus_too_long") == 1 or flags.get("blink_low") == 1:
        return LightAction(
            mode=mode,
            intent="RECOVERY",
            rgb=(170, 255, 220),                 # mint
            brightness_pct=40,
            duration_min=15,
            reason="Overfocus/low blink detected → short recovery lighting + break support."
        )

    # P4: Daytime blue-high (still reduce blue, but not necessarily amber)
    if flags.get("blue_high") == 1 or blue_excess > 0:
        return LightAction(
            mode=mode,
            intent=intent,
            rgb=(255, 255, 255),                 # neutral white
            brightness_pct=50,
            duration_min=override_duration_min if mode == "TASK_OVERRIDE" else 0,
            reason="High blue exposure → neutral white + moderate brightness (reduce blue intensity)."
        )

    # Intent-based defaults
    if intent in {"WORK", "STUDY"}:
        return LightAction(
            mode=mode,
            intent=intent,
            rgb=(200, 220, 255),                 # cool-ish
            brightness_pct=80,
            duration_min=override_duration_min if mode == "TASK_OVERRIDE" else 0,
            reason="Focus intent → brighter cool/neutral light for alertness."
        )

    if intent == "RELAX":
        return LightAction(
            mode=mode,
            intent=intent,
            rgb=(255, 170, 60),                  # amber
            brightness_pct=35,
            duration_min=override_duration_min if mode == "TASK_OVERRIDE" else 0,
            reason="Relax intent → warm/amber + lower brightness."
        )

    if intent == "SLEEP":
        return LightAction(
            mode=mode,
            intent=intent,
            rgb=(180, 0, 0),                     # deep red
            brightness_pct=10,
            duration_min=0,
            reason="Sleep intent → deep red + very low brightness."
        )

    # fallback
    return LightAction(
        mode=mode,
        intent="DEFAULT",
        rgb=(255, 255, 255),
        brightness_pct=55,
        duration_min=0,
        reason="No strong risks detected → neutral balanced lighting."
    )


def apply_to_smart_light(action: LightAction, integration_enabled: bool) -> None:
    """
    Placeholder for later (when the LED arrives).
    Right now: we only PRINT what would happen.
    """
    if not integration_enabled:
        print("[SmartLight] Integration disabled → not sending command to device.")
        return

    # Later you will replace this with the actual Wi-Fi/BLE library call:
    # e.g. tuya.set_color(action.rgb); tuya.set_brightness(action.brightness_pct)
    print("[SmartLight] (TODO) Send command to LED:", action)