#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Headless Architecture) ---
# Protocol: Safe Install Directory
# Automated deployment script for Debian/Ubuntu based systems.
# FastAPI Backend + React/Vite Frontend

set -e

# 0. Define and Navigate to Safe Installation Directory
INSTALL_DIR="$HOME/Aegis-IA"
REPO_URL="https://github.com/Gustavo324234/Aegis-IA.git"

# Clear screen for a premium feel
clear
echo "🚀 [AEGIS-IA] Starting Automated Installation (Headless Mode)..."
echo "-------------------------------------------------------------"

# 1. Directory & Source Orchestration
if [ ! -d "$INSTALL_DIR" ]; then
    echo "📂 Creating secure installation directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    echo "📡 Cloning repository..."
    git clone "$REPO_URL" .
else
    echo "📂 Existing installation found at $INSTALL_DIR. Synchronizing..."
    cd "$INSTALL_DIR"
    if [ -d ".git" ]; then
        echo "🔄 Pulling latest updates..."
        git pull origin main || git pull origin master || echo "⚠️ Warning: git pull failed, continuing with local files."
    else
        if [ -n "$(ls -A "$INSTALL_DIR" 2>/dev/null)" ]; then
            echo "⚠️ Warning: Directory exists and is not empty, but no .git found."
            echo "🛠️ Attempting to repair and fetch source code..."
            git init
            git remote add origin "$REPO_URL" || true
            git fetch origin
            git checkout -f origin/main || git checkout -f origin/master || echo "⚠️ Warning: Could not checkout branch."
        else
            echo "📡 Directory is empty. Cloning repository..."
            git clone "$REPO_URL" .
        fi
    fi
fi

PROJECT_ROOT=$(pwd)

# Verify we have the files
if [ ! -f "requirements.txt" ]; then
    echo "❌ Error: requirements.txt not found in $PROJECT_ROOT"
    echo "   Ensure the repository was cloned correctly."
    exit 1
fi

# 2. System Dependencies
echo "📦 Checking system dependencies..."
REQUIRED_PKGS="python3 python3-venv python3-pip git build-essential curl"
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
pip install -r requirements.txt

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

# 7. Final Messages & Discovery
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
