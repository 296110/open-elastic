# Elasticsearch AMI

This folder shows an example of how to use [Packer](https://www.packer.io/) to create [Amazon Machine 
Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) or Docker Images that have 
[Elasticsearch](https://www.elastic.co/) and its dependencies installed on top of:
 
1. Ubuntu 18.04
1. Ubuntu 20.04
1. Amazon Linux 2

## Quick start

To build the Elasticsearch AMI:

1. `git clone` this repo to your computer.
1. Install [Packer](https://www.packer.io/).
1. Configure your AWS credentials using one of the [options supported by the AWS 
   SDK](http://docs.aws.amazon.com/sdk-for-java/v1/developer-guide/credentials.html). Usually, the easiest option is to
   set the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables.
1. Update the `variables` section of the `elasticsearch-ami.json` Packer template to specify the AWS region and Elasticsearch
   version you wish to use.
1. To build an Ubuntu AMI for Elasticsearch: `packer build -only=elasticsearch-ami-ubuntu elasticsearch.json`.
1. To build an Amazon Linux AMI for Elasticsearch: `packer build -only=elasticsearch-ami-amazon-linux elasticsearch.json`.

## Local testing

The Packer template in this example folder can build not only AMIs, but also Docker images for local testing. This is
convenient for testing out the various scripts in the `modules` folder without having to wait for an AMI to build and
a bunch of EC2 Instances to boot up. 

1. To build an Ubuntu Docker image for Elasticsearch: `packer build -only=elasticsearch-docker-ubuntu elasticsearch.json`.
1. To build an Amazon Linux Docker image for Elasticsearch: `packer build -only=elasticsearch-docker-amazon-linux elasticsearch.json`.

For more information see [elasticsearch-docker](/examples/elasticsearch-docker).

## SSL AMIs and Docker Images

Our packer template also demonstrates how to build an AMI with [Elasticsearch](https://www.elastic.co/) installed
and configured to use the [ReadonlyREST](https://github.com/sscarduzio/elasticsearch-readonlyrest-plugin) plugin to 
enable Elasticsearch to be accessed over HTTPS. 
If you don't override the default, the AMIs will  be built in AWS region: `us-east-1`. You can override this by adding
`-var use_ssl=[the-region-you-need]` to the commands below.

1. To build an Ubuntu AMI with SSL enabled for Elasticsearch: 
  `packer build -var use_ssl=true -only=elasticsearch-ami-ubuntu elasticsearch.json`.
1. To build an Amazon Linux AMI with SSL enabled for Elasticsearch: 
  `packer build -var use_ssl=true -only=elasticsearch-ami-amazon-linux elasticsearch.json`.
