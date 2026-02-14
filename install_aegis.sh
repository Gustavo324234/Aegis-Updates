#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Protocol 62-L-Fixed) ---
# Automated deployment script for Debian/Ubuntu based systems.

REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main/aegis_latest.zip"
INSTALL_DIR="$HOME/Aegis-IA"
SERVICE_NAME="aegis.service"

set -e # Exit immediately on error

echo "🚀 [AEGIS-IA] Starting Automated Installation (Protocol 62-L-Fixed)..."

# 0. Check Permissions (Require sudo from start if possible to avoid interruptions)
if [ "$(id -u)" -eq 0 ]; then
    echo "⚠️ Warning: Running as root. It is recommended to run as a standard user with sudo privileges."
fi

# 1. Update & Install System Dependencies
echo "📦 1/5 Checking system dependencies..."

# Core deps + Build deps for PyAudio/C-Extensions + FFmpeg for Audio
REQUIRED_PKGS="python3 python3-venv python3-pip unzip curl sqlite3 git portaudio19-dev python3-dev libasound2-dev ffmpeg build-essential"
MISSING_PKGS=""

# Check installed packages
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "   ⚠️ Missing packages:$MISSING_PKGS"
    echo "   sudo access required to update and install dependencies."
    
    if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y $MISSING_PKGS
    else
        echo "   ❌ 'sudo' not found. Please execute the following manually as root:"
        echo "   apt-get update && apt-get install -y $MISSING_PKGS"
        exit 1
    fi
else
    echo "   ✅ All system dependencies are met."
fi

# 2. Download Artifact
echo "⬇️ 2/5 Downloading Aegis Core Artifact..."

# Backup existing directory if it exists and isn't empty
if [ -d "$INSTALL_DIR" ]; then
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    echo "   ⚠️ Detected existing installation. Backing up to ${INSTALL_DIR}_bak_$TIMESTAMP..."
    mv "$INSTALL_DIR" "${INSTALL_DIR}_bak_$TIMESTAMP"
fi

mkdir -p "$INSTALL_DIR"
# Use absolute path for safety
ABS_INSTALL_DIR=$(cd "$INSTALL_DIR" && pwd)

if curl -L -o /tmp/aegis_latest.zip "$REPO_URL"; then
    echo "   Download complete."
else
    echo "   ❌ Download failed. Check internet connection and URL."
    exit 1
fi

# 3. Extract Deployment
echo "📂 3/5 Extracting files..."
unzip -q /tmp/aegis_latest.zip -d "$ABS_INSTALL_DIR"

# Handle potential nested folder if zip captures root folder
# Check if root contains 'Aegis-IA' or 'Aegis-IA-main'
NESTED_DIR=$(find "$ABS_INSTALL_DIR" -maxdepth 1 -type d -name "Aegis-IA*" | head -n 1)
if [ -n "$NESTED_DIR" ] && [ "$NESTED_DIR" != "$ABS_INSTALL_DIR" ]; then
    echo "   Detected nested directory: $NESTED_DIR. Moving contents up..."
    mv "$NESTED_DIR/"* "$ABS_INSTALL_DIR/"
    rmdir "$NESTED_DIR"
fi

rm /tmp/aegis_latest.zip
echo "   ✅ Extracted to $ABS_INSTALL_DIR"

# 4. Environment Setup
echo "🐍 4/5 Setting up Virtual Environment..."
cd "$ABS_INSTALL_DIR"
python3 -m venv .venv
source .venv/bin/activate

# Critical: Upgrade pip/setuptools/wheel for robust compilation
echo "   Upgrading pip, setuptools, and wheel..."
pip install --upgrade pip setuptools wheel > /dev/null

echo "   Installing Python Dependencies (This may take a few minutes)..."
if pip install -r requirements.txt; then
    echo "   ✅ Dependencies installed successfully."
else
    echo "   ❌ PIP INSTALL FAILED."
    echo "   This is likely due to a compilation error (e.g., PyAudio)."
    echo "   Please check the error log above."
    exit 1
fi

# 5. Systemd Persistence
echo "⚙️ 5/5 Configuring Background Service..."
CURRENT_USER=$(whoami)
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
PYTHON_BIN="$ABS_INSTALL_DIR/.venv/bin/python"
STREAMLIT_BIN="$ABS_INSTALL_DIR/.venv/bin/streamlit"

# Verify binaries exist
if [ ! -f "$STREAMLIT_BIN" ]; then
    STREAMLIT_BIN="$PYTHON_BIN -m streamlit"
fi

# Construct absolute execution command
EXEC_CMD="$STREAMLIT_BIN run $ABS_INSTALL_DIR/admin_launcher.py --server.port 8501 --server.headless true"

echo "   Creating service file at $SERVICE_FILE (requires sudo)..."

if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
else
    SUDO=""
fi

cat <<EOF | $SUDO tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Aegis IA Server (Port 8501)
After=network.target

[Service]
User=$CURRENT_USER
WorkingDirectory=$ABS_INSTALL_DIR
ExecStart=$EXEC_CMD
Restart=always
RestartSec=5
# Ensure venv takes precedence
Environment=PATH=$ABS_INSTALL_DIR/.venv/bin:/usr/bin:/usr/local/bin
# Fix encoding for non-interactive shells
Environment=PYTHONIOENCODING=utf-8
# Fix Streamlit config paths
Environment=STREAMLIT_CONFIG_DIR=$ABS_INSTALL_DIR/.streamlit

[Install]
WantedBy=multi-user.target
EOF

echo "   Reloading Systemd..."
$SUDO systemctl daemon-reload
$SUDO systemctl enable "$SERVICE_NAME"
$SUDO systemctl restart "$SERVICE_NAME"

# 6. Final Report
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ INSTALLATION SUCCESSFUL!"
echo "==================================================="
echo "🖥️  Web Interface: http://$LOCAL_IP:8501"
echo "📂 Data Directory: $ABS_INSTALL_DIR"
echo "🔧 View Logs:      $SUDO journalctl -u $SERVICE_NAME -f"
echo "🛑 Stop Server:    $SUDO systemctl stop $SERVICE_NAME"
echo "==================================================="
