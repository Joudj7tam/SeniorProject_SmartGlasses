# ==========================================================
# test_metrics.py
# Unit tests for MetricsEngine
# Each test corresponds to a test case in the report
# ==========================================================

import time
import pytest
from monitoring.metrics import MetricsEngine


# ----------------------------------------------------------
# TC_M1 - Test IBI calculation
# ----------------------------------------------------------
def test_update_blink_calculates_ibi(mocker):
    """
    Verify that calling update_blink twice calculates correct IBI.
    blink1 at t=100, blink2 at t=102 => IBI should be 2 seconds.
    """

    m = MetricsEngine()

    # Mock time to control timestamps
    mocker.patch("time.time", return_value=100)
    m.update_blink(True)   # First blink

    mocker.patch("time.time", return_value=102)
    m.update_blink(True)   # Second blink

    assert m.get_latest_ibi() == 2


# ----------------------------------------------------------
# TC_M2 - Test blink rate calculation
# ----------------------------------------------------------
def test_blink_rate(mocker):
    """
    blink_count = 10 blinks in 2 minutes → blink_rate = 5/min
    """

    m = MetricsEngine()

    # Create 10 blinks
    m.blink_count = 10

    # Simulate 2 minutes passing
    m.session_start_time = 0
    mocker.patch("time.time", return_value=120)

    assert m.calculate_blink_rate() == pytest.approx(5)


# ----------------------------------------------------------
# TC_M3 - Test session time
# ----------------------------------------------------------
def test_session_time(mocker):
    """
    Session time = (now - start_time)/60
    start = 0, now = 300s → 5 minutes
    """

    m = MetricsEngine()
    m.session_start_time = 0

    mocker.patch("time.time", return_value=300)

    assert m.get_session_time_minutes() == 5


# ----------------------------------------------------------
# TC_M4 - Test lux calculation
# ----------------------------------------------------------
def test_calculate_lux():
    """
    lux = clear * 0.5
    """
    m = MetricsEngine()
    assert m.calculate_lux(200) == 100


# ----------------------------------------------------------
# TC_M5 - Test blue ratio
# ----------------------------------------------------------
def test_blue_ratio():
    """
    ratio = b / (r+g+b)
    """
    m = MetricsEngine()
    assert m.calculate_blue_ratio(30, 30, 40) == 0.4


# ----------------------------------------------------------
# TC_M6 - Test latest IBI retrieval
# ----------------------------------------------------------
def test_latest_ibi():
    """
    ibi_values = [1.5, 2, 3] → latest = 3
    """
    m = MetricsEngine()
    m.ibi_values = [1.5, 2, 3]

    assert m.get_latest_ibi() == 3


# ----------------------------------------------------------
# TC_M7 - Test IBI variance
# ----------------------------------------------------------
def test_ibi_variance():
    """
    ibi_values = [2,4,6]
    mean = 4
    variance = 2.66...
    """
    m = MetricsEngine()
    m.ibi_values = [2, 4, 6]

    assert m.ibi_variance() == pytest.approx(2.66, rel=0.01)
