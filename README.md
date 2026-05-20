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

## Architecture Overview

### System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TractorMate System                          │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────┐                           ┌──────────────────────┐
│  Mobile Devices  │                           │   Cloud Server       │
│  (Android/iOS)   │                           │   (Oracle Cloud)     │
├──────────────────┤                           ├──────────────────────┤
│                  │                           │                      │
│  ┌────────────┐  │                           │  ┌────────────────┐  │
│  │  Flutter   │  │    ← HTTPS REST API →    │  │  FastAPI       │  │
│  │    App     │  │                           │  │  Backend       │  │
│  │            │  │   JWT Authentication      │  │  (Python)      │  │
│  └─────┬──────┘  │                           │  └────────┬───────┘  │
│        │         │                           │           │          │
│  ┌─────▼──────┐  │                           │  ┌────────▼───────┐  │
│  │   Drift    │  │   Background Sync         │  │   SQLAlchemy   │  │
│  │  Database  │  │   (WorkManager)           │  │      ORM       │  │
│  │  (SQLite)  │  │                           │  │                │  │
│  └────────────┘  │                           │  └────────┬───────┘  │
│                  │                           │           │          │
└──────────────────┘                           │  ┌────────▼───────┐  │
                                               │  │    SQLite      │  │
┌──────────────────┐                           │  │   Database     │  │
│   Web Browser    │                           │  └────────────────┘  │
│  (Admin Panel)   │                           │                      │
├──────────────────┤                           │  ┌────────────────┐  │
│                  │    ← HTTPS REST API →    │  │     Nginx      │  │
│  ┌────────────┐  │                           │  │  Reverse Proxy │  │
│  │  Flutter   │  │                           │  │  + Static Host │  │
│  │    Web     │  │                           │  └────────────────┘  │
│  │            │  │                           │                      │
│  └─────┬──────┘  │                           │  ┌────────────────┐  │
│        │         │                           │  │   Systemd      │  │
│  ┌─────▼──────┐  │                           │  │   Service      │  │
│  │  IndexedDB │  │                           │  │   Manager      │  │
│  │ (sql.js)   │  │                           │  └────────────────┘  │
│  └────────────┘  │                           │                      │
│                  │                           │  ┌────────────────┐  │
└──────────────────┘                           │  │  Daily Backup  │  │
                                               │  │   (Cron Job)   │  │
                                               │  └────────────────┘  │
                                               │                      │
                                               └──────────────────────┘
```

### Component Stack

#### Frontend (Flutter)
```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│  ┌─────────────────────────────────┐   │
│  │ Screens & Widgets               │   │
│  │ • Dashboard                     │   │
│  │ • Customers                     │   │
│  │ • Drivers (Admin only)          │   │
│  │ • Rentals                       │   │
│  │ • Expenses                      │   │
│  │ • Analytics & Reports           │   │
│  │ • Settings & User Management    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ State Management (Riverpod)     │   │
│  │ • Auth Provider                 │   │
│  │ • Sync Status Provider          │   │
│  │ • Stream Providers (real-time)  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Services Layer                  │   │
│  │ • API Service (Dio + JWT)       │   │
│  │ • Auth Service                  │   │
│  │ • Sync Service                  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Data Layer (Drift ORM)          │   │
│  │ • Database Schema & Migrations  │   │
│  │ • DAOs (Data Access Objects)    │   │
│  │ • Type-safe queries             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Storage                         │   │
│  │ • SQLite (Mobile)               │   │
│  │ • IndexedDB (Web via sql.js)    │   │
│  │ • FlutterSecureStorage (Mobile) │   │
│  │ • SharedPreferences (Web)       │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

#### Backend (FastAPI)
```
┌─────────────────────────────────────────┐
│         API Layer                       │
│  ┌─────────────────────────────────┐   │
│  │ REST Endpoints                  │   │
│  │ • /auth (login, users)          │   │
│  │ • /customers                    │   │
│  │ • /drivers (admin only)         │   │
│  │ • /rentals                      │   │
│  │ • /expenses                     │   │
│  │ • /sync (push/pull)             │   │
│  │ • /reports                      │   │
│  │ • /admin (reset data)           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Middleware                      │   │
│  │ • CORS Handler                  │   │
│  │ • JWT Authentication            │   │
│  │ • Request Logging               │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Business Logic                  │   │
│  │ • Role-based Access Control     │   │
│  │ • Sync Conflict Resolution      │   │
│  │ • Data Validation               │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Data Layer (SQLAlchemy ORM)     │   │
│  │ • Models & Relationships        │   │
│  │ • Query Optimization            │   │
│  │ • Transaction Management        │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ Storage                         │   │
│  │ • SQLite Database               │   │
│  │ • File Storage (receipts)       │   │
│  │ • Automated Backups             │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Data Flow Diagram

#### User Creates a Rental
```
┌─────────┐      ┌─────────┐      ┌──────────┐      ┌────────┐
│  User   │      │  Flutter│      │  Local   │      │ Server │
│ Action  │      │   App   │      │ Database │      │   API  │
└────┬────┘      └────┬────┘      └────┬─────┘      └───┬────┘
     │                │                 │                │
     │ 1. Fill Form   │                 │                │
     ├───────────────>│                 │                │
     │                │                 │                │
     │                │ 2. Save Rental  │                │
     │                ├────────────────>│                │
     │                │   (is_synced=F) │                │
     │                │                 │                │
     │                │ 3. Return ID    │                │
     │                │<────────────────┤                │
     │                │                 │                │
     │ 4. Show Success│                 │                │
     │<───────────────┤                 │                │
     │                │                 │                │
     │                │ 5. Background Sync (15 min later)│
     │                │                 │                │
     │                │ 6. Fetch Unsynced Records        │
     │                │<────────────────┤                │
     │                │                 │                │
     │                │ 7. POST /sync/push               │
     │                ├─────────────────┼───────────────>│
     │                │   (rental data) │                │
     │                │                 │ 8. Save to DB  │
     │                │                 │<───────────────┤
     │                │                 │                │
     │                │ 9. Success Response              │
     │                │<────────────────┼────────────────┤
     │                │                 │                │
     │                │ 10. Mark as Synced               │
     │                ├────────────────>│                │
     │                │   (is_synced=T) │                │
     │                │                 │                │
     │ 11. Update     │                 │                │
     │  Sync Badge    │                 │                │
     │<───────────────┤                 │                │
     │                │                 │                │
```

### Offline-First Sync Mechanism

```
┌──────────────────────────────────────────────────────────────┐
│                    Sync Architecture                         │
└──────────────────────────────────────────────────────────────┘

MOBILE DEVICE                              SERVER
─────────────                              ──────

┌─────────────────┐                   ┌──────────────────┐
│  User Actions   │                   │   Server Time    │
│  (CRUD ops)     │                   │   (UTC)          │
└────────┬────────┘                   └────────┬─────────┘
         │                                     │
         │ Mark: is_synced = FALSE             │
         │ Store: updated_at timestamp         │
         │                                     │
         ▼                                     │
┌─────────────────┐                            │
│  Local SQLite   │                            │
│  • Customers    │                            │
│  • Rentals      │                            │
│  • Expenses     │                            │
│  • Drivers      │                            │
│  • Attendances  │                            │
└────────┬────────┘                            │
         │                                     │
         │ Every 15 minutes                    │
         │ (WorkManager / Web periodic)        │
         │                                     │
         ▼                                     │
┌─────────────────┐                            │
│  Sync Service   │                            │
│  1. Check WiFi  │                            │
│  2. Push Changes│─────HTTPS POST───────────> │
│     (if any)    │     /sync/push             │
│                 │                             │
│  3. Pull Changes│<────HTTPS GET──────────────│
│     (since last)│     /sync/pull?since=T     │
│                 │                             │
│  4. Resolve     │                   ┌────────▼────────┐
│     Conflicts   │                   │  Server SQLite  │
│     (last-write │                   │  • Central DB   │
│      wins)      │                   │  • All records  │
│                 │                   │  • User auth    │
│  5. Update      │                   └────────┬────────┘
│     local DB    │                            │
│                 │<───────JSON Response───────┤
│  6. Mark synced │     (server_time)          │
│     (is_synced  │                            │
│      = TRUE)    │                            │
└────────┬────────┘                            │
         │                                     │
         │ Update last_sync = server_time     │
         │ (prevents clock skew issues)        │
         │                                     │
         ▼                                     │
┌─────────────────┐                            │
│  UI Updates     │                            │
│  • Sync badge   │                            │
│  • Live streams │                            │
│    (Riverpod)   │                            │
└─────────────────┘                            │
```

### Role-Based Access Control

```
┌──────────────────────────────────────────────────────────┐
│                    User Roles & Permissions              │
└──────────────────────────────────────────────────────────┘

ADMIN ROLE                          USER ROLE
──────────                          ─────────

✓ View Dashboard                    ✓ View Dashboard
  (Full stats)                        (Limited stats - no profit)

✓ Manage Customers                  ✓ Manage Customers
  (Add/Edit/Delete)                   (Add/Edit only)

✓ Manage Drivers                    ✗ No Driver Access
  (Add/Edit/Delete)                   (Tab hidden)
  ✓ Driver Attendance
  ✓ Payment Tracking

✓ Manage Rentals                    ✓ Manage Rentals
  (Add/Edit/Delete)                   (Add/Edit only)

✓ Manage Expenses                   ✓ Manage Expenses
  (Add/Edit/Delete)                   (Add/Edit only)

✓ View Analytics                    ✗ No Analytics Access
  (Charts & Reports)                  (Hidden from Settings)

✓ Generate Reports                  ✗ No Reports Access
  (PDF Export)                        (Hidden from Settings)

✓ User Management                   ✗ No User Management
  (Add/Edit/Delete users)             (Web only, admin only)

✓ Reset Database                    ✗ No Reset Access
  (Danger zone)                       (Web only, admin only)

✓ System Settings                   ✓ Basic Settings
  (Server URL, Sync)                  (Server URL, Sync)
```

### Technology Stack

#### Mobile App
- **Framework:** Flutter 3.32+
- **Language:** Dart 3.8+
- **Database:** Drift (SQLite wrapper)
- **State Management:** Riverpod
- **HTTP Client:** Dio
- **Background Tasks:** WorkManager
- **Storage:** FlutterSecureStorage
- **Charts:** fl_chart
- **PDF:** pdf package
- **Localization:** flutter_localizations (en, kn)

#### Web App
- **Framework:** Flutter Web
- **Database:** sql.js (SQLite in browser via WASM)
- **Storage:** IndexedDB (via Drift), SharedPreferences
- **Build:** flutter build web

#### Backend
- **Framework:** FastAPI
- **Language:** Python 3.10+
- **Database:** SQLite with SQLAlchemy ORM
- **Authentication:** JWT (python-jose)
- **Server:** Uvicorn (ASGI)
- **Process Manager:** Systemd
- **Reverse Proxy:** Nginx
- **Deployment:** Oracle Cloud ARM VM (Ubuntu 22.04)

#### DevOps
- **Version Control:** Git
- **Backup:** Daily cron job + rsync
- **Monitoring:** Systemd + journald logs
- **SSL:** Let's Encrypt (recommended)

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
