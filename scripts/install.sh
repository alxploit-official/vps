#!/bin/sh

# Source common functions and variables
. /common.sh

# Configuration variables
ROOTFS_DIR="/home/container"
BASE_URL="https://images.linuxcontainers.org/images"
DISTRO_MAP_URL="https://distromap.ysdragon.tech"

# Add to PATH
export PATH="$PATH:~/.local/usr/bin"

# Error handling function
error_exit() {
    log "ERROR" "$1" "$RED"
    exit 1
}

# Detect the machine architecture.
ARCH=$(uname -m)

# Verify network connectivity
check_network() {
    if ! curl -s --head "$BASE_URL" >/dev/null; then
        error_exit "Unable to connect to $BASE_URL. Please check your internet connection."
    fi
}

# Function to cleanup temporary files
cleanup() {
    log "INFO" "Cleaning up temporary files..." "$YELLOW"
    rm -f "$ROOTFS_DIR/rootfs.tar.xz"
    rm -rf /tmp/sbin
}

# Function to get version label from distromap
get_label() {
    local distro="$1"
    local version="$2"
    local response
    response=$(curl -s "$DISTRO_MAP_URL/distro/$distro/$version")
    if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
        echo "$version"
    else
        echo "$response" | jq -r '.label'
    fi
}

# Function to install a specific distro
install() {
    distro_name="$1"
    pretty_name="$2"
    is_custom="$3"
    
    if [ -z "$is_custom" ]; then
        is_custom="false"
    fi
    
    log "INFO" "Preparing to install $pretty_name..." "$GREEN"
    
    if [ "$is_custom" = "true" ]; then
        url_path="$BASE_URL/$distro_name/current/$ARCH_ALT/"
    else
        url_path="$BASE_URL/$distro_name/"
    fi
    
    image_names=$(curl -s "$url_path" | grep 'href="' | grep -o '"[^/"]*/"' | tr -d '"/' | grep -v '^\.\.$') ||
    error_exit "Failed to fetch available versions for $pretty_name"
    
    versions=""
    counter=1
    
    temp_file="/tmp/install_versions.$$"
    echo "$image_names" > "$temp_file"
    
    version_count=$(grep -c . "$temp_file")
    
    # === MODIFIKASI: selalu pilih versi terbaru (bukan tanya user) ===
    selected_version=$(head -n 1 "$temp_file")
    rm -f "$temp_file"

    selected_label=$(get_label "$distro_name" "$selected_version")
    log "INFO" "Selected version: $selected_label" "$GREEN"
    
    download_and_extract_rootfs "$distro_name" "$selected_version" "$is_custom"
}

# Function to install custom distribution from URL
install_custom() {
    pretty_name="$1"
    url="$2"
    
    log "INFO" "Installing $pretty_name..." "$GREEN"
    
    mkdir -p "$ROOTFS_DIR"
    
    file_name=$(basename "$url")
    
    if ! curl -Ls "$url" -o "$ROOTFS_DIR/$file_name"; then
        error_exit "Failed to download $pretty_name rootfs"
    fi
    
    if ! tar -xf "$ROOTFS_DIR/$file_name" -C "$ROOTFS_DIR"; then
        error_exit "Failed to extract $pretty_name rootfs"
    fi
    
    mkdir -p "$ROOTFS_DIR/home/container/"
    rm -f "$ROOTFS_DIR/$file_name"
}

chimera_handler() {
    base_url="https://repo.chimera-linux.org/live/latest/"
    
    latest_file=$(curl -s "$base_url" | grep -o "chimera-linux-$ARCH-ROOTFS-[0-9]\{8\}-bootstrap\.tar\.gz" | sort -V | tail -n 1) ||
    error_exit "Failed to fetch Chimera Linux version"
    
    if [ -n "$latest_file" ]; then
        date=$(echo "$latest_file" | grep -o '[0-9]\{8\}')
        chimera_url="${base_url}chimera-linux-$ARCH-ROOTFS-$date-bootstrap.tar.gz"
        install_custom "Chimera Linux" "$chimera_url"
    else
        error_exit "No suitable Chimera Linux version found"
    fi
}

# Function to download and extract rootfs
download_and_extract_rootfs() {
    distro_name="$1"
    version="$2"
    is_custom="$3"
    
    if [ "$is_custom" = "true" ]; then
        arch_url="${BASE_URL}/${distro_name}/current/"
        url="${BASE_URL}/${distro_name}/current/${ARCH_ALT}/${version}/"
    else
        arch_url="${BASE_URL}/${distro_name}/${version}/"
        url="${BASE_URL}/${distro_name}/${version}/${ARCH_ALT}/default/"
    fi
    
    if ! curl -s "$arch_url" | grep -q "$ARCH_ALT"; then
        error_exit "This distro doesn't support $ARCH_ALT. Exiting...."
        cleanup
        exit 1
    fi
    
    latest_version=$(curl -s "$url" | grep 'href="' | grep -o '[0-9]\{8\}_[0-9]\{2\}:[0-9]\{2\}/' | sort -r | head -n 1) ||
    error_exit "Failed to determine latest version"

    log "INFO" "Downloading rootfs..." "$GREEN"
    mkdir -p "$ROOTFS_DIR"

    if ! curl -Ls "${url}${latest_version}rootfs.tar.xz" -o "$ROOTFS_DIR/rootfs.tar.xz"; then
        error_exit "Failed to download rootfs"
    fi

    log "INFO" "Extracting rootfs..." "$GREEN"
    if ! tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR"; then
        error_exit "Failed to extract rootfs"
    fi
    
    rm -f "$ROOTFS_DIR/etc/resolv.conf"
    mkdir -p "$ROOTFS_DIR/home/container/"
}

# Function to handle post-install configuration
post_install_config() {
    distro="$1"
    
    case "$distro" in
        "archlinux")
            log "INFO" "Configuring Arch Linux specific settings..." "$GREEN"
            sed -i '/^#RootDir/s/^#//' "$ROOTFS_DIR/etc/pacman.conf"
            sed -i 's|/var/lib/pacman/|/var/lib/pacman|' "$ROOTFS_DIR/etc/pacman.conf"
            sed -i '/^#DBPath/s/^#//' "$ROOTFS_DIR/etc/pacman.conf"
        ;;
    esac
}

# ============================================
# INITIAL SETUP + BYPASS UBUNTU
# ============================================
ARCH_ALT=$(detect_architecture)
check_network

log "INFO" "Auto-selecting Ubuntu (bypass menu)..." "$GREEN"

# Langsung install Ubuntu, versi terbaru otomatis
install "ubuntu" "Ubuntu" "false"

# Copy run.sh, common.sh, vnc_install.sh
cp /common.sh /run.sh "$ROOTFS_DIR"
chmod +x "$ROOTFS_DIR/common.sh" "$ROOTFS_DIR/run.sh"

if [ -f "/vnc_install.sh" ]; then
    cp /vnc_install.sh "$ROOTFS_DIR"
    chmod +x "$ROOTFS_DIR/vnc_install.sh"
fi

# Trap for cleanup on script exit
trap cleanup EXIT