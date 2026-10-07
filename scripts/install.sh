#!/bin/sh

. /common.sh

# ============================================
# Configuration
# ============================================
ROOTFS_DIR="/home/container"
BASE_URL="https://images.linuxcontainers.org/images"

export PATH="$PATH:~/.local/usr/bin"

# ============================================
# Helper Functions
# ============================================
error_exit() {
    log "ERROR" "$1" "$RED"
    exit 1
}

cleanup() {
    log "INFO" "Cleaning up temporary files..." "$YELLOW"
    rm -f "$ROOTFS_DIR/rootfs.tar.xz"
    rm -rf /tmp/sbin
}

check_network() {
    if ! curl -s --head "$BASE_URL" >/dev/null; then
        error_exit "Unable to connect to $BASE_URL."
    fi
}

# ============================================
# Install Function
# ============================================
install() {
    distro_name="$1"
    pretty_name="$2"

    log "INFO" "Preparing to install $pretty_name..." "$GREEN"

    url_path="$BASE_URL/$distro_name/"

    image_names=$(curl -s "$url_path" | grep 'href="' | grep -o '"[^/"]*/"' | tr -d '"/' | grep -v '^\.\.$') ||
    error_exit "Failed to fetch versions for $pretty_name"

    temp_file="/tmp/install_versions.$$"
    echo "$image_names" > "$temp_file"

    # Pilih versi pertama (terbaru)
    selected_version=$(head -n 1 "$temp_file")
    rm -f "$temp_file"

    if [ -z "$selected_version" ]; then
        error_exit "No version found for $pretty_name"
    fi

    log "INFO" "Selected version: $selected_version" "$GREEN"

    download_and_extract_rootfs "$distro_name" "$selected_version"
}

# ============================================
# Download & Extract Rootfs
# ============================================
download_and_extract_rootfs() {
    distro_name="$1"
    version="$2"

    arch_url="${BASE_URL}/${distro_name}/${version}/"
    url="${BASE_URL}/${distro_name}/${version}/${ARCH_ALT}/default/"

    if ! curl -s "$arch_url" | grep -q "$ARCH_ALT"; then
        error_exit "This distro doesn't support $ARCH_ALT."
    fi

    latest_version=$(curl -s "$url" | grep 'href="' | grep -o '[0-9]\{8\}_[0-9]\{2\}:[0-9]\{2\}/' | sort -r | head -n 1)

    if [ -z "$latest_version" ]; then
        log "WARNING" "Could not detect version subfolder, using default path" "$YELLOW"
        latest_version=""
    fi

    log "INFO" "Downloading rootfs..." "$GREEN"
    mkdir -p "$ROOTFS_DIR"

    if ! curl -Ls "${url}${latest_version}rootfs.tar.xz" -o "$ROOTFS_DIR/rootfs.tar.xz"; then
        error_exit "Failed to download rootfs"
    fi

    # Cek ukuran file
    file_size=$(wc -c < "$ROOTFS_DIR/rootfs.tar.xz" 2>/dev/null || echo 0)
    if [ "$file_size" -lt 1000000 ]; then
        error_exit "Downloaded rootfs too small ($file_size bytes)"
    fi

    log "INFO" "Extracting rootfs..." "$GREEN"
    if ! tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR"; then
        error_exit "Failed to extract rootfs"
    fi

    # ============================================
    # FIX: Prepare /dev, /proc, /sys, /tmp
    # ============================================
    log "INFO" "Preparing /dev entries..." "$GREEN"

    mkdir -p "$ROOTFS_DIR/dev" 2>/dev/null
    mkdir -p "$ROOTFS_DIR/proc" 2>/dev/null
    mkdir -p "$ROOTFS_DIR/sys" 2>/dev/null
    mkdir -p "$ROOTFS_DIR/tmp" 2>/dev/null
    mkdir -p "$ROOTFS_DIR/home/container" 2>/dev/null

    # Buat /dev entries sebagai regular file (PRoot butuh ini)
    for dev in null zero random urandom tty full; do
        if [ ! -e "$ROOTFS_DIR/dev/$dev" ]; then
            touch "$ROOTFS_DIR/dev/$dev" 2>/dev/null
        fi
        chmod 666 "$ROOTFS_DIR/dev/$dev" 2>/dev/null
    done

    # Permission untuk /tmp
    chmod 1777 "$ROOTFS_DIR/tmp" 2>/dev/null

    # Bersihkan resolv.conf biar bisa di-regenerate
    rm -f "$ROOTFS_DIR/etc/resolv.conf"
}

# ============================================
# MAIN - AUTO INSTALL UBUNTU
# ============================================
ARCH_ALT=$(detect_architecture)
check_network

log "INFO" "Auto-installing Ubuntu..." "$GREEN"
install "ubuntu" "Ubuntu"

# Copy file pendukung ke rootfs
cp /common.sh /run.sh "$ROOTFS_DIR"
chmod +x "$ROOTFS_DIR/common.sh" "$ROOTFS_DIR/run.sh"

if [ -f "/vnc_install.sh" ]; then
    cp /vnc_install.sh "$ROOTFS_DIR"
    chmod +x "$ROOTFS_DIR/vnc_install.sh"
fi

# Trap cleanup saat exit
trap cleanup EXIT
