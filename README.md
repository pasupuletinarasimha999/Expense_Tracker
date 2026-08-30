# Expense Tracker — Flutter Application

A modern, offline-first Flutter application for tracking monthly income and expenses, visualizing financial patterns through custom-drawn charts, automating recurring bills, planning trip budgets, and exporting reports to Gmail as CSV/PDF attachments. This is a full rewrite of an original native Android/Kotlin app, ported for feature parity — see [`MIGRATION.md`](MIGRATION.md) for what that means in practice and what's left to configure.

---

## 🌟 Key Features

- **Dashboard**: monthly balance summary, quick-add income/expense, swipe-to-mark-paid, month strip navigator.
- **Transactions**: full CRUD, search, filter chips (All/Expense/Income/Recurring), custom categories.
- **Recurring transactions**: toggle "Recurring Monthly" on any transaction — 25 months of rows are generated upfront, with per-month scoped edit/delete (this month / this & future / all months).
- **Analytics**: animated donut chart (category & payment-method breakdown), grouped bar chart (6-month income/expense trend), fiscal year overview (Apr–Mar).
- **Trips**: budget goals, savings progress (via transactions tagged to a trip), budget line items with paid/reminder tracking.
- **Settings**: currency switcher (7 currencies), dark mode, App Lock (biometric/PIN), Google Drive backup & sync, CSV/PDF/Gmail export.
- **Google Sign-In + Drive backup**: private per-account backup of transactions/categories to Drive's `appDataFolder`.
- **Local notifications**: trip expense reminders fire at 9 AM on the target date.

---

## 🏛️ Architecture & Tech Stack

- **State management**: Riverpod (`flutter_riverpod`)
- **Routing**: `go_router` with a `StatefulShellRoute` for the 5 bottom-nav tabs
- **Local database**: `drift` (SQLite) — see `lib/data/local/`
- **Auth & sync**: `google_sign_in` + hand-rolled Drive v3 REST calls (`lib/data/remote/drive_sync_manager.dart`)
- **Biometric lock**: `local_auth`
- **Notifications**: `flutter_local_notifications` + `timezone`
- **PDF/CSV export**: `pdf` package + hand-rolled CSV writer, shared via `share_plus`

## 📁 Project Structure

```
lib/
  main.dart, app.dart, app_providers.dart   # entrypoint, routing, DI
  core/                                     # theme, constants, formatting utils
  data/
    local/                                  # drift tables, DAOs, database
    remote/                                 # Drive sync REST client
    repositories/                           # business logic (recurring series, summaries, etc.)
    preferences/                            # SharedPreferences wrapper
  features/
    dashboard/ transactions/ analytics/ trips/ settings/ auth/ app_lock/
  services/                                 # notifications, report export
  widgets/                                  # shared UI (month selector, transaction tile, main shell)
```

## 🚀 Running the app

```
flutter pub get
flutter run
```

Requires the Flutter SDK, an Android SDK (API 24+), and a connected device or emulator. See [`MIGRATION.md`](MIGRATION.md) for the Google Sign-In/Drive OAuth setup needed before those specific features will authenticate.
