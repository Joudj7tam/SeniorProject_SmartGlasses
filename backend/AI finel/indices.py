# indices.py
from typing import Dict

def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))

def _ratio_to_score(ratio: float) -> int:
    """
    Mapping:
      ratio = 1.0  -> score 50  (at the user's safe limit)
      ratio = 2.0  -> score 100 (about 2x the limit)
    """
    return int(round(_clamp(ratio * 50.0, 0.0, 100.0)))

def _score_level(score: int) -> str:
    if score >= 80: return "VERY_HIGH"
    if score >= 60: return "HIGH"
    if score >= 40: return "MODERATE"
    return "LOW"

def compute_indices(sensor: Dict, profile: Dict) -> Dict:
    """
    Returns dict:
      {
        "DEI": {"score": int, "level": str, "ratio": float},
        "BLI": {"score": int, "level": str, "ratio": float},
        "EFI": {"score": int, "level": str, "ratio": float},
      }

    Updated logic:
    - DEI now uses blink + humidity + temperature + profile sensitivity
    - low humidity and higher temperature slightly increase dryness risk
    """
    blink = float(sensor["blink_rate_bpm"])
    blue = float(sensor["blue_lux"])
    focus = float(sensor["focus_minutes"])
    humidity = float(sensor.get("humidity", 45))
    temperature = float(sensor.get("temperature", 24))

    min_blink = float(profile["min_safe_blink_bpm"])
    max_blue = float(profile["max_safe_blue"])
    max_focus = float(profile["max_safe_focus_min"])

    # -----------------------------
    # Base ratios
    # -----------------------------
    dei_ratio = min_blink / max(blink, 0.1)
    bli_ratio = blue / max(max_blue, 0.1)
    efi_ratio = focus / max(max_focus, 0.1)

    # -----------------------------
    # Research-inspired DEI modifiers
    # -----------------------------
    humidity_factor = 1.0
    if humidity < 20:
        humidity_factor = 1.30
    elif humidity < 30:
        humidity_factor = 1.20
    elif humidity < 40:
        humidity_factor = 1.10

    temperature_factor = 1.0
    if temperature > 30:
        temperature_factor = 1.12
    elif temperature > 27:
        temperature_factor = 1.07

    combo_factor = 1.05 if (humidity < 30 and temperature > 28) else 1.0

    dry_eye_factor = 1.10 if int(profile.get("has_dry_eye_condition", 0)) == 1 else 1.0
    surgery_factor = 1.05 if int(profile.get("has_eye_surgery", 0)) == 1 else 1.0

    dei_ratio *= humidity_factor * temperature_factor * combo_factor * dry_eye_factor * surgery_factor

    dei_score = _ratio_to_score(dei_ratio)
    bli_score = _ratio_to_score(bli_ratio)
    efi_score = _ratio_to_score(efi_ratio)

    return {
        "DEI": {
            "score": dei_score,
            "level": _score_level(dei_score),
            "ratio": round(dei_ratio, 3),
        },
        "BLI": {
            "score": bli_score,
            "level": _score_level(bli_score),
            "ratio": round(bli_ratio, 3),
        },
        "EFI": {
            "score": efi_score,
            "level": _score_level(efi_score),
            "ratio": round(efi_ratio, 3),
        },
    }
    """
    Returns dict:
      {
        "DEI": {"score": int, "level": str, "ratio": float},
        "BLI": {"score": int, "level": str, "ratio": float},
        "EFI": {"score": int, "level": str, "ratio": float},
      }
    """
    blink = float(sensor["blink_rate_bpm"])
    blue  = float(sensor["blue_lux"])
    focus = float(sensor["focus_minutes"])

    min_blink = float(profile["min_safe_blink_bpm"])
    max_blue  = float(profile["max_safe_blue"])
    max_focus = float(profile["max_safe_focus_min"])

    # Ratios (personalized)
    # DEI: higher ratio means blink is lower than safe → dryness risk higher
    dei_ratio = min_blink / max(blink, 0.1)

    # Optional: dry-eye condition increases sensitivity slightly
    if int(profile.get("has_dry_eye_condition", 0)) == 1:
        dei_ratio *= 1.10

    # BLI: higher ratio means blue exposure above safe limit
    bli_ratio = blue / max(max_blue, 0.1)

    # EFI: higher ratio means continuous focus above safe limit
    efi_ratio = focus / max(max_focus, 0.1)

    dei_score = _ratio_to_score(dei_ratio)
    bli_score = _ratio_to_score(bli_ratio)
    efi_score = _ratio_to_score(efi_ratio)

    return {
        "DEI": {"score": dei_score, "level": _score_level(dei_score), "ratio": round(dei_ratio, 3)},
        "BLI": {"score": bli_score, "level": _score_level(bli_score), "ratio": round(bli_ratio, 3)},
        "EFI": {"score": efi_score, "level": _score_level(efi_score), "ratio": round(efi_ratio, 3)},
    }