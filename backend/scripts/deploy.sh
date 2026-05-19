#!/bin/bash
# Deploy TractorMate backend to Oracle VM.
# Safe: does NOT replace the existing nginx config.
# Adds a /tractormate-api/ location block inside the existing server block.
# Run from your LOCAL machine: bash deploy.sh

set -e

VM_USER="ubuntu"
VM_HOST="144.24.131.165"
SSH_KEY="/home/mahi/workspace/OracleUbuntuARM/Oracle_Ubuntu_Key-20241222T155900Z-001/Oracle_Ubuntu_Key/ssh-key-2024-06-30.key"
REMOTE_DIR="/home/ubuntu/tractormate"
LOCAL_BACKEND="$(cd "$(dirname "$0")/.." && pwd)"
NGINX_SITE="/etc/nginx/sites-available/ashwini-electronics"

SSH="ssh -i $SSH_KEY -o StrictHostKeyChecking=no $VM_USER@$VM_HOST"

echo "==> Checking connection to VM..."
$SSH "echo 'Connected to $(hostname)'"

echo ""
echo "==> Copying backend files to VM..."
rsync -avz --progress \
    --exclude '__pycache__' \
    --exclude '*.pyc' \
    --exclude 'tractormate.db' \
    --exclude 'uploads/' \
    --exclude '.env' \
    -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=no" \
    "$LOCAL_BACKEND/" "$VM_USER@$VM_HOST:$REMOTE_DIR/"

echo ""
echo "==> Installing Python dependencies on VM..."
$SSH bash << 'REMOTE'
set -e
cd /home/ubuntu/tractormate

# Install pip3 and venv if needed
if ! command -v pip3 &>/dev/null; then
    sudo apt-get update -qq
    sudo apt-get install -y python3-pip python3-venv sqlite3 -qq
fi

# Create virtualenv if not exists
if [ ! -d venv ]; then
    python3 -m venv venv
    echo "Virtualenv created."
fi

source venv/bin/activate
pip install --upgrade pip -q
pip install -r requirements.txt -q
echo "All Python dependencies installed."
REMOTE

echo ""
echo "==> Setting up .env file on VM (if not exists)..."
$SSH bash << 'REMOTE'
set -e
ENV_FILE="/home/ubuntu/tractormate/.env"
if [ ! -f "$ENV_FILE" ]; then
    SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")
    cat > "$ENV_FILE" << EOF
SECRET_KEY=$SECRET
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
REFRESH_TOKEN_EXPIRE_DAYS=30
DATABASE_URL=sqlite:///./tractormate.db
BACKUP_DIR=/var/backups/tractormate
UPLOAD_DIR=./uploads
EOF
    echo ".env created with a fresh secret key."
else
    echo ".env already exists, skipping."
fi
mkdir -p /home/ubuntu/tractormate/uploads
REMOTE

echo ""
echo "==> Installing systemd service..."
$SSH "sudo cp /home/ubuntu/tractormate/scripts/tractormate.service /etc/systemd/system/tractormate.service && \
      sudo systemctl daemon-reload && \
      sudo systemctl enable tractormate && \
      sudo systemctl restart tractormate && \
      sleep 2 && sudo systemctl status tractormate --no-pager | head -15"

echo ""
echo "==> Patching nginx to add /tractormate-api/ location block..."
$SSH bash << REMOTE
set -e
NGINX_SITE="$NGINX_SITE"

# Check if the location block already exists
if sudo grep -q "tractormate-api" "\$NGINX_SITE"; then
    echo "nginx: /tractormate-api/ location block already exists, skipping."
else
    # Backup the existing nginx config before touching it
    sudo cp "\$NGINX_SITE" "\${NGINX_SITE}.bak_\$(date +%Y%m%d_%H%M%S)"
    echo "nginx: Backed up existing config."

    # Insert the tractormate location block before the "# Error pages" comment.
    # Using awk for reliable multi-line insertion — safer than sed.
    sudo awk '
    /# Error pages/ {
        print "    # TractorMate API - proxied to uvicorn on port 8001"
        print "    location /tractormate-api/ {"
        print "        proxy_pass         http://127.0.0.1:8001/;"
        print "        proxy_http_version 1.1;"
        print "        proxy_set_header   Host              \$host;"
        print "        proxy_set_header   X-Real-IP         \$remote_addr;"
        print "        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;"
        print "        proxy_set_header   X-Forwarded-Proto \$scheme;"
        print "        proxy_read_timeout 60s;"
        print "        client_max_body_size 10M;"
        print "    }"
        print ""
    }
    { print }
    ' "\$NGINX_SITE" > /tmp/tractormate_nginx_patch.conf

    sudo cp /tmp/tractormate_nginx_patch.conf "\$NGINX_SITE"
    echo "nginx: Location block inserted."
fi

# Test config before reloading
sudo nginx -t && sudo systemctl reload nginx
echo "nginx: Config valid and reloaded."
REMOTE

echo ""
echo "==> Setting up daily backup cron..."
$SSH bash << 'REMOTE'
set -e
chmod +x /home/ubuntu/tractormate/scripts/backup.sh
sudo mkdir -p /var/backups/tractormate

CRON_LINE="0 2 * * * /home/ubuntu/tractormate/scripts/backup.sh >> /var/log/tractormate_backup.log 2>&1"
( crontab -l 2>/dev/null | grep -qF "tractormate/scripts/backup.sh" ) && \
    echo "Cron: backup job already exists, skipping." || \
    ( (crontab -l 2>/dev/null; echo "$CRON_LINE") | crontab - && echo "Cron: backup job scheduled at 2:00 AM daily." )
REMOTE

echo ""
echo "==> Running health check..."
sleep 2
$SSH "curl -s http://127.0.0.1:8001/health"

echo ""
echo "============================================"
echo " TractorMate backend deployment complete!"
echo "============================================"
echo " Internal URL : http://127.0.0.1:8001"
echo " Public URL   : http://$VM_HOST/tractormate-api"
echo " API docs     : http://$VM_HOST/tractormate-api/docs"
echo " Health check : http://$VM_HOST/tractormate-api/health"
echo ""
echo " Default login:"
echo "   username: admin"
echo "   password: TractorMate@2024"
echo ""
echo " IMPORTANT: Change the admin password after first login!"
echo "============================================"
