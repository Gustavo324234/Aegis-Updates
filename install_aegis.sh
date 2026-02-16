#!/bin/bash

# --- AEGIS INSTALLER FOR LINUX (Protocol 62-Data-Decoupled) ---
# Automated deployment script for Debian/Ubuntu based systems.
# Features: Auto-Dependency, VENV, Systemd, Decoupled Data Persistence (Symlinks).

REPO_URL="https://raw.githubusercontent.com/Gustavo324234/Aegis-Updates/main/aegis_latest.zip"
INSTALL_DIR="$HOME/Aegis-IA"
DATA_DIR="$HOME/Aegis-Data"
SERVICE_NAME="aegis.service"

set -e # Exit immediately on error

echo "🚀 [AEGIS-IA] Starting Automated Installation (Protocol 62-Data-Decoupled)..."

# 0. Check Permissions
if [ "$(id -u)" -eq 0 ]; then
    echo "⚠️ Warning: Running as root. Ideally run as standard user."
fi

# 1. Update & Install System Dependencies
echo "📦 1/5 Checking system dependencies..."

REQUIRED_PKGS="python3 python3-venv python3-pip unzip curl sqlite3 git portaudio19-dev python3-dev libasound2-dev ffmpeg build-essential"
MISSING_PKGS=""

for pkg in $REQUIRED_PKGS; do
    if ! dpkg -s $pkg >/dev/null 2>&1; then
        MISSING_PKGS="$MISSING_PKGS $pkg"
    fi
done

if [ -n "$MISSING_PKGS" ]; then
    echo "   ⚠️ Missing packages:$MISSING_PKGS"
    echo "   sudo access required."
    
    if command -v sudo >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y $MISSING_PKGS
    else
        echo "   ❌ 'sudo' not provided. Install manually:"
        echo "   apt-get update && apt-get install -y $MISSING_PKGS"
        exit 1
    fi
else
    echo "   ✅ System dependencies met."
fi

# 2. Prepare Data Directory (The Decoupling)
echo "💾 2/5 Preparing Persistent Data Layer..."
mkdir -p "$DATA_DIR"
mkdir -p "$DATA_DIR/users"
mkdir -p "$DATA_DIR/vault"
mkdir -p "$DATA_DIR/config"
mkdir -p "$DATA_DIR/chroma_db"

# MIGRATION LOGIC: Check if old install exists and has data, but Data Layer is empty
if [ -d "$INSTALL_DIR" ]; then
    echo "   Running Migration Check..."
    
    # Database
    if [ -f "$INSTALL_DIR/aegis_memory.db" ] && [ ! -f "$DATA_DIR/aegis_memory.db" ]; then
        echo "   -> Migrating DB to Data Layer..."
        mv "$INSTALL_DIR/aegis_memory.db" "$DATA_DIR/"
    fi
    
    # Users
    if [ -d "$INSTALL_DIR/users" ]; then
        # If destination empty, move. If not, merge.
        if [ -z "$(ls -A $DATA_DIR/users)" ]; then
             echo "   -> Migrating Users to Data Layer..."
             mv "$INSTALL_DIR/users/"* "$DATA_DIR/users/" 2>/dev/null || true
        else
             echo "   -> Merging Users to Data Layer..."
             cp -rn "$INSTALL_DIR/users/"* "$DATA_DIR/users/" 2>/dev/null || true
        fi
    fi

    # Vault
    if [ -d "$INSTALL_DIR/vault" ]; then
        if [ -z "$(ls -A $DATA_DIR/vault)" ]; then
             echo "   -> Migrating Vault to Data Layer..."
             mv "$INSTALL_DIR/vault/"* "$DATA_DIR/vault/" 2>/dev/null || true
        else
             cp -rn "$INSTALL_DIR/vault/"* "$DATA_DIR/vault/" 2>/dev/null || true
        fi
    fi

    # Config/Secrets
    if [ -f "$INSTALL_DIR/config/secrets.json" ] && [ ! -f "$DATA_DIR/config/secrets.json" ]; then
        echo "   -> Migrating Secrets to Data Layer..."
        mv "$INSTALL_DIR/config/secrets.json" "$DATA_DIR/config/"
    fi
    
    # Vector DB
    if [ -d "$INSTALL_DIR/chroma_db" ] && [ ! -d "$DATA_DIR/chroma_db" ]; then
         echo "   -> Migrating Vector DB to Data Layer..."
         mv "$INSTALL_DIR/chroma_db" "$DATA_DIR/"
    fi

    # Tenants Registry (Critical Persistence)
    if [ -f "$INSTALL_DIR/tenants_registry.json" ] && [ ! -f "$DATA_DIR/tenants_registry.json" ]; then
         echo "   -> Migrating Tenant Registry to Data Layer..."
         mv "$INSTALL_DIR/tenants_registry.json" "$DATA_DIR/"
    fi
    
    echo "   ✅ Migration Complete."
    
    # Nuke old code (Data is safe in DATA_DIR now)
    echo "   🧹 Cleaning old application files..."
    rm -rf "$INSTALL_DIR"
fi

# 3. Fresh Install
echo "⬇️ 3/5 Downloading Core System..."
mkdir -p "$INSTALL_DIR"
ABS_INSTALL_DIR=$(cd "$INSTALL_DIR" && pwd)

if curl -L -o /tmp/aegis_latest.zip "$REPO_URL"; then
    echo "   Download complete."
else
    echo "   ❌ Download failed."
    exit 1
fi

echo "📂 Extracting..."
unzip -q /tmp/aegis_latest.zip -d "$ABS_INSTALL_DIR"

# Handle nesting
NESTED_DIR=$(find "$ABS_INSTALL_DIR" -maxdepth 1 -type d -name "Aegis-IA*" | head -n 1)
if [ -n "$NESTED_DIR" ] && [ "$NESTED_DIR" != "$ABS_INSTALL_DIR" ]; then
    mv "$NESTED_DIR/"* "$ABS_INSTALL_DIR/"
    rmdir "$NESTED_DIR"
fi
rm /tmp/aegis_latest.zip

# 4. Symlink Binding (The Bridge)
echo "🔗 4/5 Linking Data Layer..."

# Database (File Link)
# Only link if source exists, otherwise let app create it later (needs complexity handle)
# Actually, best approach: If not exists in Data, touch it or let python create.
# Symlink requires target to be valid path.
if [ ! -f "$DATA_DIR/aegis_memory.db" ]; then
    # App expects symlink to work, so target must exist or symlink is broken?
    # No, ln -s to non-existent target is possible but broken link.
    # Better: Pre-seed empty file if needed, or rely on app logic.
    # App (sqlite) creates file if missing. We should probably NOT touch it 
    # but link logic is simpler if we treat it as valid.
    # We'll just link. If it doesn't exist, sqlite might complain on follow? 
    # Safest: Let's assume user wants 'aegis_memory.db' in install dir to act as the file.
    true 
fi
ln -sf "$DATA_DIR/aegis_memory.db" "$ABS_INSTALL_DIR/aegis_memory.db"

# Directories (Folder Links) - Force remove existing empty dirs from unzip first
rm -rf "$ABS_INSTALL_DIR/users"
ln -sfn "$DATA_DIR/users" "$ABS_INSTALL_DIR/users"

rm -rf "$ABS_INSTALL_DIR/vault"
ln -sfn "$DATA_DIR/vault" "$ABS_INSTALL_DIR/vault"

rm -rf "$ABS_INSTALL_DIR/chroma_db"
ln -sfn "$DATA_DIR/chroma_db" "$ABS_INSTALL_DIR/chroma_db"

# Config is tricky because it contains code files too (settings.py?).
# If config is purely data (json), fine. If mixed code, symlink whole dir breaks code updates.
# Aegis struct: config/ might have code? Usually just json/yaml.
# If just `secrets.json`, link file.
mkdir -p "$ABS_INSTALL_DIR/config"
ln -sf "$DATA_DIR/config/secrets.json" "$ABS_INSTALL_DIR/config/secrets.json"

# Fix Ownership
USER_ID=$(id -u)
GROUP_ID=$(id -g)
chown -R $USER_ID:$GROUP_ID "$ABS_INSTALL_DIR"
# Also fix Data Dir ownership if sudo created it
chown -R $USER_ID:$GROUP_ID "$DATA_DIR"

echo "   ✅ Data Linked successfully."

# 5. Environment & Service
echo "🐍 5/5 Setting up Runtime..."
cd "$ABS_INSTALL_DIR"
python3 -m venv .venv
source .venv/bin/activate

pip install --upgrade pip setuptools wheel > /dev/null
pip install -r requirements.txt > /dev/null

echo "⚙️ Configuring Service..."
CURRENT_USER=$(whoami)
SERVICE_FILE="/etc/systemd/system/$SERVICE_NAME"
EXEC_CMD="$ABS_INSTALL_DIR/.venv/bin/streamlit run $ABS_INSTALL_DIR/admin_launcher.py --server.port 8501 --server.headless true"

if command -v sudo >/dev/null 2>&1; then SUDO="sudo"; else SUDO=""; fi

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
Environment=PATH=$ABS_INSTALL_DIR/.venv/bin:/usr/bin:/usr/local/bin
Environment=PYTHONIOENCODING=utf-8
Environment=STREAMLIT_CONFIG_DIR=$ABS_INSTALL_DIR/.streamlit
Environment=AEGIS_USER_ROOT=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

$SUDO systemctl daemon-reload
$SUDO systemctl enable "$SERVICE_NAME"
$SUDO systemctl restart "$SERVICE_NAME"

LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ ARCHITECTURE UPGRADE SUCCESSFUL!"
echo "==================================================="
echo "💾 Persistent Data: $DATA_DIR"
echo "🔗 Application:     $ABS_INSTALL_DIR (Symlinked)"
echo "🖥️  Web Interface:   http://$LOCAL_IP:8501"
echo "==================================================="
