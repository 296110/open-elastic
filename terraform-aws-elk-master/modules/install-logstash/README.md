# Logstash Install Script

Logstash is an open source data collection engine with real-time pipelining capabilities. Logstash can dynamically unify data from disparate sources and normalize the data into destinations of your choice. This folder contains a script for installing [Logstash](https://www.elastic.co/products/logstash).

This script has been tested on the following operating systems:

* Ubuntu 18.04
* Ubuntu 20.04
* CentOS 7
* Amazon Linux 2

## Quick start

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "install-logstash" \
  --repo "https://github.com/gruntwork-io/terraform-aws-elk" \
  --tag "v0.0.1" # change to latest release version
```

We recommend running this module as part of a [Packer](https://www.packer.io/) template to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) (see [packer-template](/examples/elk-amis/logstash/logstash.json) for fully-working sample code).
