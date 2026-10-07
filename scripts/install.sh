#!/bin/sh

. /common.sh

ROOTFS_DIR="/home/container"
BASE_URL="https://images.linuxcontainers.org/images"

export PATH="$PATH:~/.local/usr/bin"

error_exit() {
    log "ERROR" "$1" "$RED"
    exit 1
}

ARCH=$(uname -m)

check_network() {
    if ! curl -s --head "$BASE_URL" >/dev/null; then
        error_exit "Unable to connect to $BASE_URL."
    fi
}

cleanup() {
    log "INFO" "Cleaning up temporary files..." "$YELLOW"
    rm -f "$ROOTFS_DIR/rootfs.tar.xz"
    rm -rf /tmp/sbin
}

install() {
    distro_name="$1"
    pretty_name="$2"
    is_custom="$3"

    [ -z "$is_custom" ] && is_custom="false"

    log "INFO" "Preparing to install $pretty_name..." "$GREEN"

    url_path="$BASE_URL/$distro_name/"

    image_names=$(curl -s "$url_path" | grep 'href="' | grep -o '"[^/"]*/"' | tr -d '"/' | grep -v '^\.\.$') ||
    error_exit "Failed to fetch available versions for $pretty_name"

    temp_file="/tmp/install_versions.$$"
    echo "$image_names" > "$temp_file"

    # Langsung pilih versi pertama (terbaru)
    selected_version=$(head -n 1 "$temp_file")
    rm -f "$temp_file"

    if [ -z "$selected_version" ]; then
        error_exit "No version found for $pretty_name"
    fi

    log "INFO" "Selected version: $selected_version" "$GREEN"

    download_and_extract_rootfs "$distro_name" "$selected_version" "$is_custom"
}

download_and_extract_rootfs() {
    distro_name="$1"
    version="$2"
    is_custom="$3"

    arch_url="${BASE_URL}/${distro_name}/${version}/"
    url="${BASE_URL}/${distro_name}/${version}/${ARCH_ALT}/default/"

    if ! curl -s "$arch_url" | grep -q "$ARCH_ALT"; then
        error_exit "This distro doesn't support $ARCH_ALT."
    fi

    latest_version=$(curl -s "$url" | grep 'href="' | grep -o '[0-9]\{8\}_[0-9]\{2\}:[0-9]\{2\}/' | sort -r | head -n 1)

    # Fallback: kalau kosong, pakai path default
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
        error_exit "Downloaded rootfs too small ($file_size bytes), likely failed"
    fi

    log "INFO" "Extracting rootfs..." "$GREEN"
    if ! tar -xf "$ROOTFS_DIR/rootfs.tar.xz" -C "$ROOTFS_DIR"; then
        error_exit "Failed to extract rootfs"
    fi

    rm -f "$ROOTFS_DIR/etc/resolv.conf"
    mkdir -p "$ROOTFS_DIR/home/container/"
}

# ============================================
# AUTO INSTALL UBUNTU
# ============================================
ARCH_ALT=$(detect_architecture)
check_network

log "INFO" "Auto-installing Ubuntu..." "$GREEN"
install "ubuntu" "Ubuntu" "false"

cp /common.sh /run.sh "$ROOTFS_DIR"
chmod +x "$ROOTFS_DIR/common.sh" "$ROOTFS_DIR/run.sh"

if [ -f "/vnc_install.sh" ]; then
    cp /vnc_install.sh "$ROOTFS_DIR"
    chmod +x "$ROOTFS_DIR/vnc_install.sh"
fi

trap cleanup EXIT
