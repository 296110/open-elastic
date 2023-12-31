# Elasticsearch Cluster

This folder contains a [Terraform](https://www.terraform.io/) module to deploy an [Elasticsearch](
https://www.elastic.co/products/elasticsearch) cluster in [AWS](https://aws.amazon.com/) on top of an Auto Scaling Group. 
The idea is to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
that has Elasticsearch installed using the [install-elasticsearch](/modules/install-elasticsearch) module.

In a non-production setting, you can install Elasticsearch tools such as [Kibana](https://www.elastic.co/products/kibana)
and [ElastAlert](https://github.com/Yelp/elastalert) on the same AMI. In a production setting, Elasticsearch should 
be the sole service running on each Elasticsearch node.

## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "elasticsearch_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elasticsearch-cluster?ref=<VERSION>"

  # Specify the ID of the Elasticsearch AMI. You should build this using the scripts in the install-elasticsearch (and 
  # in a non-production setting, the install-logstash, instgall-kibana, and install-elastalert modules).
  ami_id = "ami-abcd1234"
  
  # Configure and start Elasticsearch during boot. 
  user_data = <<-EOF
              #!/bin/bash
              /usr/share/elasticsearch/bin/run-elasticsearch --cluster-name dev --cluster-tag ClusterName=dev
              EOF
  
  # ... See variables.tf for the other parameters you must define for the elasticsearch-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the elasticsearch-cluster module. The double slash (`//`) is 
  intentional and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `ami_id`: Use this parameter to specify the ID of an Elasticsearch [Amazon Machine Image 
  (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) to deploy on each server in the cluster. You
  should install Elasticsearch and optionally Elasticsearch tools on this AMI using the following
  modules:

  - [install-elasticsearch](/modules/install-elasticsearch): Required.
  - [install-elastalert](/modules/install-elastalert): Optional. Enables alerts and notifications
  - [install-kibana](/modules/install-kibana): Optional. UI to explore Elasticsearch data. 
  - [install-logstash](/modules/install-logstash): Optional. Used to send Elasticsearch's own logs to Elasticsearch itself.

  In a production setting, your AMI should only run Elasticsearch, and Elasticsearch tools should be built on a separate
  AMI. In a dev-only environment where parity to production doesn't matter, colocating Elasticsearch and its tools is ok.
  
* `user_data`: Use this parameter to specify a [User 
  Data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#user-data-shell-scripts) script that each
  server will run during boot. This is where you can use the [run-elasticsearch](/modules/run-elasticsearch) and, if
  applicable, [run-elastalert](/modules/run-elastalert), [run-kibana](/modules/run-kibana), and 
  [run-logstash](/modules/run-logstash) scripts to configure and run Elasticsearch and its tools. 

You can find the other parameters in [variables.tf](variables.tf).

Check out the [examples folder](/examples) for fully-working sample code. 

## How do you connect to the Elasticsearch cluster?

### Connecting to Elasticsearch via Official Elasticsearch Clients

The preferred way to connect to Elasticsearch is to use one of the [official Elasticsearch clients](
https://www.elastic.co/guide/en/elasticsearch/client/index.html). All official Elasticsearch clients are designed to 
discover multiple Elasticsearch nodes and distribute reuqests across the various nodes. 

Therefore, using a Load Balancer to talk to Elasticsearch APIs (e.g., via an SDK) is NOT recommended, so you will need
to get the IPs of the individual nodes and connect to them directly. Since those nodes run in an Auto Scaling Group (ASG)
where servers can be added/replaced/removed at any time, you can't get their IP addresses from Terraform. Instead, you'll
need to look up the IPs using the AWS APIs. 

The easiest way to do that is to use the AWS SDK to look up the servers using EC2 Tags. Each server deployed by
the `elasticsearch-cluster` module has its `Name` and `aws:autoscaling:groupName` tag set to the value you pass in via the
`cluster_name` parameter. You can also specify custom tags via the `tags` parameter. You can use the AWS SDK to find
the IPs of all servers with those tags. 

For example, using the [AWS CLI](https://aws.amazon.com/cli/), you can get the IPs for servers in `us-east-1` with 
the tag `Name=elasticsearch-example` as follows:

```bash
aws ec2 describe-instances \
    --region "us-east-1" \
    --filter \
      "Name=tag:Name,Values=elasticsearch-example" \
      "Name=instance-state-name,Values=running"
```

This will return a bunch of JSON that contains the IPs of the servers. You can then use the [Elasticsearch client](https://www.elastic.co/guide/en/elasticsearch/client/index.html) for your programming language to connect 
to these IPs. 

### Connecting via the REST API

Elasticsearch exposes a RESTful API that you can directly access using `curl` or any other programming language feature
that makes HTTP requests. 

## What's included in this module?

This module creates the following:

* [Auto Scaling Group](#auto-scaling-group)
* [Load Balancer](#load-balancer)
* [Security Group](#security-group)
* [IAM Role and Permissions](#iam-role-and-permissions)

### What's Not Included

* [EBS Volumes](#ebs-volumes)

### Auto Scaling Group

This module runs Elasticsearch on top of an [Auto Scaling Group (ASG)](https://aws.amazon.com/autoscaling/). Typically,
you should run the ASG with multiple Instances spread across multiple [Availability 
Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). Each of the EC2
Instances should be running an AMI that has Elasticsearch and optional Elasticsearch tools installed via the 
[install-elasticsearch](/modules/install-elasticsearch), [install-elastalert](/modules/install-elastalert), [install-kibana](
/modules/install-kibana), and [install-logstash](/modules/install-logstash) scripts. You pass in the ID of the AMI to
run using the `ami_id` input parameter.

### Load Balancer

We use a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) (1)
so that we can perform ongoing health checks on each Elasticsearch node, and (2) so that Kibana can be accessed via a 
single endpoint which will forward to a live Kibana endpoint at random.

Note that we do not need a Load Balancer to distribute traffic to Elasticsearch because all the  [official
Elasticsearch clients](https://www.elastic.co/guide/en/elasticsearch/client/index.html) are designed to discover all
Elasticsearch nodes and distribute requests across the cluster. Using a Load Balancer for this reason would duplicate
functionality Elasticsearch clients already give us.

### Security Group

Each EC2 Instance in the ASG has a Security Group that allows minimal connectivity:
 
* All outbound requests
* Inbound SSH access from the CIDR blocks and security groups you specify

The ID of the security group is exported as an output variable, which you can use with the [elasticsearch-security-group-rules](/modules/elasticsearch-security-group-rules), [elastalert-security-group-rules](/modules/elastalert-security-group-rules),
[kibana-security-group-rules](/modules/kibana-security-group-rules), and [logstash-security-group-rules](
/modules/logstash-security-group-rules)  modules to open up all the ports necessary for Elasticsearch and the respective
Elasticsearch tools. 

Check out the [Security section](#security) for more details. 

### IAM Role and Permissions

Each EC2 Instance in the ASG has an [IAM Role](http://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) attached. 
The IAM Role ARN and ID are exported as output variables if you need to add additional permissions. 

### EBS Volumes

Note that we do not use [EBS Volumes](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSVolumes.html), which are
AWS's ultra-low-latency network-attached storage. Instead, per [Elasticsearch docs on AWS Best Practices](
https://www.elastic.co/guide/en/elasticsearch/plugins/current/cloud-aws-best-practices.html), we exclusively use [Instance
Stores](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html).

Instance Stores have the major disadvantage that they do not survive the termination of an EC2 Instance. That is, when
an EC2 Instance dies, all the data on an Instance Store dies with it and is unrecoverable. But Elasticsearch already has
built in support for [replica shards](https://www.elastic.co/guide/en/elasticsearch/guide/current/replica-shards.html),
so we already have redundancy available to us if an EC2 Instance should fail. 

This enables us to take advantage of the benefits of Instance Stores, which are that they are significantly faster
because I/O traffic is now all local. By contrast, I/O traffic with EBS Volumes must traverse the (admittedly ultra low-
latency) network and are therefore much slower.

## How do you roll out updates?

If you want to deploy a new version of Elasticsearch across the cluster, the best way to do that is to:

1. Rolling deploy:
    1. Build a new AMI.
    1. Set the `ami_id` parameter to the ID of the new AMI.
    1. Run `terraform apply`.
    1. Because the [elasticsearch-cluster module](/modules/elasticsearch-cluster) uses the Gruntwork [server-group](
       https://github.com/gruntwork-io/terraform-aws-asg/tree/main/modules/server-group) modules under the hood, running 
       `terraform apply` will automatically perform a zero-downtime rolling deployment. Specifically, one EC2 Instance at a time will be terminated, a new EC2 Instance will spawn in its place, and only once the new EC2 Instance passes the Load
       Balancer Health Checks will the next EC2 Instance be rolled out. 
       
       Note that there will be a brief period of time during which EC2 Instances based on both the old `ami_id` and
       new `ami_id` will be running. [Rolling upgrades docs](https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-upgrades.html)
       suggest that this is acceptable for Elasticsearch version 5.6 and greater.

       TODO: Add support for automatically disabling shard allocation and performing a synced flush on an Elasticsearch
       node prior to terminating it ([docs](https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-upgrades.html)).    

1. New cluster: 
    1. Build a new AMI.
    1. Create a totally new ASG using the `elasticsearch-cluster` module with the `ami_id` set to the new AMI, but all 
       other parameters the same as the old cluster.
    1. Wait for all the nodes in the new ASG to join the cluster and catch up on replication.
    1. Remove each of the nodes from the old cluster.
    1. Remove the old ASG by removing that `elasticsearch-cluster` module from your code.

## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Dedicated instances](#dedicated-instances)
1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)


### Encryption in transit

Elasticsearch can encrypt all of its network traffic. TODO: Should we recommend using X-Pack (official solution, but
paid), an Nginx Reverse Proxy, a custom Elasticsearch plugin, or something else?

### Encryption at rest

#### EC2 Instance Storage

The EC2 Instances in the cluster store their data in an [EC2 Instance Store](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html), which does not have native suport for
encryption (unlike [EBS Volume Encryption](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/EBSEncryption.html)). 

TODO: Should we implement encryption at rest uising the technique described at https://aws.amazon.com/blogs/security/how-to-protect-data-at-rest-with-amazon-ec2-instance-store-encryption/?

#### Elasticsearch Keystore

Some Elasticsearch settings may contain secrets and should be encrypted. You can use the [Elasticsearch Keystore](
https://www.elastic.co/guide/en/elasticsearch/reference/current/secure-settings.html) for such settings. The 
`elasticsearch.keystore` is created automatically upon boot of each node, and is available for use as described in the 
docs.

### Dedicated instances

If you wish to use dedicated instances, you can set the `tenancy` parameter to `"dedicated"` in this module. 

### Security groups

This module attaches a security group to each EC2 Instance that allows inbound requests as follows:

* **SSH**: For the SSH port (default: 22), you can use the `allowed_ssh_cidr_blocks` parameter to control the list of   
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access. You can use 
  the `allowed_inbound_ssh_security_group_ids` parameter to control the list of source Security Groups that will be 
  allowed access.
  
  The ID of the security group is exported as an output variable, which you can use with the [elasticsearch-security-group-rules](/modules/elasticsearch-security-group-rules), [elastalert-security-group-rules](/modules/elastalert-security-group-rules),
  [kibana-security-group-rules](/modules/kibana-security-group-rules), and [logstash-security-group-rules](
  /modules/logstash-security-group-rules)  modules to open up all the ports necessary for Elasticsearch and the respective
  Elasticsearch tools. 
  
  

### SSH access

You can associate an [EC2 Key Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) with each
of the EC2 Instances in this cluster by specifying the Key Pair's name in the `ssh_key_name` variable. If you don't
want to associate a Key Pair with these servers, set `ssh_key_name` to an empty string.
