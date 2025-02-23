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

log "running lpnh's custom arch install script: post-chroot"

# config variables
USERNAME="lpnh"
HOSTNAME="" # desktop or laptop
GPU_TYPE="" # amd or nvidia
CPU_TYPE="" # amd or intel

# prompt for config options
read -r -p "GPU type (amd/nvidia): " GPU_TYPE
read -r -p "CPU type (amd/intel): " CPU_TYPE

# validate inputs
[[ "$HOSTNAME" != "desktop" && "$HOSTNAME" != "laptop" ]] && error "hostname must be 'desktop' or 'laptop'"
[[ "$GPU_TYPE" != "amd" && "$GPU_TYPE" != "nvidia" ]] && error "GPU type must be 'amd' or 'nvidia'"
[[ "$CPU_TYPE" != "amd" && "$CPU_TYPE" != "intel" ]] && error "CPU type must be 'amd' or 'intel'"

# time zone
log "setting timezone for 'SP, Brazil'..."
ln -sf /usr/share/zoneinfo/Brazil/East /etc/localtime
log "genereting the /etc/adjtime file..."
hwclock --systohc
log "enabling 'timesyncd' service..."
systemctl enable systemd-timesyncd.service

# locale
log "configuring locale..."
sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >/etc/locale.conf

# keyboard layout

log "setting keyboard layout..."
read -r -p "change keyboard layout to 'br-abnt2'? (y/N): " set_keyboard
if [[ "${set_keyboard,,}" == "y" ]] || [[ "${set_keyboard,,}" == "yes" ]]; then
    echo "KEYMAP=br-abnt2" >/etc/vconsole.conf
    log "keyboard layout set to 'br-abnt2'"
else
    log "using default US keyboard layout"
fi

# hostname
log "setting hostname..."
echo "${HOSTNAME}" >/etc/hostname

# user and passwords
log "creating user..."
useradd -m -G wheel "${USERNAME}"
echo "setting root password..."
passwd
echo "setting user password for ${USERNAME}..."
passwd "${USERNAME}"

# sudo
log "configuring sudo..."
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# systemd-boot
log "installing systemd-boot..."
bootctl install

# booster
log "configuring booster..."
if [ "${GPU_TYPE}" = "amd" ]; then
    echo "extra_files: busybox,fsck,fsck.ext4
modules_force_load: amdgpu,hid_generic,usbhid" >/etc/booster.yaml
else
    echo "extra_files: busybox,fsck,fsck.ext4
modules_force_load: nvidia,nvidia_modeset,nvidia_uvm,nvidia_drm,hid_generic,usbhid" >/etc/booster.yaml
fi

# kernel install
log "configuring kernel installation..."
echo "layout=uki
uki_generator=ukify" >/etc/kernel/install.conf

# ukify
log "configuring ukify..."
echo "[UKI]
Initrd=/boot/booster-linux.img
Microcode=/boot/${CPU_TYPE}-ucode.img
Splash=/usr/share/systemd/bootctl/splash-arch.bmp" >/etc/kernel/uki.conf

# configure kernel parameters
log "setting kernel parameters..."
echo "root=LABEL=ARCHIE_ROOT nvme_load=YES nowatchdog rw quiet" >/etc/kernel/cmdline

# enable NetworkManager
log "enabling NetworkManager service..."
systemctl enable NetworkManager

success "post-chroot setup completed successfully!"

# verify configurations
log "please verify the state of your current boot setup"
log "with 'kernel-install inspect':"
kernel-install inspect
log "with 'bootctl list':"
bootctl list
log "if everything seems correct you can now:"
log "exit the chroot environment with 'exit' command"
log "unmount all the partitions with 'umount -R /mnt' command"
log "reboot into your new system with 'reboot' command"
