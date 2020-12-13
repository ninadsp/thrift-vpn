#!/bin/bash
#
#
# TODO: Where to fetch the DNS update script from?

set -ex

sudo apt-get update -q
sudo apt-get install -qy linux-headers-$(uname -r) wireguard nftables

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

ifname=$(ip link | awk -F: '$0 !~ "lo|vir|wl|wg|^[^0-9]"{print $2;getline}' | tr -d ' ')

sudo nft add table ip nat
sudo nft add chain ip nat PREROUTING { type nat hook prerouting priority 0 \; }
sudo nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \; }
sudo nft add rule ip nat POSTROUTING ip saddr 10.0.0.0/24 oifname "${ifname}" masquerade

sudo /bin/bash -c "nft list ruleset >> /etc/nftables.conf"
sudo systemctl enable nftables
sudo systemctl start nftables
