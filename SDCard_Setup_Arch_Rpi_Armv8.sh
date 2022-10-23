#!/bin/bash

# References:
#-------------
#https://unix.stackexchange.com/questions/501626/create-bootable-sd-card-with-parted 
#https://bbs.archlinux.org/viewtopic.php?id=204252
#https://itsfoss.com/install-arch-raspberry-pi/

# Partition the SD card with input as the disk designation
# 1st partition: boot: 256MB (200MB should be more than enough)
# 2nd partition: remaining
ARCHARMIMG=ArchLinuxARM-rpi-aarch64-latest
HOSTNAME=ArchLinuxRPi
DISK=$1
MOUNTROOT=/mnt/SDRoot
MOUNTBOOT=$MOUNTROOT/boot
echo "================ Parititoning /dev/${DISK}/ =================="
parted --script /dev/$DISK \
   mklabel msdos \
   mkpart primary fat32 1MiB 256MiB \
   mkpart primary ext4 256MiB 100% \
   set 1 boot on \
   set 1 lba on
echo "================ Formatting /dev/${DISK}/ =================="
mkfs.fat -F32 /dev/${DISK}1
mkfs.ext4 /dev/${DISK}2

# Mount the paritions
echo "================ Mounting disks =================="
mkdir $MOUNTROOT
mount /dev/${DISK}2 $MOUNTROOT
mkdir $MOUNTBOOT
mount /dev/${DISK}1 $MOUNTBOOT

# ArchLinuxARM-rpi-aarch64-latest.tar.gz must be already downloaded
# ArchIso does not have wget by default, and it may not have enough space
# to download this image.  However, I'll leave the wget command commented
# out and you can enable it if you think you have the space
# -------
#rm -f ${ARCHARMIMG}.tar.gz
#wget http://os.archlinuxarm.org/os/${ARCHARMIMG}.tar.gz
bsdtar -xpf ${ARCHARMIMG}.tar.gz -C $MOUNTROOT
sync

# Change the fstab SD MMC blk
sed -i 's/mmcblk0/mmcblk1/g' $MOUNTROOT/etc/fstab

## Copy files for personalization
## - Waveshare: for Waveshare HDMI LCD screen with GPIO
#cp -r ./Waveshare $MOUNTBOOT
#sync

# - pkglist: list of packages to install
# - userscript: execute script as a new user
chmod 666 ./pkglist.txt
chmod 777 ./user_pref.sh
cp ./pkglist.txt $MOUNTROOT/root
cp ./user_pref.sh $MOUNTROOT/root
sync

# Change Environment Root and run Machine Setup script script
chmod 700 ./Machine_Setup_Arch.sh
chmod 700 ./root_pref.sh
cp ./Machine_Setup_Arch.sh $MOUNTROOT
cp ./root_pref.sh $MOUNTROOT/root
sync
arch-chroot $MOUNTROOT ./Machine_Setup_Arch.sh $HOSTNAME

echo "================ Copy Boot Directory here ==================\n"
# Copy the boot directory here
mkdir -p ./boot
rm -rf ./boot/*
rsync -a $MOUNTBOOT/ ./boot/
sync

# Unmount the partitions
umount $MOUNTBOOT
umount $MOUNTROOT
echo "================ Script Ended ==================\n"

