# ELK Single Cluster Example

In this example we demonstrate a way in which the entire ELK stack can be run on just one ASG by colocating
all of the ELK components into the same AMI.  While this is not the recommended approach for running a production ELK setup, it can be useful for non-production environments.

This example also deploys a Load Balancer in front of the entire cluster using the [load-balancer
module](https://github.com/gruntwork-io/terraform-aws-load-balancer).

## What resources are does this example deploy?

1. A single _all in one server_ behind an ASG where we run 
    [elasticsearch](/modules/run-elasticsearch), [kibana](/modules/run-kibana), [logstash](/modules/run-logstash),
    [filebeat](/modules/run-filebeat) and [CollectD](/modules/run-collectd)
1. An [Application Load Balancer](https://github.com/gruntwork-io/terraform-aws-load-balancer)
1. A CloudWatch Log Group
1. A CloudWatch Log Stream
1. An S3 bucket for Cloudtrail logs

You will need to create [Amazon Machine Images (AMIs)](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/AMIs.html) 
that have all of the ELK components installed. You can do this using: 
- [ELK all-in-one AMI example](/examples/elk-amis/all-in-one)


## How do I get this example deployed?

1. `git clone` this repo to your computer.
1. Build the ELK all-in-one AMI. See the [all-in-one ami example](/examples/elk-amis/all-in-one) 
   documentation for instructions. Make sure to note down the ID of the AMI.
1. Install [Terraform](https://www.terraform.io/).
1. Open `vars.tf`, set the environment variables specified at the top of the file, and fill in any other variables that
   don't have a default, including putting your AMI ID into the `ami_id` variable.
1. Run `terraform init`.
1. Run `terraform apply`.

## Connecting to the cluster

- Once the cluster has successfully deployed, you should be able to see the DNS name of the load balancer in the `alb_dns_name`
output variable.
- To access the Kibana UI go to: `http://[lb_dns_name]:[kibana_port]/`. Your URL will look something like this: `http://exampleescluster-alb-77641507.us-east-1.elb.amazonaws.com:5601/`
- Elasticsearch will be accessible at: `http://[alb_dns_name]:[elasticsearch_api_port]/`. Your URL will look something like this: `http://exampleescluster-alb-77641507.us-east-1.elb.amazonaws.com:9200/`
- All components of the ELK stack communicate through the deployed load balancer, irrespective of the fact that they're all running on the same machine.