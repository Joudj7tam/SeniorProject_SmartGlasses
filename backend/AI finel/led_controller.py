# led_controller.py

from dataclasses import dataclass
from typing import Tuple, Optional


try:
    from flux_led import WifiLedBulb
except ImportError:
    WifiLedBulb = None


@dataclass
class LedScene:
    name: str
    rgb: Tuple[int, int, int]
    brightness: int
    reason: str


# =========================================================
# CLIPVIEW LIGHTING SCENES
# =========================================================
# These colors are demo-friendly and research-inspired:
#
# - Less blue / warmer lighting when eye strain is detected.
# - Amber / red-orange lighting for recovery and night protection.
# - Warm-neutral lighting for focus support without harsh blue stimulation.
#
# NOTE:
# RGB strips can look different depending on hardware quality.
# If amber still looks too white, reduce green more.
# Example: (255, 45, 0) instead of (255, 70, 0)
# =========================================================

SCENES = {
    "normal": LedScene(
        name="normal",
        rgb=(255, 210, 130),
        brightness=55,
        reason="Warm balanced lighting for normal safe readings.",
    ),

    "focus_support": LedScene(
        name="focus_support",
        rgb=(255, 180, 80),
        brightness=65,
        reason="Warm focus-support lighting for productivity without strong blue stimulation.",
    ),

    "recovery": LedScene(
        name="recovery",
        rgb=(255, 70, 0),
        brightness=45,
        reason="Deep amber recovery lighting for low blink rate or dry-eye strain.",
    ),

    "night_protection": LedScene(
        name="night_protection",
        rgb=(180, 35, 0),
        brightness=30,
        reason="Deep red-orange lighting for high blue-light exposure or evening protection.",
    ),

    "soft_alert": LedScene(
        name="soft_alert",
        rgb=(255, 20, 0),
        brightness=40,
        reason="Soft red-orange alert lighting for combined high eye-strain risk.",
    ),
}


# =========================================================
# INTERNAL HELPERS
# =========================================================

def _require_flux_led():
    if WifiLedBulb is None:
        raise ImportError(
            "flux_led is not installed. Run this command:\n"
            "pip install flux-led"
        )


def scale_rgb(rgb: Tuple[int, int, int], brightness: int) -> Tuple[int, int, int]:
    """
    Scale RGB values based on brightness percentage.

    Some LED controllers do not handle brightness separately very well.
    So we apply brightness by scaling the RGB values directly.
    """

    brightness = max(1, min(100, int(brightness)))
    factor = brightness / 100.0

    return tuple(
        max(0, min(255, int(channel * factor)))
        for channel in rgb
    )


def connect_bulb(ip: str):
    """
    Connect to Magic Home / Flux LED compatible controller.
    """

    _require_flux_led()

    print(f"[LED] Connecting to controller at {ip} ...")
    bulb = WifiLedBulb(ip)

    return bulb


# =========================================================
# BASIC LED ACTIONS
# =========================================================

def turn_on(ip: str) -> bool:
    try:
        bulb = connect_bulb(ip)

        if hasattr(bulb, "turnOn"):
            bulb.turnOn()
        elif hasattr(bulb, "turn_on"):
            bulb.turn_on()
        else:
            print("[LED] No turn on method found.")
            return False

        print("[LED] Turned ON")
        return True

    except Exception as e:
        print(f"[LED] Failed to turn ON: {e}")
        return False


def turn_off(ip: str) -> bool:
    try:
        bulb = connect_bulb(ip)

        if hasattr(bulb, "turnOff"):
            bulb.turnOff()
        elif hasattr(bulb, "turn_off"):
            bulb.turn_off()
        else:
            print("[LED] No turn off method found.")
            return False

        print("[LED] Turned OFF")
        return True

    except Exception as e:
        print(f"[LED] Failed to turn OFF: {e}")
        return False


def set_rgb(ip: str, rgb: Tuple[int, int, int], brightness: int = 60) -> bool:
    """
    Set LED color.

    Example:
        rgb=(255, 70, 0), brightness=45
        gives deep amber / orange recovery lighting.
    """

    try:
        bulb = connect_bulb(ip)

        scaled_rgb = scale_rgb(rgb, brightness)
        r, g, b = scaled_rgb

        print(f"[LED] Setting RGB={scaled_rgb}, brightness={brightness}%")

        if hasattr(bulb, "turnOn"):
            bulb.turnOn()
        elif hasattr(bulb, "turn_on"):
            bulb.turn_on()

        if hasattr(bulb, "setRgb"):
            bulb.setRgb(r, g, b)
        elif hasattr(bulb, "set_rgb"):
            bulb.set_rgb(r, g, b)
        else:
            print("[LED] No RGB method found.")
            return False

        print("[LED] Color applied successfully")
        return True

    except Exception as e:
        print(f"[LED] Failed to set RGB: {e}")
        return False


# =========================================================
# SCENE ACTIONS
# =========================================================

def apply_scene(ip: str, scene_name: str) -> bool:
    """
    Apply one predefined ClipView lighting scene.
    """

    if scene_name not in SCENES:
        print(f"[LED] Unknown scene: {scene_name}")
        print(f"[LED] Available scenes: {list(SCENES.keys())}")
        return False

    scene = SCENES[scene_name]

    print("=" * 60)
    print(f"[LED] Applying scene: {scene.name}")
    print(f"[LED] Reason: {scene.reason}")
    print("=" * 60)

    return set_rgb(ip, scene.rgb, scene.brightness)


def map_light_action_to_scene(light_action, flags: Optional[dict] = None) -> str:
    """
    Convert smart_light.py decision + AI flags into a physical LED scene.

    Priority:
    1. All risks high      → soft_alert
    2. Low blink/focus     → recovery
    3. High blue only      → night_protection
    4. Intent-based scene  → from smart_light.py
    5. Default             → normal
    """

    flags = flags or {}

    blink_low = int(flags.get("blink_low", 0)) == 1
    blue_high = int(flags.get("blue_high", 0)) == 1
    focus_too_long = int(flags.get("focus_too_long", 0)) == 1

    if blink_low and blue_high and focus_too_long:
        return "soft_alert"

    if blink_low or focus_too_long:
        return "recovery"

    if blue_high:
        return "night_protection"

    intent = getattr(light_action, "intent", "")
    intent = str(intent).lower()

    if "night" in intent or "sleep" in intent:
        return "night_protection"

    if "recovery" in intent:
        return "recovery"

    if "focus" in intent or "work" in intent:
        return "focus_support"

    return "normal"


def apply_light_action_to_led(
    ip: str,
    light_action,
    flags: Optional[dict] = None,
    enabled: bool = True,
) -> bool:
    """
    Called from demo_stream.py.

    Example:
        light_action = evaluate_light(...)
        apply_light_action_to_led(ip, light_action, flags, enabled=True)
    """

    if not enabled:
        print("[LED] LED integration disabled.")
        return False

    scene_name = map_light_action_to_scene(light_action, flags)
    return apply_scene(ip, scene_name)