#!/bin/bash

# Distribution detection script
# Sets DISTRO_NAME and DISTRO_FAMILY variables

detect_distro() {
    DISTRO_NAME=""
    DISTRO_FAMILY=""

    # Check for various distribution identification methods
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        DISTRO_NAME="$NAME"
        case "$ID" in
            fedora|centos|rhel|rocky|almalinux)
                DISTRO_FAMILY="fedora"
                ;;
            ubuntu|debian|linuxmint|elementary|zorin|pop)
                DISTRO_FAMILY="debian"
                ;;
            arch|manjaro|endeavouros|garuda|artix)
                DISTRO_FAMILY="arch"
                ;;
            opensuse*|sles)
                DISTRO_FAMILY="opensuse"
                ;;
            *)
                # Try to detect based on ID_LIKE
                case "$ID_LIKE" in
                    *fedora*|*rhel*)
                        DISTRO_FAMILY="fedora"
                        ;;
                    *debian*|*ubuntu*)
                        DISTRO_FAMILY="debian"
                        ;;
                    *arch*)
                        DISTRO_FAMILY="arch"
                        ;;
                    *)
                        DISTRO_FAMILY="unknown"
                        ;;
                esac
                ;;
        esac
    elif [ -f /etc/redhat-release ]; then
        DISTRO_NAME=$(cat /etc/redhat-release)
        DISTRO_FAMILY="fedora"
    elif [ -f /etc/debian_version ]; then
        DISTRO_NAME="Debian $(cat /etc/debian_version)"
        DISTRO_FAMILY="debian"
    elif [ -f /etc/arch-release ]; then
        DISTRO_NAME="Arch Linux"
        DISTRO_FAMILY="arch"
    elif command -v lsb_release >/dev/null 2>&1; then
        DISTRO_NAME=$(lsb_release -d | cut -f2)
        case "$(lsb_release -i | cut -f2 | tr '[:upper:]' '[:lower:]')" in
            *ubuntu*|*debian*|*mint*)
                DISTRO_FAMILY="debian"
                ;;
            *fedora*|*centos*|*rhel*)
                DISTRO_FAMILY="fedora"
                ;;
            *)
                DISTRO_FAMILY="unknown"
                ;;
        esac
    else
        DISTRO_NAME="Unknown"
        DISTRO_FAMILY="unknown"
    fi

    # Export variables for use in other scripts
    export DISTRO_NAME
    export DISTRO_FAMILY
}