#!/bin/bash

# exit on error
set -e

# ansi colors for the output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log "running lpnh's custom arch install script: pre-partition"

# font size
log "improving default font size..."
setfont ter-222b

# boot mode
log "checking if, for some reason, CSM is enabled..."
if [ -f "/sys/firmware/efi/fw_platform_size" ]; then
    platform_size=$(cat /sys/firmware/efi/fw_platform_size)
    if [ "$platform_size" != "64" ]; then
        error "${platform_size}-bit, wtf?"
    fi
    log "nope, ${platform_size}-bit ✓"
else
    error "...yeah, it is"
fi

# keyboard
read -r -p "change keyboard layout to 'br-abnt2'? (y/N): " set_keyboard
if [[ "${set_keyboard,,}" == "y" ]] || [[ "${set_keyboard,,}" == "yes" ]]; then
    loadkeys br-abnt2
    log "keyboard layout set to 'br-abnt2'"
else
    log "using default US keyboard layout"
fi

# system clock synchronization
log "ensuring the system clock is synchronized..."
timedatectl
