# notification_manager.py
from datetime import datetime, timedelta
from typing import Dict, Optional


class NotificationManager:
    """
    Controls notification spam using:
    1) persistence rule: same metric must appear for N consecutive readings
    2) cooldown rule: same metric cannot be sent again before cooldown expires
    """

    def __init__(self, persistence_required: int = 2, cooldown_minutes: int = 15):
        self.persistence_required = persistence_required
        self.cooldown = timedelta(minutes=cooldown_minutes)

        self.streaks = {
            "blink_low": 0,
            "blue_high": 0,
            "focus_too_long": 0,
        }

        self.last_sent_at: Dict[str, datetime] = {}

    def update_streaks(self, flags: Dict[str, int]) -> None:
        for metric in self.streaks:
            if int(flags.get(metric, 0)) == 1:
                self.streaks[metric] += 1
            else:
                self.streaks[metric] = 0

    def can_send(self, metric_name: str, now: datetime) -> bool:
        if self.streaks.get(metric_name, 0) < self.persistence_required:
            return False

        last_sent = self.last_sent_at.get(metric_name)
        if last_sent is None:
            return True

        return now - last_sent >= self.cooldown

    def mark_sent(self, metric_name: str, now: datetime) -> None:
        self.last_sent_at[metric_name] = now

    def get_message(self, metric_name: str, sensor: Dict, indices: Dict) -> tuple[str, float]:
        """
        Returns:
            message, critical_value
        """

        if metric_name == "blink_low":
            score = indices["DEI"]["score"]
            value = float(sensor["blink_rate_bpm"])
            return (
                f"Low blink rate detected for multiple readings. Dry Eye Index is {score}/100. Try blinking exercises and take a short break.",
                value,
            )

        if metric_name == "blue_high":
            score = indices["BLI"]["score"]
            value = float(sensor["blue_lux"])
            return (
                f"High blue-light exposure persisted. Blue Light Index is {score}/100. Reduce brightness or enable night mode.",
                value,
            )

        if metric_name == "focus_too_long":
            score = indices["EFI"]["score"]
            value = float(sensor["focus_minutes"])
            return (
                f"Continuous focus time is high. Eye Focus Index is {score}/100. Take a 20-20-20 break.",
                value,
            )

        return ("Eye health risk detected.", 0.0)

    async def process_notifications(
        self,
        *,
        device_id: str,
        flags: Dict[str, int],
        sensor: Dict,
        indices: Dict,
        create_notification_func,
        now: Optional[datetime] = None,
    ) -> list[dict]:
        """
        Calls your existing backend create_notification(...) only when rules pass.
        """

        now = now or datetime.utcnow()
        self.update_streaks(flags)

        sent = []

        for metric_name in ["blink_low", "blue_high", "focus_too_long"]:
            if not self.can_send(metric_name, now):
                continue

            message, critical_value = self.get_message(metric_name, sensor, indices)

            payload = {
                "deviceId": device_id,
                "type": "eye_health_alert",
                "title": "ClipView Eye Health Alert",
                "message": message,
                "metric_name": metric_name,
                "critical_value": critical_value,
                "isRead": False,
                "created_at": now,
            }

            try:
                result = await create_notification_func(payload)
                self.mark_sent(metric_name, now)
                sent.append({
                    "metric_name": metric_name,
                    "critical_value": critical_value,
                    "message": message,
                    "backend_result": result,
                })

            except Exception as e:
                print(f"[Notification] Failed for {metric_name}: {e}")

        return sent