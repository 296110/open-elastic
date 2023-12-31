# Elasticsearch Single Cluster Example

This folder shows an example of Terraform code that uses the 
[elasticsearch-cluster](/modules/elasticsearch-cluster) 
module to deploy a [Elasticsearch](https://www.elastic.co/) cluster in [AWS](https://aws.amazon.com/). The cluster 
consists of one Auto Scaling Group (ASG) that runs all Elasticsearch nodes. We use the [ReadonlyREST](https://github.com/sscarduzio/elasticsearch-readonlyrest-plugin) plugin along with
a self signed certificate in a [Java Key Store](https://docs.oracle.com/cd/E19830-01/819-4712/ablqw/index.html) to enable Elasticsearch nodes to use SSL for API requests/responses.

This example also deploys a Load Balancer in front of the Elasticsearch cluster using the [load-balancer
module](https://github.com/gruntwork-io/terraform-aws-load-balancer).

You will need to create an [Amazon Machine Image (AMI)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 
that has Elasticsearch installed along with the [ReadonlyREST](https://github.com/sscarduzio/elasticsearch-readonlyrest-plugin) plugin, which you can do using the [elasticsearch-ami 
example](/examples/elk-amis/elasticsearch#ssl-amis-and-docker-images)). 

To see an example of the Elasticsearch services deployed in separate clusters, see the [elk-multi-cluster
example](/examples/elk-multi-cluster). For 
more info on how the Elasticsearch cluster works, check out the 
[elasticsearch-cluster](/modules/elasticsearch-cluster) documentation.

To deploy an Elasticsearch Cluster:

1. `git clone` this repo to your computer.
1. Build an Elasticsearch AMI. See the [elasticsearch-ami example](/examples/elk-amis/elasticsearch) 
   documentation for instructions. Make sure to note down the ID of the AMI.
1. Install [Terraform](https://www.terraform.io/).
1. Open `vars.tf`, set the environment variables specified at the top of the file, and fill in any other variables that
   don't have a default, including putting your AMI ID into the `ami_id` variable.
1. Run `terraform init`.
1. Run `terraform apply`.

## Connecting to the cluster

Please see instructions [here](/modules/elasticsearch-cluster#connecting-via-the-rest-api)
