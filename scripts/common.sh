#!/bin/sh

PURPLE='\033[0;35m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

log() {
    level=$1
    message=$2
    color=$3
    [ -z "$color" ] && color="$NC"
    printf "${color}[$level]${NC} $message\n"
}

detect_architecture() {
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        riscv64) echo "riscv64" ;;
        *)
            log "ERROR" "Unsupported CPU architecture: $ARCH" "$RED" >&2
            return 1
            ;;
    esac
}

print_main_banner() {
    printf "\033c"
    printf "${CYAN}=============================================${NC}\n"
    printf "${CYAN}     ${PURPLE}${BOLD}VPS By PanelDino Hosting${NC}\n"
    printf "${CYAN}=============================================${NC}\n"
    printf "${GREEN}   Lightweight - Fast - Reliable${NC}\n"
    printf "${DIM}   (c) $(date +%Y) PanelDino Hosting${NC}\n"
    printf "${CYAN}=============================================${NC}\n"
    printf "\n"
}

print_help_banner() {
    printf "\n${CYAN}=============================================${NC}\n"
    printf "${CYAN}     ${BOLD}${WHITE}PanelDino - Available Commands${NC}\n"
    printf "${CYAN}=============================================${NC}\n\n"

    printf "${BOLD}${YELLOW} General:${NC}\n"
    printf "  ${YELLOW}clear, cls${NC}       - Clear screen\n"
    printf "  ${YELLOW}exit${NC}             - Shutdown container\n"
    printf "  ${YELLOW}history${NC}          - Show command history\n"
    printf "  ${YELLOW}reinstall${NC}        - Reinstall OS\n"
    printf "  ${YELLOW}install-ssh${NC}      - Install SSH server\n"
    printf "  ${YELLOW}status${NC}           - Show system status\n"
    printf "  ${YELLOW}backup${NC}           - Create system backup\n"
    printf "  ${YELLOW}restore <file>${NC}   - Restore from backup\n"
    printf "  ${YELLOW}help${NC}             - Show this help\n\n"

    printf "${BOLD}${YELLOW} GUI / Remote Desktop:${NC}\n"
    printf "  ${YELLOW}install-gui${NC}      - Install desktop + VNC\n"
    printf "  ${YELLOW}start-vnc${NC}        - Start VNC server\n"
    printf "  ${YELLOW}stop-vnc${NC}         - Stop VNC server\n"
    printf "  ${YELLOW}start-novnc${NC}      - Start noVNC (browser)\n"
    printf "  ${YELLOW}stop-novnc${NC}       - Stop noVNC\n"
    printf "  ${YELLOW}gui-status${NC}       - Show GUI status\n\n"

    printf "${DIM} Tip: type any command to get started${NC}\n"
    printf "${CYAN}=============================================${NC}\n\n"
}