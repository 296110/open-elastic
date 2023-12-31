# ELK Example AMIs

This folder contains example [Packer](https://www.packer.io/) templates for building each of our ELK AMIs.

## How we organized the code

Each folder in this directory represents an example packer template for building a particular ELK component (eg: [Kibana](/examples/elk-amis/kibana))

1. **[Elasticsearch](/examples/elk-amis/elasticsearch)**
1. **[Logstash](/examples/elk-amis/logstash)**
1. **[Kibana](/examples/elk-amis/kibana)**
1. **[Application Server](/examples/elk-amis/app-server)**

## Building AMIs configured for SSL

Each of the examples above define a `use_ssl` user variable that when set to `true` will build an AMI of a particular ELK component
wired to enable SSL encryption.

**NOTE** - Each example will look for all SSL artifacts (CA, certificate, certificate key) in `/examples/elk-amis/ssl`. If that folder
does not exist, then you will get an error when building the packer template.

**NOTE** - Logstash requires the certificate key to be encoded in PCS8 format while the other ELK applications require PCS12 format.

## Tools to aid with SSL certificate creation

We recommend using the [generate-key-stores](https://github.com/gruntwork-io/terraform-aws-kafka/tree/main/modules/generate-key-stores) script
in [terraform-aws-kafka](https://github.com/gruntwork-io/terraform-aws-kafka/). This script has been expanded to conveniently be able to generate
all of the SSL artifacts required for launching an ELK cluster with end-to-end SSL encryption enabled.

For a Go code example of how we use the [generate-key-stores](https://github.com/gruntwork-io/terraform-aws-kafka/tree/main/modules/generate-key-stores) script, please see [test_helpers_keystore.go](https://github.com/gruntwork-io/terraform-aws-elk/blob/main/test/test_helpers_keystore.go)
