#!/bin/bash
# Run this DIRECTLY ON THE VM to complete TractorMate backend setup.
# Usage: bash /home/ubuntu/tractormate/scripts/setup.sh

set -e
APP_DIR="/home/ubuntu/tractormate"

echo "============================================"
echo " TractorMate Backend Setup"
echo "============================================"

# ── Step 1: Fix apt mirror and install dependencies ───────────────────────
echo ""
echo "[1/6] Fixing apt mirror and installing python3-pip, python3-venv, sqlite3..."
sudo sed -i 's|http://ap-hyderabad-1-ad-1.clouds.ports.ubuntu.com/ubuntu-ports|http://ports.ubuntu.com/ubuntu-ports|g' /etc/apt/sources.list
sudo apt-get update -qq
sudo apt-get install -y python3-pip python3-venv sqlite3 -qq
echo "      Done."

# ── Step 2: Python virtualenv + pip install ───────────────────────────────
echo ""
echo "[2/6] Setting up Python virtualenv and installing dependencies..."
cd "$APP_DIR"
if [ ! -d venv ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo "      Done."

# ── Step 3: Create .env if it doesn't exist ───────────────────────────────
echo ""
echo "[3/6] Creating .env file..."
if [ ! -f "$APP_DIR/.env" ]; then
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    cat > "$APP_DIR/.env" << EOF
SECRET_KEY=$SECRET
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
REFRESH_TOKEN_EXPIRE_DAYS=30
DATABASE_URL=sqlite:///./tractormate.db
BACKUP_DIR=/var/backups/tractormate
UPLOAD_DIR=./uploads
EOF
    echo "      .env created with fresh secret key."
else
    echo "      .env already exists, skipping."
fi
mkdir -p "$APP_DIR/uploads"

# ── Step 4: systemd service ───────────────────────────────────────────────
echo ""
echo "[4/6] Installing systemd service..."
sudo cp "$APP_DIR/scripts/tractormate.service" /etc/systemd/system/tractormate.service
sudo systemctl daemon-reload
sudo systemctl enable tractormate
sudo systemctl restart tractormate
sleep 2
sudo systemctl status tractormate --no-pager | head -10
echo "      Done."

# ── Step 5: Patch nginx ───────────────────────────────────────────────────
echo ""
echo "[5/6] Patching nginx config..."
NGINX_SITE="/etc/nginx/sites-available/ashwini-electronics"

if sudo grep -q "tractormate-api" "$NGINX_SITE"; then
    echo "      /tractormate-api/ location block already exists, skipping."
else
    sudo cp "$NGINX_SITE" "${NGINX_SITE}.bak_$(date +%Y%m%d_%H%M%S)"
    sudo awk '
    /# Error pages/ {
        print "    # TractorMate API"
        print "    location /tractormate-api/ {"
        print "        proxy_pass         http://127.0.0.1:8001/;"
        print "        proxy_http_version 1.1;"
        print "        proxy_set_header   Host              $host;"
        print "        proxy_set_header   X-Real-IP         $remote_addr;"
        print "        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;"
        print "        proxy_read_timeout 60s;"
        print "        client_max_body_size 10M;"
        print "    }"
        print ""
    }
    { print }
    ' "$NGINX_SITE" > /tmp/nginx_patched.conf
    sudo cp /tmp/nginx_patched.conf "$NGINX_SITE"
    echo "      Location block inserted."
fi
sudo nginx -t && sudo systemctl reload nginx
echo "      nginx reloaded OK."

# ── Step 6: Backup cron ───────────────────────────────────────────────────
echo ""
echo "[6/6] Setting up daily backup cron..."
chmod +x "$APP_DIR/scripts/backup.sh"
sudo mkdir -p /var/backups/tractormate
CRON_LINE="0 2 * * * $APP_DIR/scripts/backup.sh >> /var/log/tractormate_backup.log 2>&1"
( crontab -l 2>/dev/null | grep -qF "tractormate/scripts/backup.sh" ) && \
    echo "      Cron already set, skipping." || \
    ( (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab - && echo "      Cron scheduled at 2:00 AM daily." )

# ── Final health check ────────────────────────────────────────────────────
echo ""
echo "=== Health checks ==="
echo -n "Direct (port 8001): "
curl -s http://127.0.0.1:8001/health

echo ""
echo -n "Via nginx:          "
curl -s http://127.0.0.1/tractormate-api/health

echo ""
echo "============================================"
echo " Setup complete!"
echo " Public URL : http://144.24.131.165/tractormate-api"
echo " API docs   : http://144.24.131.165/tractormate-api/docs"
echo " Login      : admin / TractorMate@2024"
echo " IMPORTANT  : Change admin password after first login!"
echo "============================================"
