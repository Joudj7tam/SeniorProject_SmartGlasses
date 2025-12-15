# Smart Glasses – Senior Project

A Smart Glasses system that monitors eye-health related metrics (such as screen distance, brightness, and eye dryness) and delivers real-time alerts to the mobile application using Firebase Cloud Messaging (FCM).

The mobile app also displays a history of notifications retrieved from the backend server.

---

## Overview

This project consists of two main parts:

- A Flutter mobile application responsible for the user interface and receiving push notifications.
- A FastAPI backend responsible for storing notifications, sending push messages via Firebase, and exposing REST APIs.

Main features:
- Receive push notifications in all app states (foreground, background, terminated)
- Store notifications in a database
- View, read, and delete notifications from the mobile app

---

## High-Level Architecture (Data Flow)

1. The backend creates a notification.
2. The notification is stored in MongoDB.
3. The backend sends a push notification using Firebase Cloud Messaging (FCM).
4. The mobile app receives the push notification.
5. The mobile app fetches the full notification list from the backend API.

---

## Repository Structure (Important Files)

### Flutter (Mobile App)
- lib/main.dart – App entry point and Firebase initialization
- lib/notifications_page.dart – Notifications UI and REST API calls
- lib/smart_bottom_nav.dart – Bottom navigation component

### Backend
- notification_controller.py – Notification CRUD logic and FCM sending
- Models/notification_model.py – Notification data schema
- firebase/firebase_client.py – Firebase Admin SDK client

---

## Requirements

### Flutter
- Flutter SDK
- Android Studio
- Android Emulator or physical device

### Backend
- Python 3.10 or higher
- MongoDB
- Firebase service account JSON file

---

## Setup and Run

### Flutter Mobile App

Install dependencies:
flutter pub get

Run the app:
flutter run

If using an Android emulator, the backend URL must be:
http://10.0.2.2:8080

---

### Backend (FastAPI)

Install dependencies:
pip install -r requirements.txt

Run the backend server:
uvicorn main:app --host 0.0.0.0 --port 8080 --reload

---

## Notifications API

Base URL:
http://localhost:8080

Endpoints:
- GET /api/notifications/
- PATCH /api/notifications/{id}/read
- DELETE /api/notifications/{id}

---

## Maintainability

Core modules related to notification handling are documented and structured so that a new developer can understand and modify the system within a short time.

Additional technical documentation is provided in the docs folder.

---

## Documentation

- docs/ARCHITECTURE.md
- docs/FCM_SETUP.md
- docs/NOTIFICATIONS_API.md

---

## License

Academic use – Senior Project.
