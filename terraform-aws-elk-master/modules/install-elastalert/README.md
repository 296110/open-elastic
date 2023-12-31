# Elastalert Install Script

This folder contains a script for installing [Elastalert](https://github.com/Yelp/elastalert). Use this script along
with the [run-elastalert script](/modules/run-elastalert) to run Elastalert alongside Elasticsearch. See the run-elastalert script for more information about ElastAlert.

This script has been tested on the following operating systems:

* Ubuntu 18.04
* Ubuntu 20.04
* Amazon Linux 2
* CentOS 7

There is a good chance it will work on other flavors of Debian, CentOS, and RHEL as well.

## Quick start

This module depends on [bash-commons](https://github.com/gruntwork-io/bash-commons), so you must install that project
first as documented in its README.

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "install-elastalert" \
  --repo "https://github.com/gruntwork-io/package-elastalert" \
  --tag "<VERSION>"
```

Checkout the [releases](https://github.com/gruntwork-io/terraform-aws-elk/releases) to find the latest version.

The `install-elastalert` script will install ElastAlert and the [run-elastalert script](/modules/run-elastalert). You
can execute the `run-elastalert` script when the server is booting to start ElastAlert.


## Command line Arguments

Run `install-elastalert --help` to see all available arguments, or just check out the [install-elastalert source 
code](/modules/install-elastalert/install.sh).
