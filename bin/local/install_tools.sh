#!/usr/bin/env bash
# Optional installation of required benchmarking tools

set -euo pipefail

install_tools() {
    local auto_yes="${1:-false}"
    log "Checking and installing required tools..."

    local pm=""
    if command -v apt-get &>/dev/null; then
        pm="apt"
    elif command -v dnf &>/dev/null; then
        pm="dnf"
    elif command -v yum &>/dev/null; then
        pm="yum"
    elif command -v zypper &>/dev/null; then
        pm="zypper"
    elif command -v pacman &>/dev/null; then
        pm="pacman"
    fi

    if [[ -z "$pm" ]]; then
        warn "No supported package manager found, skipping tool installation"
        return 1
    fi

    local tools=(sysbench hdparm fio iperf3 inxi lshw lm-sensors neofetch jq)

    log "Using package manager: $pm"
    if [[ "$auto_yes" != "true" ]]; then
        warn "auto confirmation not enabled; skipping interactive installs"
        return 0
    fi

    case "$pm" in
        apt)
            sudo apt-get update -qq
            sudo apt-get install -y "${tools[*]}" coreutils grep gawk || warn "Some packages failed to install"
            ;;
        dnf|yum)
            sudo "$pm" install -y "${tools[*]}" coreutils grep gawk || warn "Some packages failed to install"
            ;;
        zypper)
            sudo zypper install -y "${tools[*]}" coreutils grep gawk || warn "Some packages failed to install"
            ;;
        pacman)
            sudo pacman -S --noconfirm "${tools[*]}" coreutils grep gawk || warn "Some packages failed to install"
            ;;
    esac

    # Do not run sensors-detect automatically
    if command -v sensors-detect &>/dev/null; then
        log "lm-sensors detected. Skipping automatic sensors-detect."
    fi
}
