![Terraform Version](https://img.shields.io/badge/tf-%3E%3D1.0.0-blue.svg)

:warning: **As of February, 2022, we are putting this repo on hold and will not be investing in further improvements to it.** :warning:

This is because:

- Maintaining the code for a complicated, distributed, sharded, stateful system like the ELK stack is very time consuming.
- We’ve had very little customer usage / interest in a self-managed ELK offering, so it does not make sense to continue to make a large investment in it.

Therefore, for the time being, if you need to use ELK, we strongly recommend using the [Gruntwork Service Catalog Amazon Elasticsearch Service](https://github.com/gruntwork-io/terraform-aws-service-catalog/tree/main/modules/data-stores/elasticsearch).

If you have questions or concerns, please contact us at support@gruntwork.io.

# ELK AWS Module

This repo contains modules for deploying and managing the [ELK Stack](https://www.elastic.co/elk-stack).

![Elasticsearch architecture](/_docs/elk-architecture.png?raw=true)

## Quick start

If you want to quickly spin up the entire ELK stack installed on a single machine, you can run the [single server](/examples/elk-single-cluster)
example. This is a simple example that shows you how all the components in this module work together. If you want a more production-like deployment
with separate clusters for each component of ELK, look at [ELK Deployment](/examples/elk-multi-cluster) example.

### What's in this repo

This repo has the following folder structure:

* [modules](/modules): This folder contains the main implementation code for this Module, broken down into multiple standalone submodules.
* [examples](/examples): This folder contains examples of how to use the submodules.
* [test](/test): Automated tests for the submodules and examples.

The main modules are:

- * [install-elasticsearch](/modules/install-elasticsearch): Install Elasticsearch.
  * [run-elasticsearch](/modules/run-elasticsearch): Start Elasticsearch.
  * [elasticsearch-cluster](/modules/elasticsearch-cluster): A Terraform module to run a cluster of Elasticsearch nodes with ENIs
    and EBS Volumes attached, zero-downtime deployment, and auto-recovery of failed nodes.

- * [install-kibana](/modules/install-kibana): Install Kibana, a web-based data visualizer for Elasticsearch.

  * [run-kibana](/modules/run-kibana): Start Kibana.

  * [kibana-cluster](/modules/kibana-cluster): A Terraform module to run a cluster of Kibana nodes with ENIs
    and EBS Volumes attached, zero-downtime deployment, and auto-recovery of failed nodes.

- * [install-logstash](/modules/install-logstash): Install Logstash, a server based data collection
  and processing engine.

  * [run-logstash](/modules/run-logstash): Start Logstash.

  * [logstash-cluster](/modules/logstash-cluster): A Terraform module to run a cluster of Logstash nodes with ENIs
    and EBS Volumes attached, zero-downtime deployment, and auto-recovery of failed nodes.

- * [install-filebeat](/modules/install-filebeat): Install Filebeat, a lightweight log file shipper

  * [run-filebeat](/modules/run-filebeat): Start Filebeat.

- * [install-collectd](/modules/install-collectd): Install CollectD, a system and application metrics collection tool.

  * [run-collectd](/modules/run-collectd): Start CollectD.

The supporting modules are:

* [elasticsearch-cluster-backup](/modules/elasticsearch-cluster-backup): A Terraform module to deploy a Lambda function that
  takes snapshots of the Elasticsearch cluster on a configurable schedule and stores those snapshots in S3.

* [elasticsearch-cluster-restore](/modules/elasticsearch-cluster-backup): A Terraform module to deploy a Lambda function that
  restores a cluster from saved snapshots.

- * [install-elastalert](/modules/install-elastalert): Install [ElastAlert](https://github.com/Yelp/elastalert), an alerting framework
  for anomalies and patterns in data stored in Elasticsearch.

  * [run-elastalert](/modules/run-elastalert): Start ElastAlert.

* [elasticsearch-iam-policies](/modules/elasticsearch-iam-policies): A Terraform module to configure IAM permissions used by Elasticsearch.

* [elasticsearch-security-group-rules](/modules/elasticsearch-security-group-rules): A Terraform module to setup security group rules for Elasticsearch.

* [logstash-iam-policies](/modules/logstash-iam-policies): A Terraform module to configure IAM permissions used by Logstash.

* [logstash-security-group-rules](/modules/logstash-security-group-rules): A Terraform module to setup security group rules for Logstash.

* [kibana-security-group-rules](/modules/kibana-security-group-rules): A Terraform module to setup security group rules for Kibana.

* [load-balancer-alb-target-group](/modules/load-balancer-alb-target-group): A Terraform module to configure [ALB](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/main/modules/alb)
  target groups used by Elasticsearch, Logstash and Kibana clusters.

Click on each module above to see its documentation.

#### What's a Module?

A Module is a canonical, reusable, best-practices definition for how to run a single piece of infrastructure, such 
as a database or server cluster. Each Module is written using a combination of [Terraform](https://www.terraform.io/) 
and scripts (mostly bash) and include automated tests, documentation, and examples. It is maintained both by the open 
source community and companies that provide commercial support. 

Instead of figuring out the details of how to run a piece of infrastructure from scratch, you can reuse 
existing code that has been proven in production. And instead of maintaining all that infrastructure code yourself, 
you can leverage the work of the Module community to pick up infrastructure improvements through
a version number bump.
 
### Who maintains this Module?

This Module is maintained by [Gruntwork](http://www.gruntwork.io/). If you're looking for help or commercial 
support, send an email to [modules@gruntwork.io](mailto:modules@gruntwork.io?Subject=Couchbase%20for%20AWS%20Module). 
Gruntwork can help with:

* Setup, customization, and support for this Module.
* Modules for other types of infrastructure, such as VPCs, Docker clusters, databases, and continuous integration.
* Modules that meet compliance requirements, such as HIPAA.
* Consulting & Training on AWS, Terraform, and DevOps.

### How do I contribute to this Module?

Contributions are very welcome! Check out the 
[Contribution Guidelines](https://github.com/gruntwork-io/terraform-aws-elk/tree/main/CONTRIBUTING.md) for instructions.

### How is this Module versioned?

This Module follows the principles of [Semantic Versioning](http://semver.org/). You can find each new release, 
along with the changelog, in the [Releases Page](../../releases). 

During initial development, the major version will be 0 (e.g., `0.x.y`), which indicates the code does not yet have a 
stable API. Once we hit `1.0.0`, we will make every effort to maintain a backwards compatible API and use the MAJOR, 
MINOR, and PATCH versions on each release to indicate any incompatibilities. 

### License

Please see [LICENSE](https://github.com/gruntwork-io/terraform-aws-couchbase/tree/main/LICENSE) for how the code in this repo is licensed.

Copyright &copy; 2018 Gruntwork, Inc.
