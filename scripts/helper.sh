#!/bin/sh

# ============================================
# PanelDino-HOSTING - Helper
# ============================================

# Copy file pendukung ke HOME kalau belum ada
cp /common.sh "$HOME/common.sh" 2>/dev/null
cp /run.sh "$HOME/run.sh" 2>/dev/null
chmod +x "$HOME/common.sh" "$HOME/run.sh" 2>/dev/null

# Pastikan /dev entries ada di rootfs (biar PRoot gak error)
mkdir -p "$HOME/dev" "$HOME/proc" "$HOME/sys" "$HOME/tmp" 2>/dev/null
for dev in null zero random urandom tty full; do
    [ ! -e "$HOME/dev/$dev" ] && touch "$HOME/dev/$dev" 2>/dev/null
    chmod 666 "$HOME/dev/$dev" 2>/dev/null
done
chmod 1777 "$HOME/tmp" 2>/dev/null

# Jalankan PRoot masuk ke Ubuntu
exec /usr/local/bin/proot \
    --rootfs="$HOME" \
    -0 \
    -w "$HOME" \
    -b /dev \
    -b /dev/null \
    -b /dev/zero \
    -b /dev/random \
    -b /dev/urandom \
    -b /dev/tty \
    -b /sys \
    -b /proc \
    --kill-on-exit \
    /bin/sh /run.sh
