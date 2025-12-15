# System Architecture

## Main Components
- Flutter Mobile Application
- FastAPI Backend
- MongoDB Database
- Firebase Cloud Messaging (FCM)

## Data Flow
1. Backend creates a notification.
2. Notification is stored in MongoDB.
3. Backend sends an FCM push notification.
4. Mobile app receives the notification.
5. Mobile app fetches notifications using REST API.

## Key Files

### Flutter
- lib/main.dart
- lib/notifications_page.dart

### Backend
- notification_controller.py
- firebase/firebase_client.py
