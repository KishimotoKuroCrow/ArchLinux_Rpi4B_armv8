#!/bin/bash

HOSTNAME=$1

# Initialize the pacman keys
pacman-key --init
pacman-key --populate archlinuxarm

# Update Arch Linux system
sed -i 's/#Color/Color/g' /etc/pacman.conf
pacman -Syyu --noconfirm

# Set device hostname
echo $HOSTNAME > /etc/hostname

# Set locale
sed -i 's/#en_US/en_US/g' /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf

# Setup the hosts file
cat > /etc/hosts <<EOL
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME} pi.hole
EOL
sync

#
# PERSONALIZE ROOT (copied root_pref.sh in /root/ earlier)
#=========================
cd /root/
./root_pref.sh

# Quit
exit
