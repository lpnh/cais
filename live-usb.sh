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

log "running lpnh's custom arch install script: live-usb"

# config variables
ISO_DIR="latest-iso"
ISO_PATTERN="archlinux*x86_64.iso"

# check ISO_DIR
if [[ ! -d "$ISO_DIR" ]]; then
    error "directory '$ISO_DIR' not found"
fi

# ISO_FILE
log "checking available ISO files..."
ISO_FILE=$(find "$ISO_DIR" -type f -name "$ISO_PATTERN" -printf '%T@ %p\n' 2>/dev/null | sort -nr | awk 'NR==1 {print $2}')
if [[ -z "$ISO_FILE" ]]; then
    error "no Arch Linux ISO found in '$ISO_DIR'"
else
    log "'$ISO_FILE' found 󰄬"
fi

# USB_DEV
log "searching devices..."
usb_dev_option=$(lsblk -dnro rm,type,tran,path | awk '$1 == "1" && $2 == "disk" && $3 == "usb" {print $4}')
if [[ -z "$usb_dev_option" ]]; then
    error "no USB device found"
else
    for some_device in $usb_dev_option; do
        log "'$(lsblk -dno name,model,size "$some_device")' found 󰄬"
    done
fi
usb_dev_count=$(echo "$usb_dev_option" | wc -w)
if [[ $usb_dev_count -gt 1 ]]; then
    read -r -p "enter the name of the target USB device (sdX): " device_name
    if [[ -z "$device_name" ]]; then
        error "device name cannot be empty"
    else
        USB_DEV="/dev/$device_name"
    fi
else
    USB_DEV="$usb_dev_option"
fi

validate_usb_device() {
    local chosen_device="$1"

    log "validating '$chosen_device'..."

    # check if device exists
    if [[ ! -b "$chosen_device" ]]; then
        error "'$chosen_device' was not found"
    fi

    # Check if device is mounted
    if [[ $(lsblk -rno mountpoint "$chosen_device") == "" ]]; then
        log "'$chosen_device' is not mounted 󰄬"
    else
        error "'$chosen_device' or its partitions are mounted"
    fi

    # get more device info
    local dev_info
    dev_info=$(lsblk --json -do 'type,tran,rm,size' "$chosen_device")

    # extract key properties
    local device_type
    local transport
    local is_removable
    local size_bytes

    device_type=$(echo "$dev_info" | jq -r '.blockdevices[0].type')
    transport=$(echo "$dev_info" | jq -r '.blockdevices[0].tran')
    is_removable=$(echo "$dev_info" | jq -r '.blockdevices[0].rm')
    size_bytes=$(echo "$dev_info" | jq -r '.blockdevices[0].size' | numfmt --from=iec)

    if [[ "$device_type" == "disk" ]]; then
        log "'$chosen_device' is not a partition 󰄬"
    else
        error "'$chosen_device' is a partition"
    fi

    if [[ "$transport" == "usb" ]]; then
        log "'$chosen_device' is a USB device 󰄬"
    else
        error "'$chosen_device' is not a USB device"
    fi

    if [[ "$is_removable" == "true" ]]; then
        log "'$chosen_device' is removable 󰄬"
    else
        error "'$chosen_device' is not removable"
    fi

    if ((size_bytes > 137438953472)); then # size_bytes > 128GB
        readable_size="$(numfmt --to=si --round=nearest "$size_bytes")"
        log "device size '$readable_size' is unusually large for a USB stick"
        read -r -p "continue? (y/N): " size_confirm
        if [[ "${size_confirm,,}" != "y" ]] && [[ "${size_confirm,,}" != "yes" ]]; then
            error "operation aborted"
        fi
    fi

    return 0
}

validate_usb_device "$USB_DEV" || error "device validation failed"

# confirmation
log "this will overwrite all data on '$USB_DEV'"
read -r -p "are you sure you want to continue? (y/N): " confirm_writing
if [[ "${confirm_writing,,}" == "y" ]] || [[ "${confirm_writing,,}" == "yes" ]]; then
    log "proceeding..."
else
    error "operation aborted"
fi

# finally write
log "writing '$ISO_FILE' to '$USB_DEV'..."
sudo dd if="$ISO_FILE" of="$USB_DEV" bs=4M status=progress oflag=sync

success "done! live USB created successfully!"
