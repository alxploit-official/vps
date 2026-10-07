#!/bin/sh

if [ -f "/common.sh" ]; then
    . /common.sh
elif [ -f "$HOME/common.sh" ]; then
    . "$HOME/common.sh"
fi

VNC_DIR="$HOME/.vnc"
GUI_CONFIG_FILE="$VNC_DIR/gui_config.yml"

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

install_mate_debian() {
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        mate-desktop-environment-core \
        mate-terminal \
        dbus-x11 x11-xserver-utils xfonts-base \
        >&2
    echo "mate-session"
}

install_desktop_environment() {
    distro="$1"

    log "INFO" "Installing MATE desktop..." "$YELLOW" >&2

    de_startup=""
    case "$distro" in
        "debian"|"ubuntu"|"linuxmint"|"kali"|"devuan")
            apt-get update -qq >&2
            de_startup=$(install_mate_debian)
            ;;
        *)
            log "ERROR" "Unsupported distro: $distro" "$RED" >&2
            return 1
            ;;
    esac

    if ! command -v "$de_startup" > /dev/null 2>&1; then
        log "ERROR" "MATE startup not found" "$RED" >&2
        return 1
    fi

    log "SUCCESS" "MATE installed ($de_startup)" "$GREEN" >&2
    echo "$de_startup"
    return 0
}

install_vnc_server() {
    distro="$1"

    log "INFO" "Installing VNC + noVNC..." "$YELLOW"

    case "$distro" in
        "debian"|"ubuntu"|"linuxmint"|"kali"|"devuan")
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                tigervnc-standalone-server tigervnc-common \
                > /dev/null 2>&1
            DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
                novnc websockify \
                > /dev/null 2>&1
            ;;
    esac
}

setup_vnc() {
    de_startup="$1"
    vnc_port="$2"

    mkdir -p "$VNC_DIR"

    cat > "$VNC_DIR/xstartup" << 'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR

[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources

XSTARTUP

    echo "exec $de_startup" >> "$VNC_DIR/xstartup"
    chmod +x "$VNC_DIR/xstartup"

    cat > "$VNC_DIR/config" << EOF
geometry=1280x720
depth=24
localhost=no
alwaysshared
SecurityTypes=None
EOF

    rm -f "$VNC_DIR/passwd" 2>/dev/null
    log "SUCCESS" "VNC configured on port $vnc_port (no auth)" "$GREEN"
}

save_config() {
    de="$1"
    vnc_port="$2"
    novnc_port="$3"
    de_startup="$4"

    mkdir -p "$VNC_DIR"

    cat > "$GUI_CONFIG_FILE" << EOF
desktop:
  environment: "$de"
  startup_command: "$de_startup"

vnc:
  port: "$vnc_port"
  auth: none
  resolution: "1280x720"
  depth: "24"

novnc:
  enable: true
  port: "$novnc_port"
EOF

    log "INFO" "Config saved to $GUI_CONFIG_FILE" "$YELLOW"
}

main() {
    distro=$(detect_distro)
    log "INFO" "Detected: $distro" "$GREEN"

    de="mate"
    vnc_port="5901"

    if [ -n "$SERVER_PORT" ]; then
        novnc_port="$SERVER_PORT"
        log "INFO" "noVNC port (Pterodactyl): $novnc_port" "$CYAN"
    else
        novnc_port="6080"
        log "WARNING" "SERVER_PORT not set, fallback: $novnc_port" "$YELLOW"
    fi

    log "INFO" "Setup: MATE + VNC:$vnc_port + noVNC:$novnc_port" "$CYAN"

    if ! de_startup=$(install_desktop_environment "$distro") || [ -z "$de_startup" ]; then
        log "ERROR" "Failed to install MATE" "$RED"
        return 1
    fi

    install_vnc_server "$distro"
    setup_vnc "$de_startup" "$vnc_port"
    save_config "$de" "$vnc_port" "$novnc_port" "$de_startup"

    log "SUCCESS" "MATE + VNC + noVNC installed!" "$GREEN"
    return 0
}

main
