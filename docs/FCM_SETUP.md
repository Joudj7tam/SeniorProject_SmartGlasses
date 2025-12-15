# Firebase Cloud Messaging Setup

## Mobile App
- Run the Flutter application.
- Check the debug console for:
  FCM TOKEN: <device-token>

## Backend
- Place the Firebase service account JSON file at:
  firebase/serviceAccountKey.json

## Notes
- FCM tokens may change over time.
- For production use, tokens should be stored per user in the database
  and updated whenever a new token is generated.