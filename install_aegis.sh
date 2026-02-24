#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Headless Production Architecture) ---
# Protocol: Single Service Production (FastAPI + React Build)
# Automated deployment script for Debian/Ubuntu based systems.

set -e

# 0. Detect Real User (handles sudo)
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
INSTALL_DIR="$USER_HOME/Aegis-IA"
UPDATE_REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main"
ZIP_URL="$UPDATE_REPO_URL/aegis_latest.zip"

# Clear screen for a premium feel
clear
echo "🚀 [AEGIS-IA] Starting Automated Installation (Production Mode)..."
echo "-------------------------------------------------------------"

# 1. Directory & Source Orchestration
echo "📂 Preparing installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📡 Downloading latest core components..."
if curl -L -o /tmp/aegis_latest.zip "$ZIP_URL"; then
    echo "📦 Extracting system files..."
    unzip -o -q /tmp/aegis_latest.zip -d "$INSTALL_DIR"
    rm /tmp/aegis_latest.zip
else
    echo "❌ Error: Could not download the update package."
    exit 1
fi

PROJECT_ROOT=$(pwd)

# 2. System Dependencies
echo "📦 Checking system dependencies..."
REQUIRED_PKGS="python3 python3-venv python3-pip git build-essential curl unzip"
MISSING_PKGS=""
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "   ⚠️ Missing packages: $MISSING_PKGS"
    sudo apt-get update
    sudo apt-get install -y $MISSING_PKGS
fi

# 3. Node.js & npm Detection (v18+)
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -qE "v(18|2[0-9])"; then
    echo "🌐 Installing Node.js (v18+)..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    echo "✅ Node.js $(node -v) detected."
fi

# 4. Backend Setup
echo "🐍 Setting up Backend Environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo "❌ Error: requirements.txt not found!"
    exit 1
fi

# 5. Frontend Production Build
echo "🎨 Building Production UI (React)..."
if [ -d "ui_client" ]; then
    cd ui_client
    # Clean install to avoid ESM/Module conflicts
    rm -rf node_modules
    npm install --no-audit --no-fund
    echo "⚡ Compiling frontend assets..."
    npm run build
    cd ..
else
    echo "❌ Error: ui_client directory not found!"
    exit 1
fi

# 6. Systemd Service Configuration (Unified)
echo "⚙️  Configuring Aegis Service (Unified API/UI)..."

# Aegis Core Service (Serves both API and UI from /dist)
cat <<EOF | sudo tee /etc/systemd/system/aegis-core.service
[Unit]
Description=Aegis-IA Unified Service
After=network.target

[Service]
User=$REAL_USER
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/.venv/bin/python -m uvicorn server_aegis:app --host 0.0.0.0 --port 8000
Restart=always
Environment=PYTHONUNBUFFERED=1
Environment=AEGIS_PRODUCTION=true

[Install]
WantedBy=multi-user.target
EOF

# Ensure any old UI service is removed to avoid port conflicts
sudo systemctl stop aegis-ui 2>/dev/null || true
sudo systemctl disable aegis-ui 2>/dev/null || true
sudo rm -f /etc/systemd/system/aegis-ui.service

# Reload and Start Unified Service
echo "🔄 Initializing unified service..."
sudo systemctl daemon-reload
sudo systemctl enable aegis-core
sudo systemctl start aegis-core

# 7. Firewall Configuration
if command -v ufw >/dev/null 2>&1; then
    echo "🛡️  Configuring Firewall: Opening port 8000..."
    sudo ufw allow 8000/tcp > /dev/null || true
fi

# 8. User Permissions Fix
echo "🔐 Optimizing file permissions..."
sudo chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR"

# 9. Final Messages
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then LOCAL_IP="127.0.0.1"; fi

echo "-------------------------------------------------------------"
echo "🔥 AEGIS-IA IS OPERATIONAL (PRODUCTION MODE)"
echo "============================================================="
echo "🌍 ACCESS URL: http://$LOCAL_IP:8000"
echo "============================================================="
echo "💡 Commands:"
echo "   - View System Logs: journalctl -u aegis-core -f"
echo "   - Restart System:   sudo systemctl restart aegis-core"
echo "-------------------------------------------------------------"
echo "Aegis ahora se sirve de forma unificada en el puerto 8000."
echo "La interfaz UI y la API comparten el mismo túnel de red."
