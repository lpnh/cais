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

log "running lpnh's custom arch install script: pre-chroot"

# config variables
GPU_TYPE="" # amd or nvidia
CPU_TYPE="" # amd or intel

# prompt for config options
read -r -p "GPU type (amd/nvidia): " GPU_TYPE
read -r -p "CPU type (amd/intel): " CPU_TYPE

# validate inputs
[[ "$GPU_TYPE" != "amd" && "$GPU_TYPE" != "nvidia" ]] && error "GPU type must be 'amd' or 'nvidia'"
[[ "$CPU_TYPE" != "amd" && "$CPU_TYPE" != "intel" ]] && error "CPU type must be 'amd' or 'intel'"

# mirrorlist
log "updating mirrorlist..."
reflector --protocol https --verbose --latest 25 --sort rate --save /etc/pacman.d/mirrorlist || error "failed to update mirrorlist"

# set base packages
log "setting the base packages..."
PACKAGES="base base-devel linux linux-firmware git nano networkmanager booster busybox systemd-ukify mesa"

# GPU driver
log "adding GPU-specific packages..."
if [ "$GPU_TYPE" = "amd" ]; then
    PACKAGES="$PACKAGES vulkan-radeon"
else
    PACKAGES="$PACKAGES nvidia"
fi

# CPU microcode
log "adding CPU-specific packages..."
if [ "$CPU_TYPE" = "amd" ]; then
    PACKAGES="$PACKAGES amd-ucode"
else
    PACKAGES="$PACKAGES intel-ucode"
fi

# install packages
log "installing packages..."
pacstrap -K /mnt "$PACKAGES" || error "failed to install packages"

# fstab
log "generating fstab..."
genfstab -U /mnt >>/mnt/etc/fstab || error "failed to generate fstab"

success "pre-chroot setup completed successfully!"

log "you can now change the root with 'arch-chroot /mnt' command"
log "then execute the post-chroot script"
