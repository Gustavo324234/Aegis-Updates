#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Protocol 62-Data-Decoupled) ---
# Automated deployment script for Debian/Ubuntu based systems.
# Features: Auto-Dependency, VENV, Decoupled Data Persistence (Symlinks), Atomic Execution, Auto-Heal.

REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main/aegis_latest.zip"
INSTALL_DIR="$HOME/Aegis-IA"
DATA_DIR="$HOME/Aegis-Data"

set -e # Exit immediately on error

echo "🚀 [AEGIS-IA] Starting Automated Installation (Protocol 62-Data-Decoupled)..."

# 1. State Orchestrator Check (Persistence & Upgrade)
export IS_UPGRADE=false
if [ -d "$DATA_DIR" ]; then
    echo "   ✅ Found existing sibling Aegis-Data. Treating as UPGRADE."
    export AEGIS_USER_ROOT="$DATA_DIR"
    IS_UPGRADE=true
else
    echo "   🌱 No sibling Aegis-Data found. Treating as FRESH INSTALL."
    export AEGIS_USER_ROOT="$DATA_DIR"
    mkdir -p "$DATA_DIR"
fi

# 2. Headless Detection (SSH/CLI)
export IS_HEADLESS=false
if [ -z "$DISPLAY" ] || [ -n "$SSH_TTY" ]; then
    echo "   🖥️ Headless environment detected (SSH/No-GUI). Activating Bunker Mode."
    IS_HEADLESS=true
fi

# 3. System Dependencies (Atomic Execute)
echo "📦 Checking system dependencies..."
REQUIRED_PKGS="python3 python3-venv python3-pip unzip curl sqlite3 git build-essential"
MISSING_PKGS=""
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "   ⚠️ Missing packages:$MISSING_PKGS"
    if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y $MISSING_PKGS
    else
        echo "   ❌ 'sudo' not available. Install manually: apt-get install -y $MISSING_PKGS"
        exit 1
    fi
fi

# 4. Atomic Code Download/Extract (Replacing old code)
echo "⬇️ Downloading Core System..."
mkdir -p "$INSTALL_DIR"
ABS_INSTALL_DIR=$(cd "$INSTALL_DIR" && pwd)

if curl -L -o /tmp/aegis_latest.zip "$REPO_URL"; then
    echo "   Download complete. Extracting..."
    unzip -q -o /tmp/aegis_latest.zip -d /tmp/aegis_temp
    
    # Identify nested root folder if exists
    NESTED_DIR=$(find /tmp/aegis_temp -maxdepth 1 -type d -name "Aegis-IA*" | head -n 1)
    if [ -n "$NESTED_DIR" ] && [ "$NESTED_DIR" != "/tmp/aegis_temp" ]; then
        cp -r "$NESTED_DIR"/* "$ABS_INSTALL_DIR/"
    else
        cp -r /tmp/aegis_temp/* "$ABS_INSTALL_DIR/"
    fi
    rm -rf /tmp/aegis_latest.zip /tmp/aegis_temp
else
    echo "   ❌ Download failed."
    exit 1
fi

# 5. Runtime & VENV
echo "🐍 Setting up Runtime..."
cd "$ABS_INSTALL_DIR"
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

pip install --upgrade pip > /dev/null
pip install -r requirements.txt > /dev/null

# 6. Verify Integrity Check
echo "🛡️ Running Aegis Integrity Protocols..."
if ! python verify_integrity.py; then
    echo "❌ Integrity check failed. Halting installation to prevent corruption."
    exit 1
fi

# 7. Final Launch via Watchdog (Lázaro Protocol)
LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || ip route get 1 | awk '{print $7}')
if [ -z "$LOCAL_IP" ]; then LOCAL_IP="127.0.0.1"; fi

echo ""
echo "🔥 AEGIS IS READY: Launching System..."
echo "==================================================="
echo "💾 Persistent Data: $DATA_DIR"
echo "🔗 Application:     $ABS_INSTALL_DIR"
echo "🛠️  SRE / Admin Console: http://$LOCAL_IP:8501"

REGISTRY_FILE="$DATA_DIR/tenants_registry.json"
if [ -f "$REGISTRY_FILE" ]; then
    echo "👥 Active Users/Tenants Detected:"
    python3 -c "
import json
try:
    with open('$REGISTRY_FILE', 'r') as f:
        data = json.load(f)
    found = False
    for user, info in data.items():
        if info.get('status') == 'active':
            port = info.get('port')
            print(f'   -> {user}: http://$LOCAL_IP:{port}')
            found = True
    if not found:
        print('   No active users found.')
except Exception as e:
    pass
"
fi
echo "==================================================="

CMDS="python process_watchdog.py --data-root \"$DATA_DIR\""
if [ "$IS_HEADLESS" = true ]; then
    CMDS="$CMDS --headless"
fi

eval $CMDS
