# Thrift VPN

## NOTE

This project uses an older version of Debian as it's base operating system, which now receives infrequent security updates and support. If you need a VPN for security reasons, this project will no longer meet your goals. I may get time to update the project in the future, but I do not advise using this project till further notice. 

Any PRs updating the project to current Debian versions are welcome. 

---

Use Packer and Terraform to spin up a super cheap Wireguard VPN instance.

This project creates an auto scaling group in an AWS VPC and provisions a Wireguard server on it with spot instances.

## Goals

Make it easy to host a VPN server on AWS with a very tiny footprint that is relatively up to date. It should periodically handle security updates automatically, and also keep changing IP addresses to help better preserve privacy of the users. This does not aim to prevent smart services and apps from tracking your data, users are often signed in already to them. It only aims to prevent local ISPs from snooping (or worse, injecting) on our traffic.

## Requirements

* An [AWS account](https://aws.amazon.com/premiumsupport/knowledge-center/create-and-activate-aws-account/).
* A local [terraform installation](https://learn.hashicorp.com/tutorials/terraform/install-cli). This project has been tested with Terraform v 0.15, tests with newer versions appreciated. The minimum required version of terraform in this repository is 0.14 currently.
* A local [packer installation](https://learn.hashicorp.com/tutorials/packer/getting-started-install).
* Optional, but recommended: A local [Wireguard installation](https://www.wireguard.com/install/) to generate the key pairs (identities) for the various devices in the VPN.
* Optional, but recommended: An account with a DNS service provider that provides an API to update DNS records and a DNS domain/zone hosted with them.

## How to Use

* Use [these steps](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html#Using_CreateAccessKey) to create user keys for a user in your AWS account. This user will be used by Packer and Terraform to configure the VPN setup. Follow any one of [these](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html) guides to set up the AWS environment on your local machine.
* Generate the server's pub/private key on your local machine with `wg genkey | tee privatekey | wg pubkey > publickey`.
* Also generate pub/private key pairs for the various clients that should be associated with the VPN. If you do not wish to install wireguard locally, you could generate these key pairs with the client apps across various platforms, or `ssh` in to the server once it is provisioned and generate the key pairs for your clients.
* Choose an AWS region from [this page](https://aws.amazon.com/about-aws/global-infrastructure/regions_az/). Pick one that is reasonably close to you (in terms of internet speeds/latency), or fits your requirements for using a VPN.
* Create your SSH key pair with [these steps](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) and store them securely on your local machine.
* Follow [these](https://docs.aws.amazon.com/systems-manager/latest/userguide/sysman-paramstore-su-create.html) steps to create an AWS SSM Parameter (type `SecureString`) and store the private key for the wireguard server in it. Note: The secure string will require you to choose a AWS KMS Key to encrypt/decrypt the parameter, it is ok to use the default key generated for your account/region.
* Choose an instance type from [this page](https://aws.amazon.com/ec2/instance-types/). A General Purpose instance with low configurations is sufficient for this project. This project has currently been tested with `t3a.nano`, `t2.micro` and `t4g.micro` instance sizes.
* Visit the AWS Spot Instances [pricing page](https://aws.amazon.com/ec2/spot/pricing/) and find the current prices for the chosen instance type and region. Add a few cents to the pricing to ensure that the spot request is fulfilled.
* *Bootstrap Only*: Change to the `packer` directory. Create a packer base image with `packer build -var instance_type=<chosen-instance-type> -var region=<your-region> packer/debian_wireguard.json`. If you wish to use a Graviton instance, also pass `-var cpu_arch=arm64`. This step is only necessary for the very first time, an automated monthly build takes over once Terraform completes it's thing in the next step.
* Change to the `terraform` directory. Create a `terraform.tfvars` file with the following minimum variables included in it: `region`, `allowed_availability_zone_ids`, `ssh_key_id`, `asg_min_size`, `asg_desired_size`, `spot_max_price`, `wg_server_listen_addr`, `wg_server_private_key_path` and `wg_client_pub_keys`.
* Run `terraform plan` and inspect the output.
* Run `terraform apply`, ensure that the changes match up with the plan output, and approve creation of all resources.
* Once the apply completes, inspect the AWS console and get the public internet address of the Wireguard server's machine. Follow [these steps](https://www.wireguard.com/quickstart/) to configure the client device (as appropriate). Verify that you can connect to the VPN server.

## Example

The bare minimum `terraform.tfvars` file required to set up a VPN service is:

```
region                        = "us-east-1"
allowed_availability_zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
ssh_key_id                    = "my-aws-key"
asg_min_size                  = 1
asg_desired_size              = 1
spot_max_price                = "0.0012"
ssh_allow_ip_range            = ["0.0.0.0/0"]
wg_server_listen_addr         = "10.0.1.1"
wg_server_private_key_path    = "/wireguard/key-1"
wg_client_pub_keys = [
  { name = "phone-1", ip_addr = "10.0.1.2/32", pub_key = "xxxxxxxx" },
  { name = "laptop-1", ip_addr = "10.0.1.3/32", pub_key = "xxxxxxxx" },
]
```

Please see [examples](./examples.md) for a more detailed set of code snippets to use a functioning VPN server.

## Upgrades

### Terraform 0.12 -> 0.15

Terraform has been upgraded from `0.12` to `0.15` in this repository, which requires a change in the way provider versions are specified. I've updated this repository to reflect the changes. After fetching the latest Terraform binary, please run a `terraform init` and then a `terraform apply` to ensure that your statefile is updated to match the newer requirements. If you run into any issues with the `init` command, you might need to fetch the intermediate versions (0.13 and 0.14) and run the `0.13upgrade` command on 0.13, and do the init+apply dance at each step.

### Terraform 0.15 -> 1.0

Terraform version 1.0 is a continuation of the 0.15 series, and hence, everything should just work if you're on any 0.15 version. Tests with 1.0.5 are succeeding.

### Packer 1.6.0 -> 1.7.2

No-op update, should just work.

## Credits

Thanks to https://github.com/SathyaBhat/folding-aws/ for nudging me to automate my VPN server's setup and https://github.com/jmhale/terraform-aws-wireguard for helping me understand how to work with Cloud Init/user-data templates.

## Contributing

This source code is provided under the [MIT License](./LICENSE), feel free to customise and re-use as per terms of the license. To contribute to this project, please follow the standard forking+pull request [model](https://guides.github.com/activities/forking/).

## Issues

> If a newbie has a bad time, it's a bug - Jordan Sissel (author of Logstash)

If you experience any problems while using this project, please search online first to see if anyone else has run into similar issues. This project cobbles together various open source projects (Debian, Wireguard, Terraform, Packer) and popular platforms (Amazon Web Services) and hence, most problems can be explained by how these projects work (or, do not) with each other. If you find a solution to the problem, please feel free to raise a pull request and help fix the underlying cause for everyone else. This could be as simple as a fix in an example/documentation, or a more involved bug fix in the codebase. If you can't find a solution, feel free to raise an issue against this project. I work on this as a side project, and hence, will endeavour to respond to pull requests and issues within a reasonable amount of time.

## Tests

The project currently involves manual testing every time a new change is made. I modify the codebase, apply the changes to my existing Terraform infrastructure (1 `t3a.nano` instance running out of an AWS region), ensure that it completes cleanly. After this, I kill the existing instance, wait for the ASG to provision a new instance, and then re-connect all my VPN clients to ensure that the basics work alright. I verify that [ifconfig.me](https://ifconfig.me) returns the public IP address of the new instance.

Eventually, I wish to automate some parts of this testing, and maybe an end-to-end test that validates the behaviour of the various components.

## Notes

The ASG currently sets a max lifetime period of 1 month, at which time, a new instance will be provisioned. This will only change the IP address of your internet traffic, this will not ensure a newly patched/more secure instance being provisioned. Do consider periodically running the packer builds to use newer security patches and base images.

## References

* [Blog post](https://ninad.pundaliks.in/blog/2020/12/thrift-vpn/) about the various choices that I took to pick this combination of components
* [VPN is not a security measure](https://madaidans-insecurities.github.io/vpns.html) - A quick read that covers the various aspects of security/privacythat a VPN actually provides, and what parts do you need to consider yourself

## TODO

- [x] harden nftables: https://xdeb.org/post/2019/09/26/setting-up-a-server-firewall-with-nftables-that-support-wireguard-vpn/
- [x] Break up post processing examples into composable components
- [x] AWS Route53 example for DNS update
- [x] Example for DNS adblocking via the VPN
- [x] Example command to recycle instance(s) in the ASG
- [ ] Tasker integration examples
- [ ] Make documentation and project better for non-DevOps/SRE/SysAdmin folks
- [ ] Add tests
- [x] Automate AMI building to give a reasonably recent, patched base instance. [Reference](https://aws.amazon.com/blogs/mt/creating-packer-images-using-system-manager-automation/)
- [x] Test with ARM/Graviton systems on AWS
- [ ] Performance tests and tuning
- [ ] Figure out how to do DDoS protection at netdev filter correctly
- [ ] Choosing a good OpenNIC upstream for the DNS server
