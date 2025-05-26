#!/bin/bash

# Utility functions used across scripts

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Get sudo command (handles systems without sudo)
get_sudo() {
    if command_exists sudo; then
        echo "sudo"
    elif command_exists doas; then
        echo "doas"
    elif is_root; then
        echo ""
    else
        log_error "No privilege escalation method found (sudo/doas) and not running as root"
        exit 1
    fi
}

# Safe package installation with privilege escalation
safe_install() {
    local installer_cmd="$1"
    shift
    local packages="$@"

    local sudo_cmd=$(get_sudo)

    if [ -n "$sudo_cmd" ]; then
        $sudo_cmd $installer_cmd $packages
    else
        $installer_cmd $packages
    fi
}

# Download file with retry logic
download_with_retry() {
    local url="$1"
    local output="$2"
    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        log_info "Download attempt $attempt/$max_attempts: $url"
        if curl -L --fail --connect-timeout 30 --max-time 300 -o "$output" "$url"; then
            log_success "Download completed successfully"
            return 0
        else
            log_warning "Download attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
        ((attempt++))
    done

    log_error "Failed to download after $max_attempts attempts: $url"
    return 1
}

# Verify file exists and is not empty
verify_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        log_error "File not found: $file"
        return 1
    fi
    if [ ! -s "$file" ]; then
        log_error "File is empty: $file"
        return 1
    fi
    return 0
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_info "Created directory: $dir"
    fi
}