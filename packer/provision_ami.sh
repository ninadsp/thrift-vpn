#!/bin/bash
#
#
# TODO: Where to fetch the DNS update script from?

set -ex

sudo apt-get update -q
sudo apt-get install -qy linux-headers-$(uname -r) wireguard nftables

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

sudo nft add table ip nat
sudo nft add chain ip nat PREROUTING { type nat hook prerouting priority 0 \; }
sudo nft add chain ip nat POSTROUTING { type nat hook postrouting priority 100 \; }
# Had to move the masquerade stuff out of the packer provisioning into user data because
# we give people a choice to set a different CIDR block

sudo /bin/bash -c "nft list ruleset >> /etc/nftables.conf"
sudo systemctl enable nftables
sudo systemctl start nftables
