# Filebeat AMI

This folder shows an example of how to use the [install-filebeat](/modules/install-filebeat) module with [Packer](https://www.packer.io/) to create [Amazon Machine Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) that have [Filebeat](https://www.elastic.co/guide/en/beats/filebeat) and its dependencies installed on top of:
 
* Ubuntu 18.04
* Ubuntu 20.04
* CentOS 7
* Amazon Linux 2

## Quick start

To build the Filebeat AMI:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `filebeat.json` Packer template to specify the AWS region you wish to use.
1. To build an Ubuntu AMI for Filebeat: `packer build -only=filebeat-ami-ubuntu filebeat.json`.
1. To build an CentOS AMI for Filebeat: `packer build -only=filebeat-ami-centos filebeat.json`.
1. To build an Amazon Linux AMI for Filebeat: `packer build -only=filebeat-ami-amazon-linux filebeat.json`.

When the build finishes, it will output the IDs of the new AMIs.

## Local testing

The Packer template in this example folder can build not only AMIs, but also Docker images for local testing. 
This is convenient for testing out the various scripts in the `modules` folder without having to wait for an AMI to 
build and a bunch of EC2 Instances to boot up. 

## SSL AMIs

Our packer template also demonstrates how to build an AMI with CollectD installed and configured to connect to 
Elasticsearch with SSL encryption enabled. If you don't override the default, the AMIs will be built in AWS 
region: `us-east-1`. You can override this by adding `-var use_ssl=[the-region-you-need]` to the commands below.

1. To build an Ubuntu AMI image with SSL enabled for CollectD: 
  `packer build -var use_ssl=true -only=collectd-ami-ubuntu collectd.json`.
1. To build an Amazon Linux AMI image with SSL enabled for CollectD: 
  `packer build -var use_ssl=true -only=collectd-ami-amazon-linux collectd.json`.

**NOTE** When building SSL AMIs, the packer template assumes that all of the necessary SSL artifacts are in `/examples/elk-amis/ssl`. 
If that folder does not exist, then you will get an error when building the packer template. You can either copy your
SSL artifacts (certificates, keys, CAs) into `/examples/elk-amis/ssl` or, you can update `collectd.json` template to 
use a different location for sourcing the SSL artifacts.

**NOTE** - See [Tools to aid with SSL certificate creation](/examples/elk-amis#tools-to-aid-with-ssl-certificate-creation) for instructions
on how to build all of the SSL artifacts you would need to run an end-to-end SSL encrypted ELK stack.

