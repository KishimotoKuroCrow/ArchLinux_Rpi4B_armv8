#!/bin/bash

# Setup directory
cd ~/
echo 'history -c' >> ~/.bash_logout
echo 'echo "" > ~/.bash_history' >> ~/.bash_logout

## Login into XFCE4 interface immediately
#echo "exec startxfce4" >> ~/.xinitrc

# Scripts to facilitate changing the IP routing
#------------------------------------------------
# Clear all routing rules
cat > ~/cleanfw.sh <<EOL
#!/bin/bash
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -F
iptables -X
EOL

# setup routing rules
cat > ~/pihole_default.sh <<EOL
#!/bin/bash
WAN_IF=wlan0
rm /etc/dnsmasq.d/PiHole_\${WAN_IF}_dhcpserver.conf
sed -i 's/^server=8.8/#server=8.8/g' /etc/dnsmasq.d/01-pihole.conf
sed -i "s/interface=.*//g" /etc/dnsmasq.d/01-pihole.conf
sed -i "s/^server=.*//g" /etc/dnsmasq.d/01-pihole.conf
echo "interface=\${WAN_IF}" >> /etc/dnsmasq.d/01-pihole.conf
echo 'server=127.0.0.1#5300' >> /etc/dnsmasq.d/01-pihole.conf
sed -i 's/#DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
sed -i "s/DNS=.*//g" /etc/systemd/network/eth.network
echo "DNS=127.0.1.1" >> /etc/systemd/network/eth.network
rm /etc/resolv.conf
echo nameserver 127.0.1.1 > /etc/resolv.conf
EOL

cat > ~/setup_default.sh <<EOL
#!/bin/bash
WAN_IF=eth0
./cleanfw.sh
iptables -t nat -A POSTROUTING -o \${WAN_IF} -j MASQUERADE
iptables -A FORWARD -i wlan0 -o \${WAN_IF} -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4
EOL
cat > ~/setup_usbwlan.sh <<EOL
#!/bin/bash
WAN_IF=\$1
./cleanfw.sh
iptables -t nat -A POSTROUTING -o \${WAN_IF} -j MASQUERADE
iptables -A FORWARD -i wlan0 -o \${WAN_IF} -j ACCEPT
iptables -A FORWARD -i eth0 -o \${WAN_IF} -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4
EOL
chmod +x *.sh

# Quit
exit
