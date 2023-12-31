# Load Balancer Target Group Module

This module can be used to create a [Target 
Group](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-target-groups.html) and
[Listener Rules](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/listener-update-rules.html) for
an Application Load Balancer created with the [alb module](https://github.com/gruntwork-io/terraform-aws-load-balancer/tree/main/modules/alb). 

The reason the `load-balancer-alb-target-group` module is separate is that you may wish to create multiple target groups 
for a single load balancer.

See the [examples folder](/examples) for fully working sample code.

## How do you use this module?

Imagine you've deployed ELK using the [elasticsearch-cluster](/modules/elasticsearch-cluster) and a Load Balancer
using the [load-balancer module](https://github.com/gruntwork-io/terraform-aws-load-balancer/):    

```hcl
module "elasticsearch" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork/terraform-aws-elk//modules/elasticsaearch-cluster?ref=<VERSION>"
  
  cluster_name = var.cluster_name
  
  health_check_type = "ELB"
  
  # ... (other params omitted) ...
}

module "alb" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-load-balancer/releases
  source = "github.com/gruntwork/terraform-aws-load-balancer//modules/alb?ref=<VERSION>"
  
  alb_name         = var.alb_name

  http_listener_ports = [9200]

  # ... (other params omitted) ...
}
``` 

Note the following:

* `http_listener_ports`: This tells the Load Balancer to listen for HTTP requests on port 9200.
  
To create Target Groups and Listener Rules for Elasticsearch, you need to use the
`load-balancer-alb-target-group` module as follows:

```hcl
module "elasticsearch_target_group" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork/terraform-aws-elk//modules/load-balancer-alb-target-group?ref=<VERSION>"

  target_group_name = "${var.elasticsearch_cluster_name}-es-tg"
  port              = var.elasticsearch_api_port
  health_check_path = "/"

  http_listener_arns      = [lookup(module.alb.http_listener_arns, var.elasticsearch_api_port, "")]
  num_http_listener_arns  = 1
  
  listener_rule_starting_priority = 100

  # If you are deploying a module based on a Server Group vs an ASG
  using_server_group      = true
  
  # HTTP or HTTPS depending on whether you are using SSL or not.
  protocol = var.alb_target_group_protocol
    
  # ... See vars.tf for the other parameters you must define for this module
}
```

Note the following:

* `asg_name`: Use this param to attach the Target Group to an Auto Scaling Group (ASG) used under the hood in the
  **Kibana** cluster so that each EC2 Instance automatically registers with the Target Group, goes 
  through health checks, and gets replaced if it is failing health checks. `asg_name` param is **only** used if
  `using_server_group` is `false`.

* `listener_arns`: Specify the ARN of the HTTP listener from the ALB. The Elasticsearch Target Group uses
  Elasticsearch's port (default 9200).
