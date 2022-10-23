#!/bin/bash

# ---------------
# ---------------
# INFO TO CHANGE
# ---------------
# Username and Passwords
ROOTPWD=rootpwd
USERNAME=newuser
PASSWORD=newpwd
# Software Access Point Info
WIFI_AP=RPI_AP
WIFI_PWD=rpipwd
WIFI_INTF=wlan0
# ---------------
# ---------------
NEWREPO=/home/$USERNAME/GIT_BUILD
AUR_LIST="cloudflared-git pi-hole-ftl pi-hole-server"
STARTSCR=/root/startup.sh

# Change Root password
echo root:$ROOTPWD | chpasswd

# Install packages from a list (to avoid updating this script)
pacman -S --noconfirm --needed - < /root/pkglist.txt
sync

# Set wheel in sudoers (installed from pkglist)
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers

# Setup BlackArch repository, but no installation
cd ~/
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
./strap.sh
pacman -Syu --noconfirm
sync

# Setup root directory
cd ~/
cp /etc/skel/.bash* ~/
echo 'history -c' >> ~/.bash_logout
echo 'echo "" > /root/.bash_history' >> ~/.bash_logout
echo '#!/bin/bash' > $STARTSCR
echo "ip addr add 172.19.100.1/24 broadcast + dev $WIFI_INTF; sleep 2" >> $STARTSCR

# Setup hostapd (Software Access Point)
mv /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.org
cat > /etc/hostapd/hostapd.conf <<EOL
interface=$WIFI_INTF
driver=nl80211
country_code=CA
ssid=$WIFI_AP
auth_algs=1
wpa=2
wpa_key_mgmt=WPA-PSK
wpa_pairwise=CCMP
wpa_passphrase=$WIFI_PWD
hw_mode=a
channel=36
wmm_enabled=1
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2
EOL
echo 'systemctl start hostapd.service; sleep 1'>> $STARTSCR
echo 'systemctl start iptables.service; sleep 1'>> $STARTSCR

# No need for this as TTY rotate. This does not work
# but putting fbcon=rotate:3 in boot.txt did the trick
#------------------------------------------------------
## Enable a service to properly rotate the TTY screen
#cat > /etc/systemd/system/rotate_tty.service <<EOL
#[Unit]
#Description="Rotate TTY Screen"
#
#[Service]
#ExecStart=echo 3 | tee /sys/class/graphics/fbcon/rotate_all
#
#[Install]
#WantedBy=multi-user.target
#EOL
#echo 'systemctl start rotate_tty.service' >> $STARTSCR

# Enable a startup service
cat > /etc/systemd/system/startup.service <<EOL
[Unit]
Description="Service Startup"

[Service]
ExecStart=/root/startup.sh

[Install]
WantedBy=multi-user.target
EOL
systemctl enable startup.service

# Delete the default user "alarm"
userdel -r alarm

# Add my user with my pwd
useradd -m -G wheel -s /bin/bash -p $(echo ${PASSWORD} | openssl passwd -1 -stdin) $USERNAME

# Copy the public key into the new user's directory for authorization.
# Copy the private key in boot for other device to SSH into this box.
# I know it's bad practice and very dangerous to leak out private keys, 
# but since this is an automated procedure, the user have the responsibility
# to delete this key from the boot once they're done copying it in their client's machine.
ssh-keygen -A
mkdir -p /home/$USERNAME/.ssh
cat /etc/ssh/ssh_host_rsa_key.pub > /home/$USERNAME/.ssh/authorized_keys
cp /etc/ssh/ssh_host_rsa_key /boot
chmod 700 /home/$USERNAME/.ssh
chmod 600 /home/$USERNAME/.ssh/*
chown -R $USERNAME /home/$USERNAME/.ssh

# Setup Network Forwarding
cat > /etc/sysctl.d/30-ipforward.conf <<EOL
net.ipv4.ip_forward=1
net.ipv6.conf.default.forwarding=1
net.ipv6.conf.all.forwarding=1
EOL

# Setup Pi-Hole's DHCP server for when it's ready to be used
mkdir -p /etc/dnsmasq.d
cat > /etc/dnsmasq.d/PiHole_${WIFI_INTF}_dhcpserver.conf <<EOL
dhcp-leasefile=/etc/pihole/dhcp.leases
interface=$WIFI_INTF
dhcp-authoritative
dhcp-range=172.19.190.150,172.19.190.154,96h
dhcp-option=option:router,172.19.190.1
EOL
# Setup DHCP server for eth0 interface with Pi-Hole (if it's not the WAN)
# This config is not loaded until it ends with ".conf"
cat > /etc/dnsmasq.d/PiHole_eth0_dhcpserver.conf.slave <<EOL
dhcp-leasefile=/etc/pihole/dhcp.leases
interface=eth0
dhcp-authoritative
dhcp-range=172.20.200.150,172.20.200.154,96h
dhcp-option=option:router,172.20.200.1
EOL

# Customize SSH
sed -i 's/#Port 22/Port 32310/g' /etc/ssh/sshd_config
sed -i 's/#PermitEmptyPasswords/PermitEmptyPasswords/g' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sed -i 's/#X11Forwarding/X11Forwarding/g' /etc/ssh/sshd_config
echo "AllowUsers $USERNAME" >> /etc/ssh/sshd_config
echo 'systemctl start sshd.service; sleep 1' >> $STARTSCR

# Get a Personal essential from Github
git clone https://github.com/KishimotoKuroCrow/PersonalEssentials
cd PersonalEssentials
cp .vimrc ~/
cp .vimrc /home/$USERNAME/

# Get Pi-Hole related files, but only install them once connected
# in the machine
mkdir -p $NEWREPO
cd $NEWREPO
echo '#!/bin/bash' > build_all.sh
for repo in $AUR_LIST; do
   git clone https://aur.archlinux.org/$repo
   echo "cd $NEWREPO/$repo; makepkg -si --noconfirm" >> build_all.sh
done
chmod +x build_all.sh
echo '#!/bin/bash' > addpihole.sh
git clone https://github.com/KishimotoKuroCrow/PiHoleRemote
git clone https://github.com/KishimotoKuroCrow/PiHoleDomain
cat > addpihole.sh <<EOL
#!/bin/bash
cd $NEWREPO/PiHoleRemote; ./AddList.pl *.list
cd $NEWREPO/PiHoleDomain; ./AddDomain.pl MyDomainsToBlock
cd $NEWREPO/PiHoleDomain; ./AddDomainW.pl WhitelistDomain.txt
EOL
chmod +x addpihole.sh
chown -R $USERNAME:$USERNAME $NEWREPO

## Add Waveshare 4-inch HDMI LCD configuraion
#cd /usr/share/X11/xorg.conf.d
#cp 10-evdev.conf 45-evdev.conf
#cp 10-evdev.conf 45-evdev.conf.org
#cp /boot/Waveshare/xorg.conf.d/99-* .

#cd /boot
#cp config.txt config.txt.org
#cp boot.txt boot.txt.org
#cp Waveshare/config.txt .
#sed -i 's/console=ttyS1/dwc_otg.lpm_enable=0 console=ttyAMA0/g' /boot/boot.txt
#sed -i 's/console=tty0/console=tty1/g' /boot/boot.txt
#sed -i 's/rootwait/rootwait elevator=deadline fbcon=map:10 fbcon=font:ProFont6x11 fbcon=rotate:3 autit=0/g' /boot/boot.txt
#./mkscr

# Set startup script as executable
chmod +x $STARTSCR

#
# PERSONALIZE NEW USER
#=========================
# Run additional user preference.
cd ~/
cp ~/user_pref.sh /home/$USERNAME/
chown $USERNAME:$USERNAME /home/$USERNAME/user_pref.sh
cd /home/$USERNAME
su $USERNAME ./user_pref.sh

# Quit
exit
