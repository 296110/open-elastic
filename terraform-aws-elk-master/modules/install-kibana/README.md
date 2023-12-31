# Kibana Install Script

This folder contains a script for installing [Kibana](https://www.elastic.co/products/kibana).


This script has been tested on the following operating systems:

* Amazon Linux 2
* Ubuntu

## Quick start

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "install-kibana" \
  --repo "https://github.com/gruntwork-io/terraform-aws-elk" \
  --tag "v0.0.1"
```

We recommend running this module as part of a [Packer](https://www.packer.io/) template to create an [Amazon Machine 
Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html)
You can then deploy the AMI using the [kibana-cluster module](/modules/kibana-cluster) (see the
`TODO` and `TODO` examples for fully-working sample code).