# Logstash Security Group Rules Module

This folder contains a [Terraform](https://www.terraform.io/) module that defines the Security Group rules used by a 
[Logstash](https://www.elastic.co/products/logstash) cluster to control the traffic that is allowed to go in and out of the cluster. 
These rules are defined in a separate module so that you can add them to any existing Security Group. 

## Quick start

Let's say you want to deploy Logstash using the [logstash-cluster module](/modules/logstash-cluster): 

```hcl
module "logstash_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/logstash-cluster?ref=<VERSION>"

  # ... (other params omitted) ...
}
```

You can attach the Security Group rules to this cluster as follows:

```hcl
module "security_group_rules" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/logstash-security-group-rules?ref=<VERSION>"

  security_group_id = module.logstash_cluster.security_group_id

  beats_port_cidr_blocks         = ["0.0.0.0/0"]
  beats_port_security_groups     = ["sg-abcd1234"]
  num_beats_port_security_groups = 1

  # ... (other params omitted) ...
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of this module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `security_group_id`: Use this parameter to specify the ID of the security group to which the rules in this module
  should be added.

* `beats_port_cidr_blocks`, `beats_port_security_groups`, `num_beats_port_security_groups`: This shows an example of how to configure which IP address ranges and Security Groups are allowed to connect to the `beats` (e.g. `Filebeat`) port that port.

You can find the other parameters in [vars.tf](vars.tf).

Check out the [examples folder](/examples) for working sample code.

