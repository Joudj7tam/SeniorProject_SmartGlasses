# notification_manager.py

from datetime import datetime, timedelta
from typing import Dict, Optional


class NotificationManager:
    """
    Controls notification spam.

    This file does NOT save notifications directly.
    It only decides WHEN a notification should be sent.

    notification_manager.py:
        - persistence rule
        - cooldown rule
        - builds message text

    notification_controller.py:
        - saves notification to MongoDB
        - sends FCM push if token is valid
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
        Build final notification message.

        These messages now mention the smart-light response,
        so the app explains both:
        - what risk was detected
        - what lighting action ClipView applied
        """

        if metric_name == "blink_low":
            score = indices["DEI"]["score"]
            value = float(sensor["blink_rate_bpm"])

            return (
                f"Low blink rate persisted. Dry Eye Index is {score}/100. "
                f"ClipView adjusted the room light to warm amber recovery mode to support eye comfort.",
                value,
            )

        if metric_name == "blue_high":
            score = indices["BLI"]["score"]
            value = float(sensor["blue_lux"])

            return (
                f"High blue-light exposure persisted. Blue Light Index is {score}/100. "
                f"ClipView adjusted the room light to a warmer low-blue scene.",
                value,
            )

        if metric_name == "focus_too_long":
            score = indices["EFI"]["score"]
            value = float(sensor["focus_minutes"])

            return (
                f"Continuous focus time is high. Eye Focus Index is {score}/100. "
                f"ClipView switched to a soft recovery light and recommends a short 20-20-20 break.",
                value,
            )

        return ("Eye health risk detected. ClipView adjusted the room light for comfort.", 0.0)

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