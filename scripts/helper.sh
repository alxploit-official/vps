#!/bin/sh

# ============================================
# PanelDino - Helper (aman & simpel)
# ============================================

# Pastikan file pendukung ada
if [ ! -f "$HOME/common.sh" ] && [ -f "/common.sh" ]; then
    cp /common.sh "$HOME/common.sh"
    chmod +x "$HOME/common.sh"
fi

if [ ! -f "$HOME/run.sh" ] && [ -f "/run.sh" ]; then
    cp /run.sh "$HOME/run.sh"
    chmod +x "$HOME/run.sh"
fi

# Parse port dari vps.config (kalau ada)
PORT_ARGS=""
CONFIG_FILE="$HOME/vps.config"

if [ -f "$CONFIG_FILE" ]; then
    while read -r LINE; do
        # Skip baris kosong atau komentar
        case "$LINE" in
            ""|\#*) continue ;;
        esac

        # Ambil key dan value
        KEY=$(echo "$LINE" | cut -d'=' -f1 | tr -d ' \t\r\n')
        VALUE=$(echo "$LINE" | cut -d'=' -f2- | tr -d ' \t\r\n')

        # Skip internalip
        if [ "$KEY" = "internalip" ]; then
            continue
        fi

        # Cek port
        case "$KEY" in
            port[0-9]*)
                if [ -n "$VALUE" ]; then
                    # Validasi angka
                    NUM=$(echo "$VALUE" | tr -d '0-9')
                    if [ -z "$NUM" ]; then
                        if [ "$VALUE" -ge 1 ] && [ "$VALUE" -le 65535 ]; then
                            PORT_ARGS="$PORT_ARGS -p $VALUE:$VALUE"
                        fi
                    fi
                fi
                ;;
        esac
    done < "$CONFIG_FILE"
fi

# Jalankan proot masuk ke Ubuntu
exec /usr/local/bin/proot \
    --rootfs="$HOME" \
    -0 \
    -w "$HOME" \
    -b /dev \
    -b /sys \
    -b /proc \
    $PORT_ARGS \
    --kill-on-exit \
    /bin/sh /run.sh
