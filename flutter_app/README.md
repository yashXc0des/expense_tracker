# Expense Tracker — Flutter App

This is a minimal Flutter scaffold for the Camera-First Expense Tracker. It includes:

- Dark and Light themes with a toggle saved in `SharedPreferences`.
- Home screen with navigation tiles to Camera, Expenses, and Journeys.
- Placeholder screens for Camera, Expenses, and Journeys to be implemented.

Getting started

1. Install Flutter SDK: https://flutter.dev/docs/get-started/install
2. From project root run:

```bash
cd flutter_app
flutter pub get
flutter run
```

Next steps

- Add camera integration (`camera` package) and implement receipt capture preview.
- Integrate OCR upload to backend (`/api/expenses` endpoint) and show extraction results.
- Implement local DB sync (Isar) and background sync to backend.
- Polish UI and animations.

