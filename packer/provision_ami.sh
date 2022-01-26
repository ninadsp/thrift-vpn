#!/bin/bash
#
#

set -ex

sudo apt-get update -q
sudo apt-get install -qy linux-headers-$(uname -r) wireguard nftables

sudo sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf

cat <<EOF > /tmp/nftables.conf
# https://xdeb.org/post/2019/09/26/setting-up-a-server-firewall-with-nftables-that-support-wireguard-vpn/ - IPv4, relevant bits
# Throw away the default Firewall rules
flush ruleset

# Set some variables that we can reuse
define vpn = wg0
# These will be replaced during cloud-init with the appropriate values
define vpn_port = 51820
define vpn_net = 10.0.1.0/24
define wan = ens5

table inet filter {
  
  # https://wiki.nftables.org/wiki-nftables/index.php/Sets
  set tcp_accepted { type inet_service; flags interval; elements = { 22 } }

  set udp_accepted { type inet_service; flags interval; elements = { \$vpn_port } }

  chain reusable_checks {
    # Drop invalid packets
    ct state invalid drop
    
    # Allow connections that are in an established state
    ct state established,related accept
  }

  chain input {
    type filter hook input priority 0; policy drop;

    # Include reusable_checks before continuing
    jump reusable_checks

    # Limit ping requests to 1 per second, with a burst upto 5
    ip protocol icmp icmp type echo-request limit rate over 1/second burst 5 packets drop

    # Allow connections on the local/loopback interface
    iif lo accept

    # Allow specific ping requests
    ip protocol icmp icmp type { destination-unreachable, echo-reply, echo-request, source-quench, time-exceeded } accept

    # Allow needed tcp and udp ports.
    iifname \$wan tcp dport @tcp_accepted ct state new accept
    iifname \$wan udp dport @udp_accepted ct state new accept

    # Allow WireGuard clients to access services.
    iifname \$vpn tcp dport @tcp_accepted ct state new accept
    iifname \$vpn udp dport @udp_accepted ct state new accept

    # Allow WireGuard clients to connect with each other
    iifname \$vpn oifname \$vpn ct state new accept
  }

  chain forward {
    type filter hook forward priority 0; policy drop; 

    # Include reusable_checks before continuing
    jump reusable_checks

    # Allow WireGuard traffic to access the internet via wan.
    iifname \$vpn oifname \$wan ct state new accept

    # Allow WireGuard clients to connect with each other
    iifname \$vpn oifname \$vpn ct state new accept
  }

  chain output {
    type filter hook output priority 0; policy drop; 

    # Include reusable_checks before continuing
    jump reusable_checks

    # Allow new traffic to go out from this instance
    ct state new accept
  }
}

# VPN specific packet mangling rules
table ip nat {
  chain PREROUTING {
    type nat hook prerouting priority -100;
  }

  chain POSTROUTING {
    type nat hook postrouting priority 100;

    # Change the source address for any packet coming through the WireGuard interface 
    # and destined for the wider internet from the WireGuard client's internal IP
    # that of this instance before sending the traffic out
    ip saddr \$vpn_net oifname \$wan masquerade
  }
}
EOF

sudo mv /tmp/nftables.conf /etc/nftables.conf

sudo systemctl enable nftables
sudo systemctl start nftables
