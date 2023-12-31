# Filebeat Install Script

Filebeat monitors log directories or specific log files, tails the files, and forwards them either to Elasticsearch or to Logstash for indexing. This folder contains a script for installing [Filebeat](https://www.elastic.co/products/beats/filebeat).

This script has been tested on the following operating systems:

* Ubuntu 18.04
* Ubuntu 20.04
* CentOS 7
* Amazon Linux 2

## Quick start

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "install-filebeat" \
  --repo "https://github.com/gruntwork-io/terraform-aws-elk" \
  --tag "v0.0.1"
```

We recommend running this module as part of a [Packer](https://www.packer.io/) template to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html).
