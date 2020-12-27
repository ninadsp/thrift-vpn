# Thrift VPN

Use Packer and Terraform to spin up a super cheap Wireguard VPN instance.

## How to Use

* Get your AWS credentials and choose a region
* `wg genkey` for setting up the server's pub/private key
* Create a SSM Parameter (`SecureString`) and store the private key for the wireguard server
* Create a packer base image with `packer build -var instance_type=<chosen-instance-type> -var region=<your-region> packer/debian_wireguard.json`
* Create a `terraform.tfvars` with the following minimum variables included in it
* `terraform plan`
* `terraform apply`

TODO: DNS update script
TODO: harden nftables: https://xdeb.org/post/2019/09/26/setting-up-a-server-firewall-with-nftables-that-support-wireguard-vpn/
