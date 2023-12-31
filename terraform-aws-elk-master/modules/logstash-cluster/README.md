# Logstash Cluster

This folder contains a [Terraform](https://www.terraform.io/) module to deploy an [Logstash](
https://www.elastic.co/products/logstash) cluster in [AWS](https://aws.amazon.com/) on top of an Auto Scaling Group. 
The idea is to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
that has Logstash installed using the [install-logstash](/modules/install-logstash) modules.

## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "logstash_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/logstash-cluster?ref=<VERSION>"

  # Specify the ID of the Logstash AMI. You should build this using the scripts in the install-logstash module
  ami_id = "ami-abcd1234"
  
  # Configure and start Logstash during boot. 
  user_data = <<-EOF
              #!/bin/bash
              /usr/share/logstash/bin/run-logstash
              EOF
  
  # ... See vars.tf for the other parameters you must define for the logstash-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the logstash-cluster module. The double slash (`//`) is 
  intentional and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `ami_id`: Use this parameter to specify the ID of an Logstash [Amazon Machine Image 
  (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) to deploy on each server in the cluster. You
  should install Logstash on this AMI using the following [install-logstash](/modules/install-logstash) module.
  
* `user_data`: Use this parameter to specify a [User 
  Data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#user-data-shell-scripts) script that each
  server will run during boot. This is where you can use the [run-logstash](/modules/run-logstash).

You can find the other parameters in [vars.tf](vars.tf).

Check out the [examples folder](/examples) for fully-working sample code. 

## What's included in this module?

This module creates the following:

* [Auto Scaling Group](#auto-scaling-group)
* [Load Balancer](#load-balancer)
* [Security Group](#security-group)

### Auto Scaling Group

This module runs Logstash on top of an [Auto Scaling Group (ASG)](https://aws.amazon.com/autoscaling/). Typically,
you should run the ASG with multiple Instances spread across multiple [Availability 
Zones](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). Each of the EC2
Instances should be running an AMI that has Logstash installed via the [install-logstash](/modules/install-logstash) script.
You pass in the ID of the AMI to run using the `ami_id` input parameter.

### Load Balancer

We use a [Network Load Balancer](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/introduction.html) (1)
so that we can perform ongoing health checks on each Logstash node, and (2) so that Filebeat can access the Logstash cluster
via a single endpoint which will forward to a live Kibana endpoint at random.

### Security Group

Each EC2 Instance in the ASG has a Security Group that allows minimal connectivity:
 
* All outbound requests
* Inbound SSH access from the CIDR blocks and security groups you specify

The ID of the security group is exported as an output variable, which you can use with the [logstash-security-group-rules](/modules/logstash-security-group-rules) module to open up all the ports necessary for Logstash.

Check out the [Security section](#security) for more details. 

## How do you roll out updates?

If you want to deploy a new version of Logstash across the cluster, the best way to do that is to:

1. Rolling deploy:
    1. Build a new AMI.
    1. Set the `ami_id` parameter to the ID of the new AMI.
    1. Run `terraform apply`.
    1. Because the [logstash-cluster module](/modules/logstash-cluster) uses the Gruntwork [server-group](
       https://github.com/gruntwork-io/terraform-aws-asg/tree/main/modules/server-group) modules under the hood, running 
       `terraform apply` will automatically perform a zero-downtime rolling deployment. Specifically, one EC2 Instance at a time will be terminated, a new EC2 Instance will spawn in its place, and only once the new EC2 Instance passes the Load
       Balancer Health Checks will the next EC2 Instance be rolled out. 
       
       Note that there will be a brief period of time during which EC2 Instances based on both the old `ami_id` and
       new `ami_id` will be running.  

1. New cluster: 
    1. Build a new AMI.
    1. Create a totally new ASG using the `logstash-cluster` module with the `ami_id` set to the new AMI, but all 
       other parameters the same as the old cluster.
    1. Wait for all the nodes in the new ASG to join the cluster and catch up on replication.
    1. Remove each of the nodes from the old cluster.
    1. Remove the old ASG by removing that `logstash-cluster` module from your code.

## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)

### Security groups

This module attaches a security group to each EC2 Instance that allows inbound requests as follows:

* **SSH**: For the SSH port (default: 22), you can use the `allowed_ssh_cidr_blocks` parameter to control the list of   
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access. You can use 
  the `allowed_inbound_ssh_security_group_ids` parameter to control the list of source Security Groups that will be 
  allowed access.

  The ID of the security group is exported as an output variable, which you can use with the [logstash-security-group-rules](/modules/logstash-security-group-rules) modules to open up all the ports necessary for Logstash and the respective. 

### SSH access

You can associate an [EC2 Key Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) with each
of the EC2 Instances in this cluster by specifying the Key Pair's name in the `ssh_key_name` variable. If you don't
want to associate a Key Pair with these servers, set `ssh_key_name` to an empty string.
