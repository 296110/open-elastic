# ELK All in One AMIs

This folder shows an example of how to use [Packer](https://www.packer.io/) to create [Amazon Machine 
Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) that have all of the ELK components
(Elasticsearch, Kibana, Logstash and Filebeat) installed on top of:
 
1. Ubuntu 18.04
1. Ubuntu 20.04
1. Amazon Linux 2

## Quick start

To build the ELK All-in-One AMI:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `all-in-one.json` Packer template to specify the AWS region and Elasticsearch
   version you wish to use.
1. To build an Ubuntu AMI for Elasticsearch: `packer build -only=elk-aio-ami-ubuntu all-in-one.json`.
1. To build an Amazon Linux AMI for Elasticsearch: `packer build -only=elk-aio-ami-amazon-linux all-in-one.json`.
