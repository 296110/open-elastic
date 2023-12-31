# CollectD Install Script

CollectD is a daemon which collects system and application performance metrics periodically and provides mechanisms to store the values in a variety of ways. This folder contains a script for installing [CollectD](https://collectd.org/).

This script has been tested on the following operating systems:

* Ubuntu 18.04
* Ubuntu 20.04
* CentOS 7
* Amazon Linux 2

## Quick start

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "install-collectd" \
  --repo "https://github.com/gruntwork-io/terraform-aws-elk" \
  --tag "v0.0.1"
```

We recommend running this module as part of a [Packer](https://www.packer.io/) template to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html).
