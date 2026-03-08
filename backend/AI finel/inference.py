import os
import json
import joblib
import pandas as pd

# -----------------------------
# Paths (robust)
# -----------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_PATH = os.path.join(BASE_DIR, "models", "dt_alerts.joblib")
META_PATH = os.path.join(BASE_DIR, "models", "dt_alerts_meta.json")


def load_model():
    if not os.path.exists(MODEL_PATH) or not os.path.exists(META_PATH):
        raise FileNotFoundError(
            "Model files not found. Please run: python train_model.py\n"
            f"Expected:\n- {MODEL_PATH}\n- {META_PATH}"
        )

    model = joblib.load(MODEL_PATH)
    with open(META_PATH, "r", encoding="utf-8") as f:
        meta = json.load(f)
    return model, meta


def build_feature_row(sensor: dict, profile: dict, feature_columns: list) -> pd.DataFrame:
    """
    Build one-row X with the exact same columns used in training.
    sensor:  blink_rate_bpm, blue_lux, focus_minutes, ambient_lux, humidity, temperature
    profile: min_safe_blink_bpm, max_safe_blue, max_safe_focus_min, flags...
    """
    row = {}

    # sensors
    for k in ["blink_rate_bpm", "blue_lux", "focus_minutes", "ambient_lux", "humidity", "temperature"]:
        row[k] = sensor[k]

    # profile thresholds + flags
    for k in [
        "min_safe_blink_bpm",
        "max_safe_blue",
        "max_safe_focus_min",
        "has_eye_surgery",
        "has_dry_eye_condition",
        "wears_protective_glasses",
    ]:
        row[k] = profile[k]

    # engineered deltas (must match training!)
    row["blink_deficit"] = row["min_safe_blink_bpm"] - row["blink_rate_bpm"]
    row["blue_excess"] = row["blue_lux"] - row["max_safe_blue"]
    row["focus_excess"] = row["focus_minutes"] - row["max_safe_focus_min"]

    X = pd.DataFrame([row])

    # enforce exact column order
    return X[feature_columns]


def predict_alerts(sensor: dict, profile: dict) -> dict:
    model, meta = load_model()
    X = build_feature_row(sensor, profile, meta["feature_columns"])
    pred = model.predict(X)[0]  # e.g. [1,0,1]
    return {name: int(pred[i]) for i, name in enumerate(meta["label_columns"])}


def main():
    from indices import compute_indices
    from recommendation import build_recommendations
    from smart_light import evaluate_light, apply_to_smart_light

    # -----------------------------
    # Demo scenario (edit anytime)
    # -----------------------------
    sensor_demo = {
        "blink_rate_bpm": 6,
        "blue_lux": 900,
        "focus_minutes": 70,
        "ambient_lux": 800,
        "humidity": 25,
        "temperature": 26,
    }

    profile_demo = {
        "min_safe_blink_bpm": 12,
        "max_safe_blue": 500,
        "max_safe_focus_min": 40,
        "has_eye_surgery": 1,
        "has_dry_eye_condition": 1,
        "wears_protective_glasses": 0,
    }

    # toggles (for later hardware integration)
    SMART_LIGHT_INTEGRATION_ENABLED = False   # set True later when LED arrives
    FOLLOW_ROUTINE = True

    # 1) Predict FR18–FR20 flags
    flags = predict_alerts(sensor_demo, profile_demo)
    print("\nPREDICTED FLAGS:", flags)

    # 2) FR17: compute indices (DEI/BLI/EFI)
    indices = compute_indices(sensor_demo, profile_demo)
    print("\nINDICES (FR17):")
    for k in ["DEI", "BLI", "EFI"]:
        v = indices[k]
        print(f"- {k}: {v['score']}/100 ({v['level']}) [ratio={v['ratio']}]")

    # 3) Recommendations (FR17 + FR18–FR20)
    recs = build_recommendations(flags, indices, sensor_demo, profile_demo)
    print("\nRECOMMENDATIONS:")
    for r in recs:
        # show code + priority so it's obvious in terminal
        code = r.get("code", "N/A")
        pr = r.get("priority", "N/A")
        print(f"- [{code}] (P{pr}) {r['message']}")

    # 4) Smart-Light evaluation (FR12 decision layer) - Scenario A: AUTO Night
    action_auto = evaluate_light(
        sensor_demo,
        profile_demo,
        flags,
        hour=23,                 # simulate night
        user_intent=None,        # auto/routine
        follow_routine=FOLLOW_ROUTINE
    )

    print("\nSMART-LIGHT (AUTO NIGHT):")
    print(f"- Mode: {action_auto.mode} | Intent: {action_auto.intent}")
    print(f"- RGB: {action_auto.rgb} | Brightness: {action_auto.brightness_pct}% | Duration: {action_auto.duration_min} min")
    print(f"- Reason: {action_auto.reason}")
    apply_to_smart_light(action_auto, SMART_LIGHT_INTEGRATION_ENABLED)

    # 5) Smart-Light evaluation - Scenario B: Override WORK at night
    action_override = evaluate_light(
        sensor_demo,
        profile_demo,
        flags,
        hour=23,
        user_intent="WORK",      # override
        follow_routine=FOLLOW_ROUTINE,
        override_duration_min=120
    )

    print("\nSMART-LIGHT (OVERRIDE: WORK @ NIGHT):")
    print(f"- Mode: {action_override.mode} | Intent: {action_override.intent}")
    print(f"- RGB: {action_override.rgb} | Brightness: {action_override.brightness_pct}% | Duration: {action_override.duration_min} min")
    print(f"- Reason: {action_override.reason}")
    apply_to_smart_light(action_override, SMART_LIGHT_INTEGRATION_ENABLED)


if __name__ == "__main__":
    print("=" * 50)
    print("CLIPVIEW AI DEMO RUN")
    print("=" * 50)
    print()
    main()