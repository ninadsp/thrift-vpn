%{ for peer in wg_client_pub_keys ~}
[Peer]
# ${peer.name}
AllowedIPs = ${peer.ip_addr}
Publickey = ${peer.pub_key}

%{ endfor ~}