# E-CommerceApp

A full-featured e-commerce application with a multi-platform Flutter client and a Dart-based RESTful backend API using SQLite.

## Contents

- **ecommerce_app/**: Flutter client application (Android, iOS, Web, Windows, MacOS, Linux).
- **ecommerce_backend/**: Dart RESTful API backend (with SQLite database).

---

## Getting Started

### 1. Backend (API) Setup

```sh
cd kocpc/ecommerce_backend
dart pub get
dart run bin/server.dart
```

- The server runs on `localhost:3000` by default.
- Database file: `database.db`
- Uploaded product images: `uploads/products/`

### 2. Flutter App Setup

```sh
cd kocpc/ecommerce_app
flutter pub get
flutter run
```

- Requires Flutter SDK and platform tools.
- The app communicates with the backend API. Update the API URL in `lib/services/api_service.dart` if needed.

---

## Features

### Flutter App
- User registration and login
- Product listing and details
- Cart and favorites
- Order management
- Admin dashboard (add/edit products)
- Multi-platform support

### Backend API
- JWT authentication
- Product, category, cart, favorite, and order management
- SQLite database
- File upload (product images)
- Layered architecture (controller, service, middleware, route)

