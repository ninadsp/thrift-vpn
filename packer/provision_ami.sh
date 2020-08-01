#!/bin/bash
#
#
# TODO: Where to fetch the DNS update script from?

set -ex

sudo apt-get update -q
sudo apt-get install -qy fail2ban wireguard

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
# TODO: Configure fail2ban
