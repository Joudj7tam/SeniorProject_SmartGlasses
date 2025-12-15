# Notifications API

Base URL:
http://localhost:8080

## Endpoints

### GET /api/notifications/
Returns all notifications stored in the database.

### PATCH /api/notifications/{id}/read
Marks a notification as read.

Request body:
{ "isRead": true }

### DELETE /api/notifications/{id}
Deletes a notification by its ID.

## Notification Fields
- id
- title
- message
- metric_name
- critical_value
- isRead
- created_at
