#!/bin/bash

pass() {
    echo -e "\033[32m✔ $1\033[0m"
}

fail() {
    echo -e "\033[31m✘ $1\033[0m"
    exit 1
}

fail_no_exit() {
    echo -e "\033[31m✘ $1\033[0m"
}

info() {
    echo -e "\033[34mℹ $1\033[0m"
}

#function to detect the futurehome rootfs partition
detect_rpi_rootfs_partition() {
    DEVICE=$(lsblk -n -o NAME,LABEL | grep "rootfs" | awk '{gsub(/[├─└─]/, "", $1); print $1}')
    if [ -z "$DEVICE" ]; then
        fail "Failed to detect futurehome cube. Make sure the device is connected, powered, and the reset button has been pressed."
    fi
    echo "/dev/$DEVICE"
}

info "Rooting futurehome cube-1v1"

rpiboot || rpiusbboot
if [ $? -ne 0 ]; then
    fail "Failed to boot into USB mode, make sure the device is connected, powered, and the reset button has been pressed."
fi

sleep 5

#detect the Raspberry Pi rootfs partition
info "Detecting futurehome rootfs partition..."
PARTITION=$(detect_rpi_rootfs_partition)

info "Trying to unmount $PARTITION"
umount "$PARTITION" || info "Failed to unmount $PARTITION, continuing with the script"

sleep 5
info "Mounting $PARTITION"

mount "$PARTITION" /mnt || fail "Failed to mount $PARTITION, exiting script"
pass "Successfully mounted $PARTITION to /mnt"

#setting password for the root user "fh" to "supersecret"
sed -i '/^fh:/c\fh:$6$R8TLWstC3WHStKPC$p7S3zWlp82yyIDLWAt5W4P1qSXbxyZi0OP.psegEGMBS8FelViZwkkhn7UMVjAingROTNOLH5wBMIv.rlbWji.:17949:0:99999:7:::' /mnt/etc/shadow || fail "Failed to modify /mnt/etc/shadow"
pass "Successfully set password for user 'fh' to 'supersecret'"

#edit sshd_config to allow root login
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /mnt/etc/ssh/sshd_config || fail "Failed to modify /mnt/etc/ssh/sshd_config"
pass "Successfully modified /mnt/etc/ssh/sshd_config to allow root login"

#create a symlink for the sshd service
ln -s /lib/systemd/system/ssh.service /mnt/etc/systemd/system/multi-user.target.wants/sshd.service || fail "Failed to create symlink for sshd service"
pass "Successfully created symlink for sshd service"

#append legacy repos to apt sources
echo "deb http://legacy.raspbian.org/raspbian/ stretch main contrib non-free rpi" >> /mnt/etc/apt/sources.list || fail "Failed to append legacy repos to /mnt/etc/apt/sources.list"
pass "Successfully appended legacy repos to /mnt/etc/apt/sources.list"

echo "deb-src http://legacy.raspbian.org/raspbian/ stretch main contrib non-free rpi" >> /mnt/etc/apt/sources.list || fail "Failed to append deb-src legacy repos to /mnt/etc/apt/sources.list"
pass "Successfully appended deb-src legacy repos to /mnt/etc/apt/sources.list"

sleep 1

#unmount the partition
umount "$PARTITION" || fail "Failed to unmount $PARTITION after mounting"
pass "Successfully unmounted $PARTITION"

pass "Rooting process completed successfully. You can now unplug and reboot the device."