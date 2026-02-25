#!/bin/bash

# --- AEGIS-IA INSTALLER & UPDATER (Headless Multi-Tenant Protocol) ---
# Role: SRE & DevOps Engineer
# Description: Automates the cleaning, downloading, compiling, and restarting of the Aegis-IA system.

# Configuration
INSTALL_DIR="/home/$(logname)/Aegis-IA"
UPDATE_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main/aegis_latest.zip"
VENV_PATH="$INSTALL_DIR/.venv/bin/python"

echo "🛡️ [AEGIS-IA] Initializing Installation/Update Process..."

# 1. PHASE: Cleanup (Kill legacy instances and free ports)
echo "🧹 Phase 1: Cleaning up legacy processes..."
sudo pkill -9 -f "server_aegis:app" || true
sudo pkill -9 -f "app_web.py" || true
sudo pkill -9 -f "admin_launcher.py" || true
sudo pkill -9 -f "process_watchdog.py" || true
sudo pkill -9 -f "vite" || true

echo "🔓 Releasing ports 8000 and 8501..."
sudo fuser -k 8000/tcp || true
sudo fuser -k 8501/tcp || true

# 2. PHASE: Download & Extraction
echo "📡 Phase 2: Downloading latest version from GitHub..."
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

if curl -L -o aegis_latest.zip "$UPDATE_URL"; then
    echo "📦 Extracting package..."
    unzip -o aegis_latest.zip
    rm aegis_latest.zip
else
    echo "❌ Error: Failed to download the update package."
    exit 1
fi

# 3. PHASE: Compilation (CRITICAL for Headless Multi-Tenant)
echo "⚙️ Phase 3: Compiling system components..."

# Execute backend setup
if [ -f "setup.py" ]; then
    echo "🐍 Running Python setup..."
    python3 setup.py
else
    echo "⚠️ Warning: setup.py not found, skipping."
fi

# Compile React Frontend to Static
if [ -d "ui_client" ]; then
    echo "🎨 Building React frontend (ui_client)..."
    cd ui_client
    echo "📥 Installing frontend dependencies..."
    npm install --quiet
    echo "🏗️  Compiling to production static files..."
    npm run build
    cd "$INSTALL_DIR"
else
    echo "❌ Error: ui_client directory not found! Front-end build postponed."
    exit 1
fi

# 4. PHASE: Restart
echo "🚀 Phase 4: Restarting Aegis-IA Core Service..."

if [ -f "$VENV_PATH" ]; then
    echo "🛰️  Lifting backend in background mode..."
    nohup "$VENV_PATH" -m uvicorn server_aegis:app --host 0.0.0.0 --port 8000 > aegis_system.log 2>&1 &
    
    # Optional: Brief wait to ensure it starts
    sleep 2
    if pgrep -f "server_aegis:app" > /dev/null; then
        echo "✅ Aegis-IA is now LIVE at http://0.0.0.0:8000"
    else
        echo "❌ Critical: Server failed to start. Check aegis_system.log"
    fi
else
    echo "❌ Error: Virtual environment not found at $VENV_PATH"
    echo "💡 Try running 'python3 -m venv .venv' and 'pip install -r requirements.txt' first."
    exit 1
fi

echo "-------------------------------------------------------------"
echo "🛡️  AEGIS-IA UPDATE COMPLETED SUCCESSFULLY"
echo "============================================================="
