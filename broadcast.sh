#!/bin/bash

# broadcast.sh by James Forwood (uberoptix)
# Designed to quickly setup a wifi broadcast on a new install of Raspberry Pi OS.
# Last updated 6 Jan 2024

# Define script URL
script_url="https://raw.githubusercontent.com/uberoptix/piscripts/main/broadcast.sh"

# Check if the script is running in a pipe (e.g., via curl command)
if [ ! -t 0 ]; then
    # Download and run the script locally
    curl -sSL "$script_url" -o /tmp/uberoptix_broadcast.sh
    bash /tmp/uberoptix_broadcast.sh
    rm /tmp/uberoptix_broadcast.sh
    exit $?
fi

while true; do
    # Prompt for user input
    read -p "Enter the Wi-Fi interface name (e.g., wlan1): " wifi_interface
    read -p "Enter the desired static IP address (e.g., 192.168.220.1): " static_ip
    read -p "Enter the desired SSID for the network: " ssid
    read -p "Enter the passphrase for the network: " passphrase

    # Summarize inputs for validation
    echo -e "\nConfiguration Summary:"
    echo "Wi-Fi Interface: $wifi_interface"
    echo "Static IP Address: $static_ip"
    echo "SSID: $ssid"
    echo "Passphrase: $passphrase"
    echo -e "\nIs this information correct? (y/n)"
    read -p "> " confirmation
    if [ "$confirmation" = "y" ]; then
        break
    else
        echo "Please re-enter the configuration details."
    fi
done

# Update and install necessary packages
sudo apt update
sudo apt install dnsmasq hostapd -y

# Stop dnsmasq and hostapd services
sudo systemctl stop dnsmasq
sudo systemctl stop hostapd

# Back up configuration files
sudo cp /etc/dhcpcd.conf /etc/dhcpcd.conf.bak
sudo cp /etc/hostapd/hostapd.conf /etc/hostapd/hostapd.conf.bak 2>/dev/null
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.bak 2>/dev/null
sudo cp /etc/sysctl.conf /etc/sysctl.conf.bak

# Configure a static IP for the USB Wi-Fi adapter
echo -e "\ninterface $wifi_interface\nstatic ip_address=${static_ip}/24\nnohook wpa_supplicant" | sudo tee -a /etc/dhcpcd.conf

# Restart dhcpcd
sudo service dhcpcd restart

# Configure Hostapd for Access Point
cat <<EOF | sudo tee /etc/hostapd/hostapd.conf
interface=$wifi_interface
driver=nl80211
ssid=$ssid
hw_mode=g
channel=7
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$passphrase
wpa_key_mgmt=WPA-PSK
wpa_pairwise=TKIP
rsn_pairwise=CCMP
EOF

# Set DAEMON_CONF in hostapd
sudo sed -i 's/^#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/default/hostapd

# Configure Dnsmasq
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig
echo -e "interface=$wifi_interface\ndhcp-range=${static_ip%.*}.50,${static_ip%.*}.150,255.255.255.0,24h" | sudo tee /etc/dnsmasq.conf

# Enable IP Forwarding
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

# Add NAT rule to iptables
sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE # Replace eth0 with your internet-facing interface if different
sudo sh -c "iptables-save > /etc/iptables.ipv4.nat"

# Install iptables-persistent for saving rules
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt install iptables-persistent -y

# Enable and start services
sudo systemctl unmask hostapd
sudo systemctl enable hostapd
sudo systemctl start hostapd
sudo systemctl restart dnsmasq

echo "Setup Complete."

# Automated reboot with delay and cancel option
echo "Rebooting in 10 seconds to apply changes. Press any key to cancel."
read -t 10 -n 1
if [ $? = 0 ]; then
    echo "Reboot cancelled by user."
else
    echo "Rebooting now."
    sudo reboot
