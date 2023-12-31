# ElastAlert Security Group Rules Module

This folder contains a [Terraform](https://www.terraform.io/) module that defines the Security Group rules used by 
[ElastAlert](https://github.com/Yelp/elastalert) to control the traffic that is allowed to go in and out of the cluster. 
These rules are defined in a separate module so that you can add them to any existing Security Group. 

## Quick start

Let's say you want to deploy ElastAlert using the [elastalert module](/modules/elastalert): 

```hcl
module "elastalert_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elastalert?ref=<VERSION>"

  # ... (other params omitted) ...
}
```

You can attach the Security Group rules to this cluster as follows:

```hcl
module "elastalert_security_group_rules" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elastalert-security-group-rules?ref=<VERSION>"

  security_group_id = module.elasticsearch_cluster.security_group_id
  
  allow_ssh_from_cidr_blocks   = ["0.0.0.0/0"]  
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

* `rest_port_range_start`, `rest_port_range_end`, `rest_port_cidr_blocks`, `rest_port_security_groups`: This shows an
  example of how to configure which ports you're using for various Elasticsearch functionality, such as the REST port
  range, and which IP address ranges and Security Groups are allowed to connect to that port. Check out the [HTTP Settings
  documentation](https://www.elastic.co/guide/en/elasticsearch/reference/6.8/modules-http.html) to understand what ports
  Elasticsearch uses.
  
You can find the other parameters in [variables.tf](variables.tf).

Check out the [elk-multi-cluster example](/examples/elk-multi-cluster) for working sample code.

