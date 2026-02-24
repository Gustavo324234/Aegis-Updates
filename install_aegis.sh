#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Zero-Touch Production Architecture) ---
# Protocol: Self-Healing Full Automation
# Author: Aegis-IA Release Engineer

set -e

# 0. Global Setup & Permission Handling
export DEBIAN_FRONTEND=noninteractive
REAL_USER=${SUDO_USER:-$USER}
USER_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
INSTALL_DIR="$USER_HOME/Aegis-IA"
UPDATE_REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main"
ZIP_URL="$UPDATE_REPO_URL/aegis_latest.zip"

# Clear screen for a premium feel
clear
echo "🚀 [AEGIS-IA] Starting Full Automated Deployment..."
echo "-------------------------------------------------------------"

# 1. System Dependencies (Core)
echo "📦 Installing core system tools..."
sudo apt-get update -y -qq
sudo apt-get install -y -qq python3 python3-venv python3-pip git build-essential curl unzip wget ufw > /dev/null

# 2. Node.js v20+ Forced Installation (Vite 7 Requirement)
echo "🌐 Checking Node.js runtime..."
REINSTALL_NODE=false
if ! command -v node >/dev/null 2>&1; then
    REINSTALL_NODE=true
else
    NODE_VER=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [ "$NODE_VER" -lt 20 ]; then
        echo "   ⚠️  Detected Node.js $NODE_VER. Upgrading to v20 for Vite 7 compatibility..."
        REINSTALL_NODE=true
    fi
fi

if [ "$REINSTALL_NODE" = true ]; then
    echo "   📡 Fetching Node.js v20 from NodeSource..."
    sudo rm -f /etc/apt/sources.list.d/nodesource.list
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - > /dev/null
    sudo apt-get purge -y nodejs npm > /dev/null 2>&1 || true
    sudo apt-get install -y nodejs > /dev/null
    echo "   ✅ Node.js $(node -v) successfully installed."
else
    echo "   ✅ Node.js $(node -v) already compliant."
fi

# 3. Directory & Source Orchestration
echo "📂 Orchestrating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

echo "📡 Downloading latest AEC-Aegis bundle..."
if curl -L -o /tmp/aegis_latest.zip "$ZIP_URL"; then
    echo "📦 Extracting system files..."
    unzip -o -q /tmp/aegis_latest.zip -d "$INSTALL_DIR"
    rm /tmp/aegis_latest.zip
    
    # --- AUTO-HEAL: Handle nested folder structures from ZIP (e.g., GitHub main/ folder) ---
    # Find where 'requirements.txt' or 'ui_client' is
    SEARCH_PATH=$(find "$INSTALL_DIR" -maxdepth 2 -name "requirements.txt" | head -n 1)
    if [ -n "$SEARCH_PATH" ]; then
        ACTUAL_ROOT=$(dirname "$SEARCH_PATH")
        if [ "$ACTUAL_ROOT" != "$INSTALL_DIR" ]; then
            echo "📂 Detected nested structure at $ACTUAL_ROOT. Adjusting roots..."
            mv "$ACTUAL_ROOT"/* "$INSTALL_DIR/" 2>/dev/null || true
            mv "$ACTUAL_ROOT"/.* "$INSTALL_DIR/" 2>/dev/null || true
            # Clean up empty subdirectory if it's different
            [ "$ACTUAL_ROOT" != "$INSTALL_DIR" ] && rmdir "$ACTUAL_ROOT" 2>/dev/null || true
        fi
    fi
else
    echo "❌ CRITICAL ERROR: Could not fetch deployment package. Check network."
    exit 1
fi

PROJECT_ROOT=$(pwd)

# 4. Backend Setup
echo "🐍 Initializing Python Reactor (.venv)..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install --upgrade pip -q
if [ -f "requirements.txt" ]; then
    echo "   🛠️  Installing neural dependencies..."
    pip install -r requirements.txt -q
else
    echo "❌ ERROR: requirements.txt missing in bundle!"
    exit 1
fi

# 5. Frontend Production Architecture
echo "🎨 Compiling Production UI (React + Vite 7)..."
if [ -d "ui_client" ]; then
    cd ui_client
    # Verify index.html exists in root
    if [ ! -f "index.html" ]; then
        echo "   ⚠️  Warning: index.html not in ui_client root. Checking subdirs..."
        # In case the zip structure has another level
        if [ -f "src/index.html" ]; then mv src/index.html ./; fi
    fi
    
    echo "   📦 Fetching frontend modules..."
    rm -rf node_modules package-lock.json
    npm install --no-audit --no-fund --quiet
    
    echo "   ⚡ Optimizing assets for high performance..."
    npm run build --quiet
    cd ..
else
    echo "❌ ERROR: ui_client directory not found!"
    exit 1
fi

# 6. Systemd Service Integration
echo "⚙️  Registering Aegis-IA Unified Service..."
cat <<EOF | sudo tee /etc/systemd/system/aegis-core.service > /dev/null
[Unit]
Description=Aegis-IA Unified Core Service
After=network.target

[Service]
User=$REAL_USER
WorkingDirectory=$PROJECT_ROOT
ExecStart=$PROJECT_ROOT/.venv/bin/python -m uvicorn server_aegis:app --host 0.0.0.0 --port 8000
Restart=always
Environment=PYTHONUNBUFFERED=1
Environment=AEGIS_PRODUCTION=true
Environment=PATH=$PROJECT_ROOT/.venv/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=multi-user.target
EOF

# Clean up legacy UI service if present
sudo systemctl stop aegis-ui 2>/dev/null || true
sudo systemctl disable aegis-ui 2>/dev/null || true
sudo rm -f /etc/systemd/system/aegis-ui.service

echo "🔄 Activating system reactor..."
sudo systemctl daemon-reload
sudo systemctl enable aegis-core > /dev/null 2>&1
sudo systemctl restart aegis-core

# 7. Network & Security Settings
if command -v ufw >/dev/null 2>&1; then
    echo "🛡️  Opening neural gates (Port 8000)..."
    sudo ufw allow 8000/tcp > /dev/null || true
fi

# 8. Permissions Finalization
sudo chown -R $REAL_USER:$REAL_USER "$INSTALL_DIR"

# 9. Final Report
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then LOCAL_IP="127.0.0.1"; fi

echo "-------------------------------------------------------------"
echo "🛡️  AEGIS-IA DEPLOYMENT SUCCESSFUL"
echo "============================================================="
echo "🌍 ACCESS INTERFACE: http://$LOCAL_IP:8000"
echo "📡 CORE STATUS:      Running (Unified Mode)"
echo "============================================================="
echo "💡 Commands for SRE:"
echo "   - Watch Logs: journalctl -u aegis-core -f"
echo "   - Restart:    sudo systemctl restart aegis-core"
echo "-------------------------------------------------------------"
echo "Instalación completada. Aegis es ahora accesible en tu red local."
