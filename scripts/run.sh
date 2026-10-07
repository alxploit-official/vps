#!/bin/sh

. /common.sh

HOSTNAME="PanelDino"
HISTORY_FILE="${HOME}/.custom_shell_history"
MAX_HISTORY=1000
GUI_CONFIG_FILE="$HOME/.vnc/gui_config.yml"
VNC_DIR="$HOME/.vnc"

# ============================================
# INITIAL SETUP
# ============================================
if [ ! -e "/.installed" ]; then
    [ -f "/rootfs.tar.xz" ] && rm -f "/rootfs.tar.xz"
    [ -f "/rootfs.tar.gz" ] && rm -f "/rootfs.tar.gz"
    rm -rf /tmp/sbin
    printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > /etc/resolv.conf
    touch "/.installed"
fi

if [ ! -e "/autorun.sh" ]; then
    touch /autorun.sh
    chmod +x /autorun.sh
fi

# ============================================
# HELPER FUNCTIONS
# ============================================
cleanup() {
    log "INFO" "Session ended. Goodbye!" "$GREEN"
    exit 0
}

get_formatted_dir() {
    current_dir="$PWD"
    case "$current_dir" in
        "$HOME"*) printf "~${current_dir#$HOME}" ;;
        *) printf "$current_dir" ;;
    esac
}

print_prompt() {
    user="$1"
    printf "\n${GREEN}${user}@${HOSTNAME}${NC}:${RED}$(get_formatted_dir)${NC}# "
}

save_to_history() {
    cmd="$1"
    if [ -n "$cmd" ] && [ "$cmd" != "exit" ]; then
        printf "$cmd\n" >> "$HISTORY_FILE"
        [ -f "$HISTORY_FILE" ] && tail -n "$MAX_HISTORY" "$HISTORY_FILE" > "$HISTORY_FILE.tmp" && mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
    fi
}

# ============================================
# GUI / VNC / noVNC
# ============================================
install_gui() {
    if [ -f "$GUI_CONFIG_FILE" ]; then
        log "WARNING" "GUI already installed." "$YELLOW"
        return 0
    fi
    if [ -f "/vnc_install.sh" ]; then
        sh /vnc_install.sh install
    else
        log "ERROR" "vnc_install.sh not found." "$RED"
        return 1
    fi
}

reinstall_gui() {
    rm -f "$GUI_CONFIG_FILE"
    rm -rf "$VNC_DIR"
    rm -f "$HOME/.xsession"
    install_gui
}

parse_gui_config() {
    if [ -f "$GUI_CONFIG_FILE" ]; then
        GUI_SERVER_TYPE="vnc"
        GUI_DE_STARTUP=$(grep -E '^\s*startup_command:' "$GUI_CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')
        GUI_DE=$(grep -E '^\s*environment:' "$GUI_CONFIG_FILE" | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')
        VNC_PORT=$(grep -A5 '^vnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*port:' | head -1 | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')
        VNC_PASSWORD=$(grep -A5 '^vnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*password:' | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')
        NOVNC_PORT=$(grep -A3 '^novnc:' "$GUI_CONFIG_FILE" | grep -E '^\s*port:' | sed 's/.*: *"\?\([^"]*\)"\?/\1/' | tr -d ' ')

        VNC_PORT="${VNC_PORT:-5901}"
        NOVNC_PORT="${NOVNC_PORT:-${SERVER_PORT:-6080}}"

        [ -z "$GUI_DE_STARTUP" ] && GUI_DE_STARTUP="mate-session"
    fi
}

start_vnc() {
    [ ! -f "$GUI_CONFIG_FILE" ] && { log "ERROR" "GUI not installed." "$RED"; return 1; }

    parse_gui_config

    if pgrep -x "Xvnc" > /dev/null 2>&1 || pgrep -x "Xtigervnc" > /dev/null 2>&1; then
        log "WARNING" "VNC already running." "$YELLOW"
        return 0
    fi

    log "INFO" "Starting VNC on port $VNC_PORT..." "$YELLOW"

    VNC_DISPLAY_NUM=$((VNC_PORT - 5900))
    [ "$VNC_DISPLAY_NUM" -lt 1 ] && VNC_DISPLAY_NUM=1

    mkdir -p "$VNC_DIR" 2>/dev/null
    mkdir -p /tmp/.X11-unix 2>/dev/null || true

    pkill -f "Xtigervnc.*:$VNC_DISPLAY_NUM" > /dev/null 2>&1 || true
    pkill -f "Xvnc.*:$VNC_DISPLAY_NUM" > /dev/null 2>&1 || true
    sleep 1

    start_desktop_env() {
        export DISPLAY=":$VNC_DISPLAY_NUM"
        export HOME="$HOME"
        export XDG_RUNTIME_DIR="/tmp/runtime-$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR" 2>/dev/null || true
        chmod 700 "$XDG_RUNTIME_DIR" 2>/dev/null || true

        case "$GUI_DE" in
            mate)
                marco &
                sleep 1
                mate-panel 2>/dev/null &
                caja --no-desktop 2>/dev/null &
                ;;
            *)
                command -v openbox > /dev/null 2>&1 && openbox &
                command -v xfwm4   > /dev/null 2>&1 && xfwm4 &
                ;;
        esac
        sleep 2
    }

    VNC_SECURITY="-SecurityTypes None"
    if [ -n "$VNC_PASSWORD" ] && [ "$VNC_PASSWORD" != "" ]; then
        mkdir -p "$HOME/.vnc" 2>/dev/null
        printf "%s\n%s\nn\n" "$VNC_PASSWORD" "$VNC_PASSWORD" | vncpasswd "$HOME/.vnc/passwd" > /dev/null 2>&1
        [ -f "$HOME/.vnc/passwd" ] && VNC_SECURITY="-SecurityTypes VncAuth -PasswordFile $HOME/.vnc/passwd"
    fi

    if command -v Xtigervnc > /dev/null 2>&1; then
        Xtigervnc ":$VNC_DISPLAY_NUM" -geometry 1280x720 -depth 24 -rfbport "$VNC_PORT" $VNC_SECURITY -pn -ac &
        sleep 2
        start_desktop_env
    elif command -v Xvnc > /dev/null 2>&1; then
        Xvnc ":$VNC_DISPLAY_NUM" -geometry 1280x720 -depth 24 -rfbport "$VNC_PORT" $VNC_SECURITY -pn -ac &
        sleep 2
        start_desktop_env
    else
        log "ERROR" "No VNC server found." "$RED"
        return 1
    fi

    if pgrep -f "Xvnc.*:$VNC_DISPLAY_NUM" > /dev/null 2>&1 || pgrep -f "Xtigervnc.*:$VNC_DISPLAY_NUM" > /dev/null 2>&1; then
        log "SUCCESS" "VNC running on port $VNC_PORT" "$GREEN"
    else
        log "ERROR" "VNC failed to start." "$RED"
        return 1
    fi
}

stop_vnc() {
    log "INFO" "Stopping VNC..." "$YELLOW"
    parse_gui_config
    VNC_DISPLAY_NUM=$((VNC_PORT - 5900))
    [ "$VNC_DISPLAY_NUM" -lt 1 ] && VNC_DISPLAY_NUM=1
    command -v vncserver > /dev/null 2>&1 && vncserver -kill ":$VNC_DISPLAY_NUM" > /dev/null 2>&1
    pkill -f "Xvnc" > /dev/null 2>&1
    pkill -f "Xtigervnc" > /dev/null 2>&1
    pkill -f "Xvfb" > /dev/null 2>&1
    log "SUCCESS" "VNC stopped." "$GREEN"
}

start_novnc() {
    [ ! -f "$GUI_CONFIG_FILE" ] && { log "ERROR" "GUI not installed." "$RED"; return 1; }

    parse_gui_config

    if pgrep -f "websockify" > /dev/null 2>&1; then
        log "WARNING" "noVNC already running." "$YELLOW"
        return 0
    fi

    start_vnc

    log "INFO" "Starting noVNC on port $NOVNC_PORT..." "$YELLOW"

    NOVNC_PATH=""
    [ -d "/usr/share/novnc" ] && NOVNC_PATH="/usr/share/novnc"
    [ -d "/usr/share/webapps/novnc" ] && NOVNC_PATH="/usr/share/webapps/novnc"

    if command -v websockify > /dev/null 2>&1; then
        if [ -n "$NOVNC_PATH" ]; then
            websockify --web="$NOVNC_PATH" "$NOVNC_PORT" localhost:"$VNC_PORT" > /tmp/novnc.log 2>&1 &
        else
            websockify "$NOVNC_PORT" localhost:"$VNC_PORT" > /tmp/novnc.log 2>&1 &
        fi
        sleep 2
        log "SUCCESS" "noVNC running on port $NOVNC_PORT" "$GREEN"
        printf "\n${CYAN}Access: http://<node-ip>:$NOVNC_PORT/vnc.html${NC}\n\n"
    else
        log "ERROR" "websockify not found." "$RED"
        return 1
    fi
}

stop_novnc() {
    log "INFO" "Stopping noVNC..." "$YELLOW"
    pkill -f "websockify" > /dev/null 2>&1
    log "SUCCESS" "noVNC stopped." "$GREEN"
}

gui_status() {
    printf "\n${CYAN}GUI Status:${NC}\n\n"
    [ ! -f "$GUI_CONFIG_FILE" ] && { log "INFO" "GUI not installed." "$YELLOW"; return; }
    parse_gui_config
    printf "  Desktop: $GUI_DE_STARTUP\n\n"
    printf "  ${YELLOW}VNC:${NC} "
    if pgrep -f "Xvnc" > /dev/null 2>&1 || pgrep -f "Xtigervnc" > /dev/null 2>&1; then
        printf "${GREEN}Running${NC} (port $VNC_PORT)\n"
    else
        printf "${RED}Stopped${NC}\n"
    fi
    printf "  ${YELLOW}noVNC:${NC} "
    if pgrep -f "websockify" > /dev/null 2>&1; then
        printf "${GREEN}Running${NC} (port $NOVNC_PORT)\n"
    else
        printf "${RED}Stopped${NC}\n"
    fi
    printf "\n"
}

# ============================================
# OTHER UTILITIES
# ============================================
show_system_status() {
    log "INFO" "System Status:" "$GREEN"
    uptime; free -h; df -h
    ps aux --sort=-%mem | head -n 10
}

create_backup() {
    command -v tar > /dev/null 2>&1 || { log "ERROR" "tar not installed." "$RED"; return 1; }
    backup_file="/backup_$(date +%Y%m%d%H%M%S).tar.gz"
    exclude_file="/tmp/exclude-list.txt"
    cat > "$exclude_file" <<EOF
./${backup_file#/}
./proc
./tmp
./dev
./sys
./run
./vps.config
${exclude_file#/}
EOF
    log "INFO" "Backing up..." "$YELLOW"
    (cd / && tar --numeric-owner -czf "$backup_file" -X "$exclude_file" .) > /dev/null 2>&1
    log "SUCCESS" "Backup: $backup_file" "$GREEN"
    rm -f "$exclude_file"
}

restore_backup() {
    backup_file="$1"
    command -v tar > /dev/null 2>&1 || { log "ERROR" "tar not installed." "$RED"; return 1; }
    [ -z "$backup_file" ] && { log "INFO" "Usage: restore <file>" "$YELLOW"; return 1; }
    if [ -f "/$backup_file" ]; then
        log "INFO" "Restoring..." "$YELLOW"
        tar --numeric-owner -xzf "/$backup_file" -C / --exclude="$backup_file" > /dev/null 2>&1
        log "SUCCESS" "Restored from $backup_file" "$GREEN"
    else
        log "ERROR" "Not found: $backup_file" "$RED"
    fi
}

reinstall() {
    log "INFO" "Reinstalling OS..." "$YELLOW"
    find / -mindepth 1 -xdev -delete > /dev/null 2>&1
}

print_banner() { print_main_banner; }
print_help_message() { print_help_banner; }

# ============================================
# COMMAND EXECUTION
# ============================================
execute_command() {
    cmd="$1"
    user="$2"
    save_to_history "$cmd"

    case "$cmd" in
        "clear"|"cls") printf "\033c"; print_prompt "$user"; return 0 ;;
        "exit") cleanup ;;
        "history") [ -f "$HISTORY_FILE" ] && cat "$HISTORY_FILE"; print_prompt "$user"; return 0 ;;
        "reinstall") reinstall; exit 2 ;;
        "sudo"*|"su"*) log "ERROR" "Already root." "$RED"; print_prompt "$user"; return 0 ;;
        "install-gui") install_gui; print_prompt "$user"; return 0 ;;
        "reinstall-gui") reinstall_gui; print_prompt "$user"; return 0 ;;
        "start-vnc") start_vnc; print_prompt "$user"; return 0 ;;
        "stop-vnc") stop_vnc; print_prompt "$user"; return 0 ;;
        "start-novnc") start_novnc; print_prompt "$user"; return 0 ;;
        "stop-novnc") stop_novnc; print_prompt "$user"; return 0 ;;
        "gui-status") gui_status; print_prompt "$user"; return 0 ;;
        "status") show_system_status; print_prompt "$user"; return 0 ;;
        "backup") create_backup; print_prompt "$user"; return 0 ;;
        "restore") log "ERROR" "Usage: restore <file>" "$RED"; print_prompt "$user"; return 0 ;;
        "restore "*) restore_backup "$(echo "$cmd" | cut -d' ' -f2-)"; print_prompt "$user"; return 0 ;;
        "help") print_help_message; print_prompt "$user"; return 0 ;;
        *) eval "$cmd"; print_prompt "$user"; return 0 ;;
    esac
}

run_prompt() {
    user="$1"
    read -r cmd
    execute_command "$cmd" "$user"
    print_prompt "$user"
}

# ============================================
# MAIN ENTRY - FULL AUTO
# ============================================
touch "$HISTORY_FILE"
trap cleanup INT TERM
print_banner
log "INFO" "Type 'help' to view available commands." "$YELLOW"

# === AUTO INSTALL GUI + START noVNC ===
if [ ! -f "$GUI_CONFIG_FILE" ]; then
    log "INFO" "First run: auto-installing MATE + VNC + noVNC..." "$GREEN"
    install_gui

    if [ -f "$GUI_CONFIG_FILE" ]; then
        log "SUCCESS" "GUI installed. Starting noVNC..." "$GREEN"
        start_novnc
    else
        log "ERROR" "GUI install failed." "$RED"
    fi
else
    log "INFO" "GUI already installed. Starting noVNC..." "$GREEN"
    start_novnc
fi

# === MAIN LOOP ===
printf "${GREEN}root@${HOSTNAME}${NC}:${RED}$(get_formatted_dir)${NC}#\n"
sh "/autorun.sh"

while true; do
    run_prompt "user"
done