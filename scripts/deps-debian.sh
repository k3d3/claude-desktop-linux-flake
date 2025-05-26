#!/bin/bash

# Ubuntu/Debian dependency installation

install_dependencies() {
    log_info "Installing dependencies for Ubuntu/Debian..."

    # Update package cache
    log_info "Updating package cache..."
    safe_install "apt update"

    # Basic tools
    local basic_packages="curl wget git build-essential"
    log_info "Installing basic tools..."
    safe_install "apt install -y" $basic_packages

    # Compression tools
    if ! command_exists 7z; then
        log_info "Installing 7zip..."
        safe_install "apt install -y" p7zip-full p7zip-rar
    fi

    # Node.js and npm (install from NodeSource for latest version)
    if ! command_exists node || ! command_exists npm; then
        install_nodejs_debian
    fi

    # Rust toolchain
    if ! command_exists rustc; then
        log_info "Installing Rust toolchain..."
        # Install rustup first, then use it to install rust
        if ! command_exists rustup; then
            safe_install "apt install -y" rustup
            rustup install stable
            rustup default stable
        else
            safe_install "apt install -y" rust-all
        fi
    fi

    # Icon extraction tools
    if ! command_exists wrestool || ! command_exists icotool; then
        log_info "Installing icon extraction tools..."
        safe_install "apt install -y" icoutils
    fi

    # ImageMagick for icon processing
    if ! command_exists convert; then
        log_info "Installing ImageMagick..."
        safe_install "apt install -y" imagemagick
    fi

    # Python3 (usually pre-installed but ensure pip is available)
    if ! command_exists python3; then
        log_info "Installing Python3..."
        safe_install "apt install -y" python3 python3-pip
    elif ! command_exists pip3; then
        safe_install "apt install -y" python3-pip
    fi

    # Additional build dependencies
    log_info "Installing additional build dependencies..."
    safe_install "apt install -y" pkg-config libssl-dev

    # Install global npm packages
    install_npm_packages

    # Install AppImageTool
    install_appimagetool
}

install_nodejs_debian() {
    log_info "Installing Node.js from NodeSource repository..."

    # Add NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    safe_install "apt install -y" nodejs

    # Verify installation
    if command_exists node && command_exists npm; then
        log_success "Node.js $(node --version) and npm $(npm --version) installed successfully"
    else
        log_warning "NodeSource installation failed, trying distribution packages..."
        safe_install "apt install -y" nodejs npm
    fi
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