# Project Commands Documentation

This file provides instructions for setting up and running each component of the SBMS project.

## Prerequisites
- **Python 3.x** (for Backend API)
- **Node.js & npm** (for Web Frontend)
- **Flutter SDK** (for Mobile App)
- **PostgreSQL 17** (for Database)
- **Arduino IDE** (for IoT/ESP32 Scripts)

---

## 1. Backend API (Django)
**Location:** `api/`

### Setup
1. Create a virtual environment:
   ```powershell
   python -m venv venv
   .\venv\Scripts\activate
   ```
2. Install dependencies:
   ```powershell
   pip install -r requirements.txt
   ```

### Commands
- **Run Server:** `python manage.py runserver`
- **Apply Migrations:** `python manage.py migrate`
- **Create Superuser:** `python manage.py createsuperuser`

---

## 2. Web Frontend (React + Vite)
**Location:** `web/`

### Setup
1. Install dependencies:
   ```powershell
   npm install
   ```

### Commands
- **Run Dev Server:** `npm run dev`
- **Build for Production:** `npm run build`

---

## 3. Mobile App (Flutter)
**Location:** `mobile/`

### Setup
1. Fetch dependencies:
   ```powershell
   flutter pub get
   ```

### Commands
- **Run App:** `flutter run`
- **Build App:** `flutter build apk` (for Android)

---

## 4. IoT Scripts (ESP32)
**Location:** `iot_scripts/`

### Setup
1. Open the `.ino` files in **Arduino IDE**.
2. Install necessary libraries (e.g., `DHT sensor library`, `Adafruit Unified Sensor`).
3. Select your ESP32 board and port.
4. Flash the code to the device.

---

## 5. Database (PostgreSQL)
**Database Name:** `sbmsdb`

### Backup
To create a backup:
```powershell
$env:PGPASSWORD='9609'; & "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe" -U postgres -d sbmsdb -f backup.sql
```

### Restore
To restore from `backup.sql`:
1. Create the database first if it doesn't exist:
   ```powershell
   & "C:\Program Files\PostgreSQL\17\bin\createdb.exe" -U postgres sbmsdb
   ```
2. Restore the backup:
   ```powershell
   $env:PGPASSWORD='9609'; & "C:\Program Files\PostgreSQL\17\bin\psql.exe" -U postgres -d sbmsdb -f backup.sql
   ```
