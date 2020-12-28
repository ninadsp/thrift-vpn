# Thrift VPN

Use Packer and Terraform to spin up a super cheap Wireguard VPN instance.

This project creates an auto scaling group in an AWS VPC and provisions a Wireguard server on it with spot instances.

## Requirements

* An [AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/).
* A local [terraform installation](https://learn.hashicorp.com/tutorials/terraform/install-cli). This project has been tested with Terraform v 0.12, tests with newer versions appreciated.
* A local [packer installation](https://learn.hashicorp.com/tutorials/packer/getting-started-install).
* A local [Wireguard installation](https://www.wireguard.com/install/) to generate the key pairs (identities) for the various devices in the VPN.
* An account with a DNS service provider that provides an API to update DNS records and a DNS domain/zone hosted with them.

## How to Use

* Use [these steps](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) to create user keys for a user in your AWS account. This user will be used by Packer and Terraform to configure the VPN setup. Follow any one of [these](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) guides to set up the AWS environment on your local machine.
* Generate the server's pub/private key on your local machine with `wg genkey | tee privatekey | wg pubkey > publickey`.
* Also generate pub/private key pairs for the various clients that should be associated with the VPN.
* Choose an AWS region from [this page](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/). Pick one that is reasonably close to you (in terms of internet speeds/latency), or fits your requirements for using a VPN.
* Create your SSH key pair with [these steps](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and store them securely on your local machine.
* Follow [these](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) steps to create an AWS SSM Parameter (type `SecureString`) and store the private key for the wireguard server in it. Note: The secure string will require you to choose a AWS KMS Key to encrypt/decrypt the parameter, it is ok to use the default key generated for your account/region.
* Choose an instance type from [this page](https://aws.amazon.com/ec2/instance-types/). A General Purpose instance with low configurations is sufficient for this project. This project has currently been tested with `t3a.nano` and `t2.micro` instance sizes.
* Visit the AWS Spot Instances [pricing page](https://aws.amazon.com/ec2/spot/pricing/) and find the current prices for the chosen instance type and region. Add a few cents to the pricing to ensure that the spot request is fulfilled.
* Change to the `packer` directory. Create a packer base image with `packer build -var instance_type=<chosen-instance-type> -var region=<your-region> packer/debian_wireguard.json`
* Change to the `terraform` directory. Create a `terraform.tfvars` file with the following minimum variables included in it: `region`, `allowed_availability_zone_ids`, `ssh_key_id`, `asg_min_size`, `asg_desired_size`, `spot_max_price`, `wg_server_listen_addr`, `wg_server_private_key_path` and `wg_client_pub_keys`.
* Run `terraform plan` and inspect the output.
* Run `terraform apply`, ensure that the changes match up with the plan output, and approve creation of all resources.
* Once the apply completes, inspect the AWS console and get the public internet address of the Wireguard server's machine. Follow [these steps](https://www.wireguard.com/quickstart/) to configure the client device (as appropriate). Verify that you can connect to the VPN server.

## Examples

A sample `terraform.tfvars` file that also updates DNS records and posts a message to a Slack webhook whenever a new instance is provisioned:

```
region                        = "us-east-1"
allowed_availability_zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
ssh_key_id                    = "my-aws-key"
asg_min_size                  = 1
asg_desired_size              = 1
spot_max_price                = "0.0012"
ssh_allow_ip_range            = ["1.1.1.1/32"]
wg_server_listen_addr         = "10.0.1.1"
wg_server_private_key_path    = "/wireguard/key-1"
wg_client_pub_keys = [
  { name = "phone-1", ip_addr = "10.0.1.2/32", pub_key = "xxxxxxxx" },
  { name = "laptop-1", ip_addr = "10.0.1.3/32", pub_key = "xxxxxxxx" },
]
post_provisioning_steps = <<EOF
public_ip=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
name_com_api=$(aws ssm get-parameters --output text --region $aws_region --names "/wireguard/dns" --with-decryption --query 'Parameters[*].Value')
slack_webhook=$(aws ssm get-parameters --output text --region $aws_region --names "/wireguard/slack" --with-decryption --query 'Parameters[*].Value')

curl --silent -X PUT https://api.name.com/v4/domains/example.org/records/123456 -u "$name_com_api" -H 'Content-Type: application/json' --data '{"host":"wireguard", "type":"A", "answer":"'"$public_ip"'", "ttl":"300"}'
curl --silent -X POST "$slack_webhook" --data-urlencode 'payload={"text": "VPN server moved to '"$public_ip"'"}'
EOF
```

## Credits

Thanks to github.com/SathyaBhat/folding-aws for nudging me to automate my VPN server's setup and github.com/jmhale/terraform-aws-wireguard for helping me understand how to work with Cloud Init/user-data templates.

TODO: harden nftables: https://xdeb.org/post/2019/09/26/setting-up-a-server-firewall-with-nftables-that-support-wireguard-vpn/
