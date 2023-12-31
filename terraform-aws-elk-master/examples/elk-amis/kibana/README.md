# Kibana AMI

In this example we will use our [Packer](https://www.packer.io/) template to create both an Amazon Linux and Ubuntu AMI image as well
as Docker images with [Kibana](/modules/install-kibana) installed and configured.

## Quick start

To build the AMIs:

1. Install [Packer](https://www.packer.io/)
1. Set your [GitHub access token](https://help.github.com/articles/creating-an-access-token-for-command-line-use/) as
   the environment variable `GITHUB_OAUTH_TOKEN`.
1. Run `packer build kibana-ami.json`

## SSL AMIs

Our packer template also demonstrates how to build an AMI with Kibana installed and configured to connect to 
Elasticsearch with SSL encryption enabled. If you don't override the default, the AMIs will be built in AWS 
region: `us-east-1`. You can override this by adding `-var use_ssl=[the-region-you-need]` to the commands below.

1. To build an Ubuntu AMI image with SSL enabled for Kibana: 
  `packer build -var use_ssl=true -only=kibana-ami-ubuntu kibana.json`.
1. To build an Amazon Linux AMI image with SSL enabled for Kibana: 
  `packer build -var use_ssl=true -only=kibana-ami-amazon-linux kibana.json`.

**NOTE** When building SSL AMIs, the packer template assumes that all of the necessary SSL artifacts are in `/examples/elk-amis/ssl`. 
If that folder does not exist, then you will get an error when building the packer template. You can either copy your
SSL artifacts (certificates, keys, CAs) into `/examples/elk-amis/ssl` or, you can update `kibana.json` template to 
use a different location for sourcing the SSL artifacts.

**NOTE** - See [Tools to aid with SSL certificate creation](/examples/elk-amis#tools-to-aid-with-ssl-certificate-creation) for instructions
on how to build all of the SSL artifacts you would need to run an end-to-end SSL encrypted ELK stack.

