#!/bin/bash

# Fedora/RHEL/CentOS dependency installation

install_dependencies() {
    log_info "Installing dependencies for Fedora/RHEL/CentOS..."

    # Update package cache
    safe_install "dnf check-update" || true

    # Basic tools
    local basic_packages="curl wget git"
    log_info "Installing basic tools..."
    safe_install "dnf install -y" $basic_packages

    # Compression tools
    if ! command_exists 7z; then
        log_info "Installing 7zip..."
        safe_install "dnf install -y" p7zip p7zip-plugins
    fi

    # Node.js and npm
    if ! command_exists node || ! command_exists npm; then
        log_info "Installing Node.js and npm..."
        safe_install "dnf install -y" nodejs npm
    fi

    # Rust toolchain
    if ! command_exists rustc; then
        log_info "Installing Rust toolchain..."
        safe_install "dnf install -y" rust cargo
    fi

    # Icon extraction tools
    if ! command_exists wrestool || ! command_exists icotool; then
        log_info "Installing icon extraction tools..."
        safe_install "dnf install -y" icoutils
    fi

    # ImageMagick for icon processing
    if ! command_exists convert; then
        log_info "Installing ImageMagick..."
        safe_install "dnf install -y" ImageMagick
    fi

    # Development tools
    if ! rpm -q gcc &>/dev/null; then
        log_info "Installing development tools..."
        safe_install "dnf groupinstall -y" "Development Tools"
    fi

    # Python3 (often needed for node modules)
    if ! command_exists python3; then
        log_info "Installing Python3..."
        safe_install "dnf install -y" python3 python3-pip
    fi

    # Install global npm packages
    install_npm_packages

    # Install AppImageTool
    install_appimagetool
}

install_npm_packages() {
    log_info "Installing global npm packages..."

    if ! command_exists asar; then
        log_info "Installing asar..."
        npm install -g asar
    fi

    if ! command_exists electron; then
        log_info "Installing electron..."
        npm install -g electron
    fi
}

install_appimagetool() {
    if ! command_exists appimagetool; then
        log_info "Installing AppImageTool..."
        local temp_file=$(mktemp)
        download_with_retry "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" "$temp_file"
        chmod +x "$temp_file"
        safe_install "mv" "$temp_file" "/usr/local/bin/appimagetool"
    fi
}