# CollectD Run Script

This folder contains a script for configuring and running [CollectD](https://collectd.org/) on an [AWS](https://aws.amazon.com/) EC2 instance. This script has been tested on the following operating systems:

* Ubuntu 18.04
* Ubuntu 20.04
* CentOS 7
* Amazon Linux 2

## Quick start

This module depends on [bash-commons](https://github.com/gruntwork-io/bash-commons), so you must install that project
first as documented in its README.

The easiest way to use this module is with the [Gruntwork Installer](https://github.com/gruntwork-io/gruntwork-installer):

```bash
gruntwork-install \
  --module-name "run-collectd" \
  --repo "https://github.com/gruntwork-io/terraform-aws-elk" \
  --tag "<VERSION>"
```  

Checkout the [releases](https://github.com/gruntwork-io/terraform-aws-elk/releases) to find the latest version.

```ini
<Plugin write_http>
	<Node "logstash">
		URL "<__LOGSTASH_URL__>"
		Format "JSON"
	</Node>
</Plugin>
```  

Now you can fill in those placeholders and start CollectD by executing the `run-collectd` script as follows:

```bash
run-collectd --auto-fill "<__LOGSTASH_URL__>=http://s4JSnd.gruntwork-sandbox.com"
```

This will:

1. Replace all instances of the text `<__LOGSTASH_URL__>` in the CollectD config file with the path to the log file that CollectD will read from
1. Start CollectD on the local node.

We recommend using the `run-collectd` command as part of [User Data](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html#user-data-shell-scripts), so that it executes when the EC2 Instance is first booting. 

See the [examples folder](../../examples/elk-multi-cluster) for fully working sample code.


## Command line Arguments

Run `run-collectd --help` to see all available arguments.

```
Usage: run-collectd [options]

This script can be used to configure and run CollectD. This script has been tested with Ubuntu 20.04 + 18.04, CentOS 7 and Amazon Linux 2.

Options:

  --config-file                         The path to the config file for CollectD.
  --auto-fill KEY=VALUE                 Search the CollectD config file for KEY and replace it with VALUE. May be repeated.
  --help                                Show this help text and exit.

Example:

  run-collectd --auto-fill '<__LOGSTASH_URL__>=http://s4JSnd.gruntwork-sandbox.com'
```
