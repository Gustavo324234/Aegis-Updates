#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Zero-Touch Production Architecture) ---
# Protocol: Self-Healing Full Automation v3 (Omni-Locator Engine)
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
echo "🚀 [AEGIS-IA] Starting Full Automated Deployment (Omni-Locator Mode)..."
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
    
    # --- OMNI-LOCATOR: Normalize structure regardless of ZIP nesting ---
    echo "🔍 Analyzing structure topology..."
    # Find the heart of the project (requirements.txt)
    HART_PATH=$(find "$INSTALL_DIR" -maxdepth 4 -name "requirements.txt" | head -n 1)
    if [ -n "$HART_PATH" ]; then
        ACTUAL_ROOT=$(dirname "$HART_PATH")
        if [ "$ACTUAL_ROOT" != "$INSTALL_DIR" ]; then
            echo "📂 Detected nested structure at $ACTUAL_ROOT. Moving files to root..."
            cp -r "$ACTUAL_ROOT"/. "$INSTALL_DIR/" 2>/dev/null || true
            # Avoid deleting the current directory if we are in it
            [ "$ACTUAL_ROOT" != "$INSTALL_DIR" ] && rm -rf "$ACTUAL_ROOT"
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
    echo "❌ ERROR: requirements.txt missing after normalization!"
    exit 1
fi

# 5. Frontend Production Architecture
echo "🎨 Compiling Production UI (React + Vite 7)..."

# Find ui_client folder wherever it is
UI_PATH=$(find "$PROJECT_ROOT" -maxdepth 3 -type d -name "ui_client" | head -n 1)
if [ -n "$UI_PATH" ]; then
    cd "$UI_PATH"
    echo "   📍 Fixed UI environment: $(pwd)"
    
    # Verify index.html existence and vital files
    if [ ! -f "index.html" ]; then
        echo "   🔍 index.html not found in current UI root. Searchingโครงการ..."
        DEEP_INDEX=$(find "$PROJECT_ROOT" -name "index.html" | head -n 1)
        if [ -n "$DEEP_INDEX" ]; then
            echo "   ✅ Found at $DEEP_INDEX. Relocating..."
            cp "$DEEP_INDEX" ./index.html
        else
            echo "   ⚠️  Warning: index.html missing from bundle. Creating emergency shim..."
            cat <<EOF > index.html
<!doctype html>
<html lang="en"><head><meta charset="UTF-8" /><title>Aegis-IA</title></head>
<body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body></html>
EOF
        fi
    fi

    # Vital Source locator
    if [ ! -d "src" ]; then
        echo "   🔍 src/ directory missing in UI root. Looking for survivors..."
        DEEP_SRC=$(find "$PROJECT_ROOT" -type d -name "src" | grep "ui_client" | head -n 1)
        if [ -n "$DEEP_SRC" ] && [ "$DEEP_SRC" != "$(pwd)/src" ]; then
            echo "   ✅ Found src at $DEEP_SRC. Moving to root..."
            cp -r "$DEEP_SRC" ./
        fi
    fi

    # Vite Config locator
    if [ ! -f "vite.config.mjs" ] && [ ! -f "vite.config.js" ]; then
        echo "   🛠️  Recreating building specs (Vite Config)..."
        cat <<EOF > vite.config.mjs
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react-swc';
import tailwindcss from '@tailwindcss/vite';
export default defineConfig({ plugins: [react(), tailwindcss()] });
EOF
    fi
    
    echo "   📦 Fetching modules (npm install)..."
    rm -rf node_modules package-lock.json
    npm install --no-audit --no-fund --quiet
    
    echo "   ⚡ Optimizing assets..."
    # Build attempt with debug info
    if ! npm run build; then
        echo "❌ BUILD FAILED. PROJECT MAP:"
        find . -maxdepth 2
        exit 1
    fi
    cd "$PROJECT_ROOT"
else
    echo "❌ ERROR: ui_client directory not found anywhere!"
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
echo "============================================================="
echo "💡 Commands for SRE:"
echo "   - Watch Logs: journalctl -u aegis-core -f"
echo "   - Restart:    sudo systemctl restart aegis-core"
echo "-------------------------------------------------------------"
