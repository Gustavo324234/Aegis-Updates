#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Headless Architecture) ---
# Protocol: Public Zip Distribution (Aegis-Updates)
# Automated deployment script for Debian/Ubuntu based systems.
# FastAPI Backend + React/Vite Frontend

set -e

# 0. Configuration
INSTALL_DIR="$HOME/Aegis-IA"
UPDATE_REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main"
ZIP_URL="$UPDATE_REPO_URL/aegis_latest.zip"

# Clear screen for a premium feel
clear
echo "🚀 [AEGIS-IA] Starting Automated Installation (Headless Mode)..."
echo "-------------------------------------------------------------"

# 1. Directory & Source Orchestration (Public Download)
echo "📂 Preparing installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📡 Downloading latest core components from Aegis-Updates..."
if curl -L -o /tmp/aegis_latest.zip "$ZIP_URL"; then
    echo "📦 Extracting system files..."
    # We use -o to overwrite existing files upon update
    unzip -o -q /tmp/aegis_latest.zip -d "$INSTALL_DIR"
    rm /tmp/aegis_latest.zip
else
    echo "❌ Error: Could not download the update package. Check your connection."
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

# 3. Node.js & npm Detection/Installation
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
    echo "❌ Error: requirements.txt not found after extraction in $PROJECT_ROOT"
    exit 1
fi

# 5. Frontend Setup
echo "🎨 Setting up React UI Client..."
if [ -d "ui_client" ]; then
    cd ui_client
    npm install
    cd ..
else
    echo "❌ Error: ui_client directory not found!"
    exit 1
fi

# 6. Systemd Services Generation
echo "⚙️  Configuring Persistent Services (Systemd)..."
USER_NAME=$(whoami)
NPM_PATH=$(command -v npm)

# Aegis Core Service (API)
cat <<EOF | sudo tee /etc/systemd/system/aegis-core.service
[Unit]
Description=Aegis-IA Core (FastAPI Backend)
After=network.target

[Service]
User=$USER_NAME
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/.venv/bin/python -m uvicorn server_aegis:app --host 0.0.0.0 --port 8000
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
EOF

# Aegis UI Service (Frontend)
cat <<EOF | sudo tee /etc/systemd/system/aegis-ui.service
[Unit]
Description=Aegis-IA UI (React Frontend)
After=network.target aegis-core.service

[Service]
User=$USER_NAME
WorkingDirectory=$PROJECT_ROOT/ui_client
ExecStart=$NPM_PATH run dev -- --host
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload and Enable Services
echo "🔄 Initializing services..."
sudo systemctl daemon-reload
sudo systemctl enable aegis-core
sudo systemctl enable aegis-ui
sudo systemctl start aegis-core
sudo systemctl start aegis-ui

# 7. Firewall Configuration (Security Protocol)
if command -v ufw >/dev/null 2>&1; then
    echo "🛡️  Configuring Firewall (UFW): Opening ports 5173 and 8000..."
    sudo ufw allow 5173/tcp > /dev/null || true
    sudo ufw allow 8000/tcp > /dev/null || true
    # If ufw is disabled, don't force it on, just ensure the rules are there.
fi

# 8. Final Messages & Discovery
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then LOCAL_IP="127.0.0.1"; fi

echo "-------------------------------------------------------------"
echo "🔥 AEGIS-IA IS OPERATIONAL"
echo "============================================================="
echo "🖥️  FRONTEND DYNAMO (UI):  http://$LOCAL_IP:5173"
echo "🔌 BACKEND NERVE (API):     http://$LOCAL_IP:8000"
echo "============================================================="
echo "💡 Commands:"
echo "   - View Core Logs: journalctl -u aegis-core -f"
echo "   - View UI Logs:   journalctl -u aegis-ui -f"
echo "   - Restart System: sudo systemctl restart aegis-core aegis-ui"
echo "-------------------------------------------------------------"
echo "Aegis ahora arrancará automáticamente al iniciar el sistema."
