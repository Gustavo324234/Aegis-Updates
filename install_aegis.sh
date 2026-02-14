#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Protocol 62-L) ---
# Automated deployment script for Debian/Ubuntu based systems.

REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main/aegis_latest.zip"
INSTALL_DIR="$HOME/Aegis-IA"
SERVICE_NAME="aegis.service"

set -e # Exit on error

echo "🚀 [AEGIS-IA] Starting Automated Installation..."

# 1. Check & Install Dependencies
echo "📦 1/5 Checking system dependencies..."
REQUIRED_PKGS="python3 python3-venv python3-pip unzip curl sqlite3"
MISSING_PKGS=""

# Simple check using dpkg
for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "   ⚠️ Missing packages:$MISSING_PKGS"
    echo "   sudo access required to install dependencies."
    sudo apt-get update
    sudo apt-get install -y $MISSING_PKGS
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
curl -L -o /tmp/aegis_latest.zip "$REPO_URL"

# 3. Extract Deployment
echo "📂 3/5 Extracting files..."
unzip -q /tmp/aegis_latest.zip -d "$INSTALL_DIR"
# Handle potential nested folder if zip captures root folder
if [ -d "$INSTALL_DIR/Aegis-IA" ]; then
    mv "$INSTALL_DIR/Aegis-IA/"* "$INSTALL_DIR/"
    rmdir "$INSTALL_DIR/Aegis-IA"
fi
rm /tmp/aegis_latest.zip
echo "   ✅ Extracted to $INSTALL_DIR"

# 4. Environment Setup
echo "🐍 4/5 Setting up Virtual Environment..."
cd "$INSTALL_DIR"
python3 -m venv .venv
source .venv/bin/activate
echo "   Installing Python Dependencies (This may take a minute)..."
pip install --upgrade pip > /dev/null
pip install -r requirements.txt > /dev/null

# 5. Systemd Persistence
echo "⚙️ 5/5 Configuring Background Service..."
CURRENT_USER=$(whoami)
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
PYTHON_BIN="$INSTALL_DIR/.venv/bin/python"
STREAMLIT_BIN="$INSTALL_DIR/.venv/bin/streamlit"

# Check if streamlit bin exists, otherwise use python -m streamlit
EXEC_CMD="$STREAMLIT_BIN run admin_launcher.py --server.port 8501 --server.headless true"
if [ ! -f "$STREAMLIT_BIN" ]; then
    EXEC_CMD="$PYTHON_BIN -m streamlit run admin_launcher.py --server.port 8501 --server.headless true"
fi

echo "   Creating service file at $SERVICE_FILE (requires sudo)..."

cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Aegis IA Server (Port 8501)
After=network.target

[Service]
User=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=$EXEC_CMD
Restart=always
RestartSec=5
Environment=PATH=$INSTALL_DIR/.venv/bin:/usr/bin:/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

echo "   Reloading Systemd..."
sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl restart "$SERVICE_NAME"

# 6. Final Report
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ INSTALLATION COMPLETE!"
echo "==================================================="
echo "🖥️  Web Interface: http://$LOCAL_IP:8501"
echo "📂 Data Directory: $INSTALL_DIR"
echo "🔧 View Logs:      sudo journalctl -u $SERVICE_NAME -f"
echo "🛑 Stop Server:    sudo systemctl stop $SERVICE_NAME"
echo "==================================================="
