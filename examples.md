# Examples

Example configurations that can be used for this project. The various samples should be combined to get a well functioning service. I personally recommend combining the basic VPN, DNS caching, ad-blocking and DNS records to make this a good experience for your end users. All configurations should be added to the `terraform.tfvars` file. Please see the [official documentation](https://learn.hashicorp.com/tutorials/terraform/aws-variables#from-a-file) for more information about this file.

### Basic VPN

```
region                        = "us-east-1"
allowed_availability_zone_ids = ["use1-az1", "use1-az2", "use1-az3"]
ssh_key_id                    = "my-aws-key"
instance_type                 = "t3.nano"
asg_min_size                  = 1
asg_desired_size              = 1
spot_max_price                = "0.0018"
ssh_allow_ip_range            = ["0.0.0.0/0"]
wg_server_listen_addr         = "10.0.1.1"
wg_server_private_key_path    = "/wireguard/key-1"
wg_client_pub_keys = [
  { name = "phone-1", ip_addr = "10.0.1.2/32", pub_key = "xxxxxxxx" },
  { name = "laptop-1", ip_addr = "10.0.1.3/32", pub_key = "xxxxxxxx" },
]
```

### DNS caching

Install `dnsmasq`, a lightweight DNS caching server and update the firewall rules to allow DNS queries against the service. This also sets upstream DNS servers ([Google DNS](https://developers.google.com/speed/public-dns/) and [Cloudflare DNS](https://www.cloudflare.com/dns/)) for `dnsmasq`. Do note that these are not privacy preserving services and you should find more appropriate servers for your use case. Do factor in latency, accuracy and reliability of the upstream DNS servers when choosing them.

```
post_provisioning_steps = <<EOF
apt-get -qy install dnsmasq
sed -i -e '$ a no-resolv' \
  -e '$ a interface=wg0' \
  -e '$ a server=8.8.8.8' \
  -e '$ a server=8.8.4.4' \
  -e '$ a server=1.1.1.1' \
  -e '$ a server=1.0.0.1' \
  /etc/dnsmasq.conf
systemctl enable dnsmasq
systemctl restart dnsmasq
nft add element inet filter udp_accepted { domain }
sed -i 's/set udp_accepted.*/set udp_accepted { type inet_service; elements = { domain, $vpn_port } }/' /etc/nftables.conf
EOF
```

### DNS caching + Ad-blocking

The same as the previous step, along with a well known DNS adblock list configured for blocking most pesky ads on the VPN network

```
post_provisioning_steps = <<EOF
apt-get -qy install dnsmasq
curl --silent https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts -o /usr/local/etc/adblock_hosts
sed -i -e '$ a no-resolv' \
  -e '$ a interface=wg0' \
  -e '$ a addn-hosts=/usr/local/etc/adblock_hosts' \
  -e '$ a server=8.8.8.8' \
  -e '$ a server=8.8.4.4' \
  -e '$ a server=1.1.1.1' \
  -e '$ a server=1.0.0.1' \
  /etc/dnsmasq.conf
systemctl enable dnsmasq
systemctl restart dnsmasq
nft add element inet filter udp_accepted { domain }
sed -i 's/set udp_accepted.*/set udp_accepted { type inet_service; elements = { domain, $vpn_port } }/' /etc/nftables.conf

( crontab -l 2>/dev/null; echo "5 0 * * * curl --silent https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-porn/hosts -o /usr/local/etc/adblock_hosts" ) | crontab -
EOF
```

### Slack Webhook notification

If you have a Slack team/workspace and wish to be notified whenever a new VPN server is provisioned, use these following steps. Please see [this](https://slack.com/intl/en-in/help/articles/115005265063-Incoming-webhooks-for-Slack) for more information about how to set up and generate Slack Incoming Webhook links. This example assumes that the webhook link is stored in the AWS SSM Parameter Store under `/wireguard/slack`

```
post_provisioning_steps = <<EOF
public_ip=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
slack_webhook=$(aws ssm get-parameters --output text --region $aws_region --names "/wireguard/slack" --with-decryption --query 'Parameters[*].Value')
curl --silent -X POST "$slack_webhook" --data-urlencode 'payload={"text": "VPN server moved to '"$public_ip"'"}'
EOF
```
Note - the `template_file` resource in `terraform/asg.tf` ensures that the `$aws_region` value is correctly replaced in the `post_provisioning_steps` block of shell script.

### Update DNS record - Name.com/generic API

If your DNS provider provides a REST API that you can query to update a DNS record with basic authentication, you can use a snippet like this to update the DNS record as soon as a new instance is provisioned. This example assumes that the secret required to authenticate is stored in the AWS SSM Parameter Store under `/wireguard/dns` and an `A` DNS record `vpn.example.xyz` points to the public IP of the current instance.

```
post_provisioning_steps = <<EOF
public_ip=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
name_com_api=$(aws ssm get-parameters --output text --region $aws_region --names "/wireguard/dns" --with-decryption --query 'Parameters[*].Value')
curl --silent -X PUT https://api.name.com/v4/domains/example.xyz/records/1234 -u "$name_com_api" -H 'Content-Type: application/json' --data '{"host":"vpn", "type":"A", "answer":"'"$public_ip"'", "ttl":"300"}'
EOF
```

### Update DNS record - AWS Route53

See [this example](https://oliverhelm.me/sys-admin/updating-aws-dns-records-from-cli) for updating the DNS record. Updating DNS records is a little more invovled for AWS Route53 due to the nature of the API. Also, the IAM permissions of the instance will need to be updated to allow API calls to Route53 from the instance. Alternatively, you can generate a dedicated IAM user with the appropriate IAM permissions, store the access key/secret pair to SSM's Parameter store and consume them in the post processing script.

```
post_provisioning_steps = <<EOF
public_ip=$(curl --silent http://169.254.169.254/latest/meta-data/public-ipv4)
cat > /tmp/vpn_r53_update.json <<A_Record_JSON
{
  "Comment": "VPN update in Route 53 to $public_ip",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "vpn",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": [{"Value":\"$public_ip\"}]
      }
    }
  ]
}
A_Record_JSON
aws route53 change-resource-record-sets --hosted-zone-id <zone-id> --change-batch file:///tmp/vpn_r53_update.json
rm /tmp/vpn_r53_update.json
EOF
```

### Cycle instance without downtime

Ideally, this is how you should change instances in the ASG pool. If you have a recent AWS CLI installation, and prefer to use the native ASG Instance refresh process

```
aws autoscaling start-instance-refresh --auto-scaling-group-name wireguard_asg --preferences InstanceWarmup=180
```

If you don't have a recent AWS CLI installation, or wish to have more control over the process, use the following steps

```
aws autoscaling set-desired-capacity --auto-scaling-group-name wireguard_asg --desired-capacity 2
# Wait for the new instance to be provisioned and be ready
aws autoscaling set-desired-capacity --auto-scaling-group-name wireguard_asg --desired-capacity 1
```

### Cycle instance with downtime

Sometimes, it might be necessary to terminate the instance in the ASG pool before creating a new one. This will cause a small amount of downtime for clients of the VPN, for the amount of time it takes to provision a new instance in the pool and the DNS record changes to be propagated to all clients.

```
aws autoscaling terminate-instance-in-auto-scaling-group --no-should-decrement-desired-capacity --instance-id $(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName=='wireguard_asg'].InstanceId" --output text)
```

Or

```
aws ec2 terminate-instances --instance-ids $(aws autoscaling describe-auto-scaling-instances --query "AutoScalingInstances[?AutoScalingGroupName=='wireguard_asg'].InstanceId" --output text)
```

### Integration with Tasker

TODO
