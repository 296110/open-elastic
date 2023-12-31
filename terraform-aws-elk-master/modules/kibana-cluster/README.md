# Kibana Cluster

This folder contains a [Terraform](https://www.terraform.io/) module to deploy a [Kibana](
https://www.elastic.co/products/kibana) cluster in [AWS](https://aws.amazon.com/) on top of an Auto Scaling Group. 
The idea is to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
that has Kibana installed using the [install-kibana](/modules/install-kibana) and [run-kibana](/modules/run-kibana) modules.

In a non-production setting, you can install other Elastic tools such as [Elasticsearch](https://www.elastic.co/products/elasticsearch)
and [ElastAlert](https://github.com/Yelp/elastalert) on the same AMI. In a production setting, Kibana should 
be the sole service running on each Kibana node.

## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "kibana_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/kibana-cluster?ref=<VERSION>"

  # Specify the ID of the Kibana AMI. You should build this using the scripts in the install-kibana (and 
  # in a non-production setting, the install-logstash, install-elasticsearch, and install-elastalert modules).
  ami_id = "ami-abcd1234"
  
  # Configure and start Kibana during boot. 
  user_data = <<-EOF
              #!/bin/bash
              /usr/share/elasticsearch/bin/run-kibana
              EOF
  
  # ... See vars.tf for the other parameters you must define for the elasticsearch-cluster module
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of the kibana-cluster module. The double slash (`//`) is 
  intentional and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `ami_id`: Use this parameter to specify the ID of an Kibana [Amazon Machine Image 
  (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) to deploy on each server in the cluster. You
  should install Kibana on this AMI using the following
  modules:

  - [install-kibana](/modules/install-kibana): Required.
  - [install-elastalert](/modules/install-elastalert): Optional. Enables alerts and notifications
  - [install-logstash](/modules/install-logstash): Optional. Used to send Elasticsearch's own logs to Elasticsearch itself.

  In a production setting, your AMI should only run Kibana, and Other Elasticsearch tools should be built on a separate
  AMI. In a dev-only environment where parity to production doesn't matter, colocating Kibana and other Elastic products is ok.
  
* `user_data`: Use this parameter to specify a [User 
  Data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#user-data-shell-scripts) script that each
  server will run during boot. This is where you can use the [run-kibana](/modules/run-kibana) and, if
  applicable, [run-elastalert](/modules/run-elastalert), and 
  [run-logstash](/modules/run-logstash) scripts to configure and run Kibana and its tools. 

You can find the other parameters in [variables.tf](variables.tf).

Check out the [examples folder](/examples) for fully-working sample code. 

## How do you connect to the Kibana cluster?

### Using a load balancer
If you deploy the Kibana cluster with a load balancer in front of it see: [ELK multi-cluster](/examples/elk-multi-cluster/README.md) Example
Then you can use the load balancer's DNS along with the `kibana_ui_port` that you specified in the `variables.tf` to form a URL like: `http://loadbalancer_dns:kibana_ui_port/` 
For example, your URL will likely look something like: `http://kibanaexample-lb-77641507.us-east-1.elb.amazonaws.com:5601/`

### Using the AWS Console UI
Without a load balancer to act as a single entry point, you will have to manually choose one of the IP addresses from the EC2 Instances 
that were deployed as part of the Auto Scaling Group. You can find the IP addresses of each EC2 Instance that was deployed as part of the Kibana cluster deployment by locating
those instances in the [AWS Console's Instance view](https://console.aws.amazon.com/ec2/).  Accessing the Kibana UI would require that
the IP address you use is either public, or accessible from your local network. The URL would look something like: `http://the.ip.address:kibana_ui_port/`

## How do you roll out updates?

If you want to deploy a new version of Kibana across the cluster, the best way to do that is to:

1. Rolling deploy:
    1. Build a new AMI.
    1. Set the `ami_id` parameter to the ID of the new AMI.
    1. Run `terraform apply`.
    1. Because the [kibana-cluster module](/modules/kibana-cluster) uses the Gruntwork [asg-rolling-deploy](
       https://github.com/gruntwork-io/terraform-aws-asg/tree/main/modules/asg-rolling-deploy) module under the hood, running 
       `terraform apply` will automatically perform a zero-downtime rolling deployment. Specifically, new EC2 Instances will spawned, and only once the new EC2 Instances pass the Load
       Balancer Health Checks will the existing Instances be terminated. 
       
       Note that there will be a brief period of time during which EC2 Instances based on both the old `ami_id` and
       new `ami_id` will be running. [Rolling upgrades docs](https://www.elastic.co/guide/en/elasticsearch/reference/current/rolling-upgrades.html)
       suggest that this is acceptable for Elasticsearch version 5.6 and greater.  

1. New cluster: 
    1. Build a new AMI.
    1. Create a totally new ASG using the `kibana-cluster` module with the `ami_id` set to the new AMI, but all 
       other parameters the same as the old cluster.
    1. Wait for all the nodes in the new ASG to start up and pass health checks.
    1. Remove each of the nodes from the old cluster.
    1. Remove the old ASG by removing that `kibana-cluster` module from your code.

# TODO TODO TODO BELOW HERE NEEDS TO CHECKED/IMPLEMENTED

## Security

Here are some of the main security considerations to keep in mind when using this module:

1. [Encryption in transit](#encryption-in-transit)
1. [Encryption at rest](#encryption-at-rest)
1. [Dedicated instances](#dedicated-instances)
1. [Security groups](#security-groups)
1. [SSH access](#ssh-access)


### Encryption in transit

Kibana can encrypt all of its network traffic. TODO: Should we recommend using X-Pack (official solution, but
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

# TODO TODO TODO ABOVE HERE NEEDS TO CHECKED/IMPLEMENTED

### Security groups

This module attaches a security group to each EC2 Instance that allows inbound requests as follows:

* **SSH**: For the SSH port (default: 22), you can use the `allowed_ssh_cidr_blocks` parameter to control the list of   
  [CIDR blocks](https://en.wikipedia.org/wiki/Classless_Inter-Domain_Routing) that will be allowed access. You can use 
  the `allowed_inbound_ssh_security_group_ids` parameter to control the list of source Security Groups that will be 
  allowed access.
  
  The ID of the security group is exported as an output variable, which you can use with the [kibana-security-group-rules](/modules/kibana-security-group-rules), 
  [elasticsearch-security-group-rules](/modules/elasticsearch-security-group-rules), [elastalert-security-group-rules](/modules/elastalert-security-group-rules),
  and [logstash-security-group-rules](/modules/logstash-security-group-rules) modules to open up all the ports necessary for Kibana and the respective
  Elasticsearch tools. 

### SSH access

You can associate an [EC2 Key Pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html) with each
of the EC2 Instances in this cluster by specifying the Key Pair's name in the `ssh_key_name` variable. If you don't
want to associate a Key Pair with these servers, set `ssh_key_name` to an empty string.
