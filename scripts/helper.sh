#!/bin/sh
cp /common.sh "$HOME/common.sh" 2>/dev/null
cp /run.sh "$HOME/run.sh" 2>/dev/null
chmod +x "$HOME/common.sh" "$HOME/run.sh" 2>/dev/null
exec /usr/local/bin/proot \
    --rootfs="$HOME" \
    -0 \
    -w "$HOME" \
    -b /dev \
    -b /sys \
    -b /proc \
    --kill-on-exit \
    /bin/sh /run.sh
