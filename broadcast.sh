#!/bin/bash

# broadcast.sh by James Forwood (uberoptix)
# Designed to quickly setup a wifi broadcast on a new install of Raspberry Pi OS.
# Last updated 6 Jan 2024

# Configuration variables
AP_INTERFACE="wlan1"
AP_SSID="YourNetworkSSID"
AP_PASSPHRASE="YourPassword"
AP_IP="192.168.5.1"

# Define the network sources as an array
NET_SOURCES=("eth0" "wlan0")

# Calculate DHCP range
IFS='.' read -ra ADDR <<< "$AP_IP"
DHCP_RANGE_START="${ADDR[0]}.${ADDR[1]}.$((ADDR[2]+1)).$((ADDR[3]+1))"
DHCP_RANGE_END="${ADDR[0]}.${ADDR[1]}.$((ADDR[2]+1)).$((ADDR[3]+50))"

echo "$(date) - broadcast.sh - Installing necessary packages…"

sudo apt update
sudo apt install hostapd dnsmasq iptables-persistent -y
systemctl stop hostapd
systemctl stop dnsmasq

echo "$(date) - broadcast.sh - Backup up configuration files…"

sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak

echo "$(date) - broadcast.sh - Configuring hostapd…"

cat > /etc/hostapd/hostapd.conf <<EOF
interface=$AP_INTERFACE
driver=nl80211
ssid=$AP_SSID
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$AP_PASSPHRASE
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF
sudo sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

echo "$(date) - broadcast.sh - Configuring dnsmasq…"

cat > /etc/dnsmasq.conf <<EOF
interface=$AP_INTERFACE
dhcp-range=$DHCP_RANGE_START,$DHCP_RANGE_END,255.255.255.0,24h
EOF

echo "$(date) - broadcast.sh - Configuring NetworkManager…"

nmcli dev set $AP_INTERFACE managed no
ip link set $AP_INTERFACE down
ip addr add $AP_IP/24 dev $AP_INTERFACE
ip link set $AP_INTERFACE up

echo "$(date) - broadcast.sh - Configuring iptables…"

for source in "${NET_SOURCES[@]}"; do
    iptables -t nat -A POSTROUTING -o $source -j MASQUERADE
    iptables -A FORWARD -i $source -o $AP_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $AP_INTERFACE -o $source -j ACCEPT
done
netfilter-persistent save

echo "$(date) - broadcast.sh - Configuring IP Forwarding…"

echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "$(date) - broadcast.sh - Restarting services…"

systemctl unmask hostapd
systemctl enable hostapd
systemctl start hostapd
systemctl unmask dnsmasq
systemctl enable dnsmasq
systemctl start dnsmasq
systemctl restart NetworkManager

echo "$(date) - broadcast.sh - Wi-Fi Access Point setup is complete. Reboot now? (y/n)"

read -r REBOOT_CONFIRMATION
if [[ $REBOOT_CONFIRMATION =~ ^[Yy]$ ]]; then
    echo "Rebooting in 10 seconds to apply changes. Press any key to cancel."
    read -t 10 -n 1
    if [ $? = 0 ]; then
        echo "$(date) - broadcast.sh - Reboot cancelled by user."
    else
        echo "$(date) - broadcast.sh - Rebooting now."
        sudo reboot
    fi
else
    echo "$(date) - broadcast.sh - You may need to manually reboot your system for changes to take effect."
fi
