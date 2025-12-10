# without humidity and temperature values.
# metrics.py
# ============================================
# This file calculates all real-time metrics:
# - Inter Blink Interval (IBI)
# - Blink Rate (blinks/min)
# - Session time
# - Ambient light (lux)
# - Blue light ratio
# ============================================

import time

class MetricsEngine:
    def __init__(self):
        # Store timestamps of last few blinks
        self.last_blink_time = None
        self.ibi_values = []  # for variance calculation

        # Blink counters
        self.blink_count = 0
        self.session_start_time = time.time()

    # ----------------------------------------------------
    # Update blink metrics when blink.rawValue == 1
    # ----------------------------------------------------
    def update_blink(self, blink_detected: bool):
        current_time = time.time()

        if blink_detected:
            self.blink_count += 1

            if self.last_blink_time is not None:
                ibi = current_time - self.last_blink_time
                self.ibi_values.append(ibi)

                # Limit to recent 20 values only
                if len(self.ibi_values) > 20:
                    self.ibi_values.pop(0)

            self.last_blink_time = current_time

    # ----------------------------------------------------
    # Calculate blink rate (blinks per minute)
    # ----------------------------------------------------
    def calculate_blink_rate(self):
        minutes = (time.time() - self.session_start_time) / 60
        if minutes == 0:
            return 0
        return self.blink_count / minutes

    # ----------------------------------------------------
    # Calculate IBI metrics
    # ----------------------------------------------------
    def get_latest_ibi(self):
        if not self.ibi_values:
            return None
        return self.ibi_values[-1]

    def ibi_variance(self):
        if len(self.ibi_values) < 3:
            return 0
        mean = sum(self.ibi_values) / len(self.ibi_values)
        var = sum((x - mean) ** 2 for x in self.ibi_values) / len(self.ibi_values)
        return var

    # ----------------------------------------------------
    # Session time (used for long-exposure warnings)
    # ----------------------------------------------------
    def get_session_time_minutes(self):
        return (time.time() - self.session_start_time) / 60

    # ----------------------------------------------------
    # Ambient light estimation (lux)
    # ----------------------------------------------------
    def calculate_lux(self, clear_value):
        # Simple approximation, not scientific — allowed
        return clear_value * 0.5

    # ----------------------------------------------------
    # Blue Light Ratio
    # ----------------------------------------------------
    def calculate_blue_ratio(self, r, g, b):
        total = r + g + b
        if total == 0:
            return 0
        return b / total
