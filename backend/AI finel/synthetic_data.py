import numpy as np
import pandas as pd

# -----------------------------
# 1) Define schema (source of truth)
# -----------------------------
LABEL_COLUMNS = ["blink_low", "blue_high", "focus_too_long"]

FEATURE_COLUMNS = [
    # sensor window features
    "blink_rate_bpm",
    "blue_lux",
    "focus_minutes",
    "ambient_lux",
    "humidity",
    "temperature",

    # profile thresholds (personalization)
    "min_safe_blink_bpm",
    "max_safe_blue",
    "max_safe_focus_min",

    # optional profile flags (personal sensitivity)
    "has_eye_surgery",
    "has_dry_eye_condition",
    "wears_protective_glasses",

    # engineered deltas (super important)
    "blink_deficit",
    "blue_excess",
    "focus_excess",
]


def generate_profiles(n_profiles: int, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)

    profiles = pd.DataFrame({
        "profile_id": np.arange(n_profiles),

        # personalized thresholds (example ranges)
        "min_safe_blink_bpm": rng.integers(8, 18, size=n_profiles),
        "max_safe_blue": rng.integers(200, 800, size=n_profiles),
        "max_safe_focus_min": rng.integers(20, 60, size=n_profiles),

        # health flags
        "has_eye_surgery": rng.integers(0, 2, size=n_profiles),
        "has_dry_eye_condition": rng.integers(0, 2, size=n_profiles),
        "wears_protective_glasses": rng.integers(0, 2, size=n_profiles),
    })
    return profiles

def generate_sensor_windows(profiles: pd.DataFrame,
                            windows_per_profile: int,
                            seed: int = 7) -> pd.DataFrame:
    """
    Generates sensor "windows" per profile.
    Each row ~ one time window (e.g., last 1-5 minutes summary).

    Updated logic:
    - low humidity -> more tear evaporation risk
    - higher temperature -> mild extra dryness risk
    - low humidity + high temperature together -> stronger effect
    """
    rng = np.random.default_rng(seed)
    rows = []

    for _, p in profiles.iterrows():
        for _w in range(windows_per_profile):
            # environmental signals
            humidity = float(np.clip(rng.normal(45, 12), 10, 90))
            temperature = float(np.clip(rng.normal(24, 3), 15, 35))
            ambient_lux = float(np.clip(rng.normal(500, 300), 0, 2000))

            # blue light influenced by ambient + "devices"
            blue_lux = float(np.clip(rng.normal(450, 220) + (ambient_lux * 0.2), 0, 2000))
            if int(p["wears_protective_glasses"]) == 1:
                blue_lux *= 0.85

            # focus duration window (minutes)
            focus_minutes = float(np.clip(rng.normal(35, 15), 1, 120))

            # ----------------------------- 
            # Research-inspired environment effect
            # -----------------------------
            # lower humidity = higher evaporation risk
            humidity_penalty = max(0.0, (40.0 - humidity)) * 0.05

            # warmer room = mild extra evaporation risk
            temperature_penalty = max(0.0, (temperature - 25.0)) * 0.12

            # low humidity + warm temperature together = stronger effect
            combo_penalty = 0.8 if (humidity < 30 and temperature > 28) else 0.0

            # blink rate tends to drop with:
            # - lower humidity
            # - longer focus
            # - slightly warmer/drier environment
            blink_rate = (
                rng.normal(14, 4)
                - humidity_penalty
                - (focus_minutes * 0.02)
                - temperature_penalty
                - combo_penalty
            )

            if int(p["has_dry_eye_condition"]) == 1:
                blink_rate -= 0.7

            blink_rate_bpm = float(np.clip(blink_rate, 2, 30))

            rows.append({
                "profile_id": int(p["profile_id"]),
                "blink_rate_bpm": blink_rate_bpm,
                "blue_lux": blue_lux,
                "focus_minutes": focus_minutes,
                "ambient_lux": ambient_lux,
                "humidity": humidity,
                "temperature": temperature,
            })

    return pd.DataFrame(rows)

def build_features(sensor_df: pd.DataFrame, profiles_df: pd.DataFrame) -> pd.DataFrame:
    """
    Join sensor windows + profiles, then compute engineered features.
    Output X with FEATURE_COLUMNS only (order matters).
    """
    df = sensor_df.merge(profiles_df, on="profile_id", how="left")

    # engineered deltas (key for personalization)
    df["blink_deficit"] = df["min_safe_blink_bpm"] - df["blink_rate_bpm"]
    df["blue_excess"] = df["blue_lux"] - df["max_safe_blue"]
    df["focus_excess"] = df["focus_minutes"] - df["max_safe_focus_min"]

    # Return exactly the features (X)
    return df[FEATURE_COLUMNS].copy()


def build_labels(sensor_df: pd.DataFrame, profiles_df: pd.DataFrame) -> pd.DataFrame:
    """
    Create the ground-truth Y using your Functional Requirements rules.
    """
    df = sensor_df.merge(profiles_df, on="profile_id", how="left")

    y = pd.DataFrame({
        # FR18
        "blink_low": (df["blink_rate_bpm"] < df["min_safe_blink_bpm"]).astype(int),
        # FR19
        "blue_high": (df["blue_lux"] > df["max_safe_blue"]).astype(int),
        # FR20
        "focus_too_long": (df["focus_minutes"] > df["max_safe_focus_min"]).astype(int),
    })
    return y[LABEL_COLUMNS].copy()


def generate_dataset(n_profiles: int = 50,
                     windows_per_profile: int = 100,
                     seed_profiles: int = 42,
                     seed_sensors: int = 7):
    profiles = generate_profiles(n_profiles=n_profiles, seed=seed_profiles)
    sensors = generate_sensor_windows(profiles=profiles, windows_per_profile=windows_per_profile, seed=seed_sensors)

    X = build_features(sensors, profiles)
    Y = build_labels(sensors, profiles)

    return X, Y
