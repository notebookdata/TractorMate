# Deployment Guide

This guide helps you deploy TractorMate to your own server.

## Prerequisites

- A Linux server (tested on Ubuntu 22.04 ARM)
- Python 3.10+
- Flutter SDK 3.32+ (for mobile app)
- Nginx (for web hosting and API proxy)
- SSH access to your server

## 1. Backend Deployment

### Step 1: Prepare Your Server

```bash
# SSH into your server
ssh your-user@YOUR_SERVER_IP

# Create directory
sudo mkdir -p /home/ubuntu/tractormate
cd /home/ubuntu/tractormate
```

### Step 2: Copy Backend Files

From your local machine:

```bash
# Copy backend files to server
scp -r backend/ your-user@YOUR_SERVER_IP:/home/ubuntu/tractormate/
```

### Step 3: Install Dependencies

On the server:

```bash
cd /home/ubuntu/tractormate
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Step 4: Configure Environment

Create `.env` file:

```bash
cat > .env << EOF
SECRET_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))")
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
REFRESH_TOKEN_EXPIRE_DAYS=30
DATABASE_URL=sqlite:///./tractormate.db
BACKUP_DIR=/var/backups/tractormate
UPLOAD_DIR=./uploads
EOF
```

### Step 5: Set Up Systemd Service

```bash
# Copy service file
sudo cp scripts/tractormate.service /etc/systemd/system/

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable tractormate
sudo systemctl start tractormate

# Check status
sudo systemctl status tractormate
```

### Step 6: Configure Nginx

Add to your nginx site config:

```nginx
# TractorMate API - proxied to uvicorn on port 8001
location /tractormate-api/ {
    proxy_pass         http://127.0.0.1:8001/;
    proxy_http_version 1.1;
    proxy_set_header   Host              $host;
    proxy_set_header   X-Real-IP         $remote_addr;
    proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header   X-Forwarded-Proto $scheme;
    proxy_read_timeout 60s;
    client_max_body_size 10M;
}
```

Reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

### Step 7: Set Up Backups

```bash
# Create backup directory
sudo mkdir -p /var/backups/tractormate

# Add cron job for daily backups at 2 AM
crontab -e
# Add this line:
0 2 * * * /home/ubuntu/tractormate/scripts/backup.sh >> /var/log/tractormate_backup.log 2>&1
```

## 2. Mobile App Configuration

### Step 1: Update Server URL

Edit `app/lib/services/api_service.dart`:

```dart
const _defaultBaseUrl = 'http://YOUR_SERVER_IP/tractormate-api';
```

### Step 2: Build APK

```bash
cd app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter build apk --release
```

The APK will be at: `app/build/app/outputs/flutter-apk/app-release.apk`

### Step 3: Distribute to Users

Transfer the APK to your devices and install.

## 3. Web App Deployment

### Step 1: Build Web App

```bash
cd app
flutter build web --release --base-href /tractormate/
```

### Step 2: Deploy to Server

```bash
# From local machine
scp -r app/build/web/ your-user@YOUR_SERVER_IP:/home/ubuntu/tractormate-web/
```

### Step 3: Configure Nginx for Web App

Add to nginx config:

```nginx
location /tractormate/ {
    alias /home/ubuntu/tractormate-web/;
    index index.html;
    try_files $uri $uri/ /tractormate/index.html;
}
```

Reload nginx:

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 4. Initial Setup

### Access Web App

1. Navigate to `http://YOUR_SERVER_IP/tractormate/`
2. Login with default credentials:
   - Username: `admin`
   - Password: `TractorMate@2024` (or check your deployment logs)

### Change Admin Password

1. Go to Settings
2. Create a new admin user with a secure password
3. Logout and login with the new credentials
4. Delete the default admin account

### Create Users

1. Go to Settings > User Management (admin only)
2. Click "Add User"
3. Enter username, password, and assign role (admin or user)

## 5. Maintenance

### View Logs

```bash
sudo journalctl -u tractormate -n 50 -f
```

### Restart Service

```bash
sudo systemctl restart tractormate
```

### Manual Backup

```bash
bash /home/ubuntu/tractormate/scripts/backup.sh
```

### Update Backend

```bash
# Copy new files
scp -r backend/ your-user@YOUR_SERVER_IP:/home/ubuntu/tractormate/

# Restart service
ssh your-user@YOUR_SERVER_IP "sudo systemctl restart tractormate"
```

## Security Checklist

- [ ] Change default admin password
- [ ] Use strong passwords for all users
- [ ] Set up HTTPS/SSL with Let's Encrypt
- [ ] Regularly update system packages
- [ ] Monitor backup logs
- [ ] Restrict SSH access (use SSH keys, disable password auth)
- [ ] Configure firewall (allow only 80, 443, and SSH)

## Troubleshooting

### API not responding

```bash
# Check if service is running
sudo systemctl status tractormate

# Check logs
sudo journalctl -u tractormate -n 100

# Test locally
curl http://127.0.0.1:8001/health
```

### Mobile app can't connect

1. Check if server IP is correct in `api_service.dart`
2. Verify firewall allows port 80/443
3. Test API from browser: `http://YOUR_SERVER_IP/tractormate-api/health`

### Database issues

```bash
# Check database file
ls -lh /home/ubuntu/tractormate/tractormate.db

# View recent backups
ls -lh /var/backups/tractormate/
```

## Support

For issues or questions:
1. Check logs first
2. Review this deployment guide
3. Check GitHub Issues (if available)
