# TractorMate — ಟ್ರ್ಯಾಕ್ಟರ್‌ಮೇಟ್

Tractor Rent & Expense Tracker — Android app with offline-first architecture and Oracle Cloud backup.

## Features

- **Customer Management** — Add customers, track rental history, view balances
- **Rental Recording** — Record work type, rent amount, payments; auto-calculates payment status
- **Expense Tracking** — Diesel, repairs, maintenance, spare parts with optional receipt photos
- **Analytics** — Daily/weekly/monthly/yearly earnings, expense breakdown charts
- **PDF Reports** — Generate and share via WhatsApp/Email
- **Offline-First** — Works without internet; auto-syncs to Oracle Cloud when online
- **Bilingual** — Kannada + English throughout
- **Multi-User** — 2-5 users with shared central database

## Project Structure

```
TractorMate/
├── app/          # Flutter Android app
└── backend/      # FastAPI server (deploys to Oracle Cloud ARM VM)
```

## Backend Setup (Oracle Cloud VM)

### Quick deploy (run on the VM)
```bash
bash /home/ubuntu/tractormate/scripts/setup.sh
```

### What it does
- Installs Python dependencies in a virtualenv
- Starts FastAPI server on port 8001 via systemd
- Patches nginx to serve `/tractormate-api/` (without disturbing existing sites)
- Sets up daily SQLite backup at 2 AM

### API
- Public URL: `http://YOUR_SERVER_IP/tractormate-api`
- API docs: `http://YOUR_SERVER_IP/tractormate-api/docs`
- Default login: `admin` / `YOUR_SECURE_PASSWORD` (**configured in backend/.env**)

## Flutter App Build

### Prerequisites
```bash
# Flutter SDK at /home/mahi/flutter
export PATH="$PATH:/home/mahi/flutter/bin"

# Android SDK with cmdline-tools at /home/mahi/android-sdk
export ANDROID_SDK_ROOT=/home/mahi/android-sdk
export JAVA_HOME=/home/mahi/jdk-17.0.2  # or your JDK 17 path
```

### Install dependencies
```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

### Build APK
```bash
flutter build apk --release
# Output: app/build/app/outputs/flutter-apk/app-release.apk
```

### Install on device
```bash
flutter install
```

## Architecture

```
Android Phone                    Oracle Cloud ARM VM
─────────────                    ───────────────────
Flutter UI          ←──────────→  FastAPI (port 8001)
  ↕ Drift SQLite                    ↕ SQLite DB
WorkManager sync    ──── HTTPS ───→  nginx proxy
```

### Offline Sync
- Every write sets `is_synced = false` locally
- WorkManager runs every 15 min when internet available
- Push local changes → Pull server changes (last-write-wins)
- Sync status shown in app bar (cloud icon)

## Default Credentials

| Field     | Value               |
|-----------|---------------------|
| Username  | admin               |
| Password  | Set during deployment |

**Important:** The admin password is automatically generated during backend deployment. Check your backend logs or `.env` file for the actual password.

To create more users, use the web admin panel (Settings > User Management) or the API:
```bash
curl -X POST http://YOUR_SERVER_IP/tractormate-api/auth/users \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"username": "user2", "password": "SecurePass123", "role": "user"}'
```

## Maintenance

### Check backend status
```bash
ssh user@YOUR_SERVER_IP "sudo systemctl status tractormate"
```

### View logs
```bash
ssh user@YOUR_SERVER_IP "sudo journalctl -u tractormate -n 50"
```

### Manual backup
```bash
ssh user@YOUR_SERVER_IP "bash /home/ubuntu/tractormate/scripts/backup.sh"
```

### Re-deploy backend after changes
See `DEPLOYMENT.md` for detailed deployment instructions.
