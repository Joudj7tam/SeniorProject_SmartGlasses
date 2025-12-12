# ==========================================================
# test_rules.py
# Unit tests for the Rules Engine
# ==========================================================

import pytest
from monitoring.rules import evaluate_rules, LAST_ALERT


# Reset cooldowns before each test
@pytest.fixture(autouse=True)
def reset_cooldowns():
    for key in LAST_ALERT:
        LAST_ALERT[key] = 0


# Helper to extract metric_name
def get_metric_name(mock_notify):
    args, kwargs = mock_notify.call_args
    return args[0]["metric_name"]


# ----------------------------------------------------------
# TC_R1 - Short IBI → Dry Eye Alert
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_short_ibi_triggers_dry_eye(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 1.5,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "IBI_short"


# ----------------------------------------------------------
# TC_R2 - Long IBI → Evaporative Dryness
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_long_ibi_triggers_evaporative(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 15,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "IBI_long"


# ----------------------------------------------------------
# TC_R3 - Low blink rate (<4)
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_low_blink_rate(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 2,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "low_blink_rate"


# ----------------------------------------------------------
# TC_R4 - Fatigue (IBI 8–12)
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_fatigue_range(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 10,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "fatigue_concentration"


# ----------------------------------------------------------
# TC_R5 - Long exposure + blue light
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_long_exposure(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.5,
        "session_time": 150,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "long_exposure"


# ----------------------------------------------------------
# TC_R6 - Low light
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_low_light(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 100,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "low_light"


# ----------------------------------------------------------
# TC_R7 - High light
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_high_light(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 1000,
        "blue_ratio": 0.1,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "high_light"


# ----------------------------------------------------------
# TC_R8 - High blue light only
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_blue_only(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 300,
        "blue_ratio": 0.45,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "blue_light_only"


# ----------------------------------------------------------
# TC_R9 - Blue + dark
# ----------------------------------------------------------
@pytest.mark.asyncio
async def test_blue_and_dark(mocker):
    mock_notify = mocker.patch("monitoring.rules.create_notification")

    metrics = {
        "ibi": 6,
        "blink_rate": 8,
        "ibi_variance": 0,
        "lux": 100,
        "blue_ratio": 0.45,
        "session_time": 10,
    }

    await evaluate_rules(metrics)

    mock_notify.assert_called_once()
    assert get_metric_name(mock_notify) == "blue_and_dark"
# ==========================================================