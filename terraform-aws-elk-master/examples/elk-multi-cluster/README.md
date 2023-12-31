# ELK Multi Cluster Example

In this example we demonstrate how to use our ELK modules to run an ELK stack consisting of several Auto Scaling Groups (ASGs)
that each run an ELK component (Kibana, Logstash, Elasticsearch...)


## What resources does this example deploy?

  1. An [elasticsearch-cluster](/modules/elasticsearch-cluster)
  1. A [kibana-cluster](/modules/kibana-cluster)
  1. A [logstash-cluster](/modules/logstash-cluster)
  1. A simple _app-server_ where we will run [filebeat](/modules/run-filebeat) and [CollectD](/modules/run-collectd)
  1. An ASG of one node <sup>[1](#whyjustonenode)</sup> running [elastalert](/modules/elastalert).
  1. An [Application Load Balancer](https://github.com/gruntwork-io/terraform-aws-load-balancer)
  1. A CloudWatch Log Group
  1. A CloudWatch Log Stream
  1. An S3 bucket for Cloudtrail logs
  1. An SNS topic - this is where ElastAlert will send our sample alert notifications.
  1. A Route53 Alias Record that will attach a subdomain name to an existing HostedZone.

## How do I get this example deployed?

  1. `git clone` this repo to your computer.
  1. You'll need to build AMIs of each of the ELK components referenced above and note down the `ami_id`s of the AMIs
  you've built. Look [here](/examples/elk-amis) for detailed guides on how to build the AMIs
  1. Install [Terraform](https://www.terraform.io/).
  1. (Optional) If configuring end to end encryption, you will need to:
        1. Generate a JVM keystore containing self signed certificates for use with ELK. Refer to the
           [generate-key-stores module in
           terraform-aws-kafka](https://github.com/gruntwork-io/terraform-aws-kafka/tree/main/modules/generate-key-stores) for a
           helper script to do this.
        1. Create AWS Secrets Manager entries for the Kibana and Logstash authentication passwords to access
           Elasticsearch. You will also need to set the `elasticsearch_password_for_logstash_secrets_manager_arn` and
           `elasticsearch_password_for_kibana_secrets_manager_arn` input vars.
  1. Open `vars.tf`, set the environment variables specified at the top of the file, and fill in any other variables that
     don't have a default, including putting the AMI Ids you noted down from above into the `[elk-component]_ami_id` variables.
  1. Run `terraform init`.
  1. Run `terraform apply`.

## Connecting to the cluster

- Once the cluster has successfully deployed, you should be able to see the main URL in the `alb_url`
output variable.
- To access the Kibana UI go to the URL provided in `alb_url` output variable. Your URL will look something like
this: `http://[SubdomainYouSet].[YourHostedZone]/`
- Elasticsearch will be accessible at: `http://[SubdomainYouSet].[YourHostedZone]:[elasticsearch_api_port(9200 by default)]`.

## Why deploy an ALB?

We deploy an ALB in order to simplify load balancing and routing between the nodes of the ELK cluster.  The ALB also helps
solve the issues around resource discovery in a convenient and simple way.  The ALB only deals with HTTP and HTTPS
traffic. This is an important detail to keep in mind as ELK components that use custom (non-http) protocols, like
Filebeat, cannot use the ALB for load balancing or discovery.

## How we handle non-HTTP discovery?

Given the ALB's HTTP only limitation, we require a different solution for dealing with discovery for Filebeat, a component
which uses a custom protocol for sending messages to Elasticsearch.

### Why we don't use an NLB

A Network Load Balancer (NLB) was originally how we solved the load balancing and discovery problem for _all_ ELK cluster
members. In fact, we tried only using an ALB without having to deploy an ALB.  Unfortunately we ran into some NLB Limitations
which precluded its use:
  - The NLB can't [route back requests to the same node that initiated the request](https://forums.aws.amazon.com/thread.jspa?threadID=265344).
  - An internal NLB in a private subnet can't be accessed from a peered VPC. This limitation doesn't affect __this__ example
  code because we are deploying a public NLB into a public subnet and not trying to access it from a peered VPC. In a
  production environment, this is no longer the case and makes it impossible to access the NLB.

### Auto-discovery

#### Current implementation

To work around the issues we encountered we created a simple [auto-discovery](/modules/auto-discovery) module that will
use AWS APIs to get the IP addresses of all instances matching a given tag. The current implementation of this script
will use a regular expression (passed as a parameter when invoking the script) to find/replace newly discovered IP addresses
in a config file (also passed as a parameter). Finally, the script will automatically restart whatever application it is
performing discovery for (the application's systemd service name is also passed as a script parameter)

**LIMITATION:** Unfortunately, the approach described above can't work if the application for which we are doing discovery
is configured to do full SSL certificate verification (ie: hostname verification). Since our approach looks up randomly
assigned IP addresses, there's no way we could generate an SSL certificate that encapsulates all of the possible IP addresses
that may be found. For this reason, we have to disable SSL hostname verification when using [auto-discovery](/modules/auto-discovery).

#### Future Improvements

To work around the limitation described above, we will be introducing updates to the [auto-discovery](/modules/auto-discovery) module
that will update local `/etc/hosts` or run a local instance of [Dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html)
in order to make seamless updates to the DNS instead of updating an application's config file and then needing to restart
that application.

<a name="whyjustonenode">1</a>: We are using an ASG here even though we will only be running one node because we want the
ASG to handle automatically restarting our EC2 instance if it ever crashes.
