def build_recommendations(
    pred_flags: dict,
    indices: dict | None = None,
    sensor: dict | None = None,
    profile: dict | None = None
):
    """
    Updated:
    - uses blink / blue / focus flags
    - also uses humidity + temperature for environment-aware recommendations
    """
    recs = []

    humidity = None
    temperature = None
    has_dry_eye = 0

    if sensor:
        humidity = float(sensor.get("humidity", 45))
        temperature = float(sensor.get("temperature", 24))

    if profile:
        has_dry_eye = int(profile.get("has_dry_eye_condition", 0))

    # 0) Index summary
    if indices:
        for k in ["DEI", "BLI", "EFI"]:
            s = indices[k]["score"]
            lvl = indices[k]["level"]
            recs.append({
                "code": f"{k}_INDEX",
                "message": f"{k} = {s}/100 ({lvl})",
                "priority": 4
            })

    # Base FR18–FR20 messages
    if pred_flags.get("blink_low") == 1:
        recs.append({
            "code": "BLINK_LOW",
            "message": "Your blink rate seems low. Consider blinking exercises and hydration.",
            "priority": 2
        })

    if pred_flags.get("blue_high") == 1:
        recs.append({
            "code": "BLUE_HIGH",
            "message": "High blue-light exposure detected. Lower screen brightness or enable night mode.",
            "priority": 2
        })

    if pred_flags.get("focus_too_long") == 1:
        recs.append({
            "code": "FOCUS_TOO_LONG",
            "message": "You’ve been focusing for a long time. Take a short break using the 20-20-20 rule.",
            "priority": 2
        })

    # Combined logic
    if pred_flags.get("blink_low") == 1 and pred_flags.get("blue_high") == 1:
        recs.append({
            "code": "OVERFOCUS",
            "message": "Possible overfocus detected: low blinking + high blue light. Take a break now.",
            "priority": 3
        })

    # Environment-aware recommendations
    if humidity is not None:
        if humidity < 30:
            recs.append({
                "code": "LOW_HUMIDITY",
                "message": "The air appears dry (low humidity), which may increase tear evaporation. Consider hydration, artificial tears, or a humidifier.",
                "priority": 3 if has_dry_eye else 2
            })
        elif humidity < 40:
            recs.append({
                "code": "MID_LOW_HUMIDITY",
                "message": "Humidity is slightly low, which may contribute to eye dryness during screen use.",
                "priority": 1
            })

    if temperature is not None:
        if temperature > 30:
            recs.append({
                "code": "HIGH_TEMP",
                "message": "The surrounding temperature is relatively high, which may mildly worsen dryness, especially with screen use.",
                "priority": 2
            })
        elif temperature > 27 and humidity is not None and humidity < 35:
            recs.append({
                "code": "WARM_DRY_ENV",
                "message": "A warm and dry environment is detected. This combination may worsen eye dryness.",
                "priority": 3
            })

    if has_dry_eye == 1 and humidity is not None and humidity < 35:
        recs.append({
            "code": "DRY_EYE_ENV_ALERT",
            "message": "Because the user profile indicates dry-eye sensitivity, the current environment may increase discomfort faster than usual.",
            "priority": 3
        })

    recs.sort(key=lambda x: x["priority"], reverse=True)
    return recs