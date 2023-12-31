# ElastAlert

This folder contains a [Terraform](https://www.terraform.io/) module to deploy [ElastAlert](https://github.com/Yelp/elastalert)
on top of an Auto Scaling Group of exactly one EC2 instance.

The idea is to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
that has ElastAlert installed using the [install-elastalert](/modules/install-elastalert) module.

## How do you use this module?

This folder defines a [Terraform module](https://www.terraform.io/docs/modules/usage.html), which you can use in your
code by adding a `module` configuration and setting its `source` parameter to URL of this folder:

```hcl
module "elasticsearch_cluster" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elastalert?ref=<VERSION>"

  # Specify the ID of the ElastAlert AMI. You should build this using the scripts in the install-elastalert.
  ami_id = "ami-abcd1234"

  # Configure and start Elasticsearch during boot.
  user_data = <<-EOF
              #!/bin/bash
              /usr/share/elasticsearch/bin/run-elastalert...
              EOF

  # ... See vars.tf for the other parameters you must define for the elasticsearch-cluster module
}
```

For a concrete example of deploying ElastAlert see [elk-multi-cluster](/examples/elk-multi-cluster)
