"""
firebase_client.py

Purpose:
    Firebase Cloud Messaging (FCM) client used by the backend to send push notifications.

Maintainability notes:
    - Keep message payload schema consistent with the mobile app.
"""
import firebase_admin
from firebase_admin import credentials, messaging

cred = credentials.Certificate("firebase/serviceAccountKey.json")
firebase_admin.initialize_app(cred)
USER_FCM_TOKEN = "eVeOV6zFSj6pi9S8ldoFpg:APA91bFbvRqeEQzGF6ugTO1xvy4Jd5Ywvca_BZ8Q_rVpfIqTCIApbQhXtZLep9eoH1ETCUqOvIawsXDVthNyqU-FyKjFilHiWSxFozCnALqiYOTvXaCfPrw"

"""
    Send a push notification via Firebase Cloud Messaging.

    Args:
        token: Target device FCM token.
        title: Notification title.
        body: Notification body text.
        data: Optional key/value payload (strings recommended for cross-platform consistency).

    Returns:
        Firebase message ID as a string.
    """
def send_push_notification(token: str, title: str, body: str, data: dict = {}):
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        token=token,
        data=data
    )
    response = messaging.send(message)
    print("✅ FCM sent:", response)
    return response