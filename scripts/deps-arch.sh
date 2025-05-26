#!/bin/bash

# Arch Linux dependency installation

install_dependencies() {
    log_info "Installing dependencies for Arch Linux..."

    # Update package cache
    log_info "Updating package cache..."
    safe_install "pacman -Sy"

    # Basic tools and base-devel group
    log_info "Installing basic tools and build essentials..."
    safe_install "pacman -S --needed --noconfirm" base-devel curl wget git

    # Compression tools
    if ! command_exists 7z; then
        log_info "Installing 7zip..."
        safe_install "pacman -S --needed --noconfirm" p7zip
    fi

    # Node.js and npm
    if ! command_exists node || ! command_exists npm; then
        log_info "Installing Node.js and npm..."
        safe_install "pacman -S --needed --noconfirm" nodejs npm
    fi

    # Rust toolchain
    if ! command_exists rustc; then
        log_info "Installing Rust toolchain..."
        safe_install "pacman -S --needed --noconfirm" rust
    fi

    # Icon extraction tools
    if ! command_exists wrestool || ! command_exists icotool; then
        log_info "Installing icon extraction tools..."
        safe_install "pacman -S --needed --noconfirm" icoutils
    fi

    # ImageMagick for icon processing
    if ! command_exists convert; then
        log_info "Installing ImageMagick..."
        safe_install "pacman -S --needed --noconfirm" imagemagick
    fi

    # Python (usually pre-installed)
    if ! command_exists python3 && ! command_exists python; then
        log_info "Installing Python..."
        safe_install "pacman -S --needed --noconfirm" python python-pip
    fi

    # Additional development packages
    log_info "Installing additional development packages..."
    safe_install "pacman -S --needed --noconfirm" pkgconf openssl

    # Install global npm packages
    install_npm_packages

    # Install AppImageTool (check AUR first)
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
        # Try to install from AUR if available
        if install_from_aur "appimagetool-appimage"; then
            log_success "AppImageTool installed from AUR"
            return
        fi

        # Fallback to manual installation
        log_info "Installing AppImageTool manually..."
        local temp_file=$(mktemp)
        download_with_retry "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" "$temp_file"
        chmod +x "$temp_file"
        safe_install "mv" "$temp_file" "/usr/local/bin/appimagetool"
    fi
}

install_from_aur() {
    local package="$1"

    # Check if an AUR helper is available
    for helper in yay paru trizen yaourt; do
        if command_exists "$helper"; then
            log_info "Installing $package from AUR using $helper..."
            if $helper -S --noconfirm "$package" 2>/dev/null; then
                return 0
            fi
        fi
    done

    # Check if makepkg is available for manual AUR installation
    if command_exists makepkg && command_exists git; then
        log_info "Installing $package from AUR manually..."
        local temp_dir=$(mktemp -d)
        cd "$temp_dir"

        if git clone "https://aur.archlinux.org/${package}.git" 2>/dev/null; then
            cd "$package"
            if makepkg -si --noconfirm 2>/dev/null; then
                rm -rf "$temp_dir"
                return 0
            fi
        fi
        rm -rf "$temp_dir"
    fi

    log_warning "Could not install $package from AUR"
    return 1
}