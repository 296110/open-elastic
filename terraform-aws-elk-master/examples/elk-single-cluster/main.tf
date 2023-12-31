terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE OUR AWS CONNECTION
# ---------------------------------------------------------------------------------------------------------------------

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------------------------------------------------
# PROVISION ELK CLUSTER
# This will provision an ASG that runs nodes that host all components of the ELK stack on each instance.
# ---------------------------------------------------------------------------------------------------------------------

module "elk_cluster" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/elasticsearch-cluster?ref=v0.0.1"
  source = "../../modules/elasticsearch-cluster"

  elasticsearch_cluster_name = var.elk_cluster_name
  cluster_size               = var.elasticsearch_cluster_size

  ami_id        = var.ami_id
  aws_region    = var.aws_region
  instance_type = var.elk_instance_type

  user_data = data.template_file.user_data.rendered

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default_subnets.ids

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  alowable_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_cidr_blocks = ["0.0.0.0/0"]

  key_name = var.key_name
  target_group_arns = [
    module.es_target_group.target_group_arn,
    module.kibana_target_group.target_group_arn,
    module.logstash_target_group_collectd.target_group_arn,
  ]

  tags = {
    Environment = "development"
    Role        = "Cluster"
  }
}

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    # Elasticsearch
    cluster_name     = var.elk_cluster_name
    network_host     = "0.0.0.0" # IP address of the network interface that elasticsearch will bind to.
    jvm_xms          = "4g"
    jvm_xmx          = "4g"
    min_master_nodes = 1
    aws_region       = var.aws_region

    # Logstash
    beats_port         = var.filebeat_port
    collectd_port      = var.collectd_port
    elasticsearch_host = module.alb.alb_dns_name
    elasticsearch_port = var.elasticsearch_api_port
    bucket             = aws_s3_bucket.s3_test_bucket.bucket
    output_path        = var.cloudtrail_dest_log_path
    log_group          = aws_cloudwatch_log_group.cloudwatch_test_group.name
    region             = var.aws_region

    # Kibana
    server_name          = "${var.elk_cluster_name}-kibana"
    elasticsearch_url    = "http://${module.alb.alb_dns_name}:${var.elasticsearch_api_port}"
    kibana_ui_port       = var.kibana_ui_port
    config_file_template = "/tmp/config/kibana.yml" # This is where you copied the templated config file when creating the AMI

    # Filebeat
    log_path    = var.filebeat_log_path
    log_content = "TODO: I don't think we need this"
    tag         = "Role=Cluster"
    port        = var.filebeat_port

    # CollectD
    logstash_url = "http://${module.alb.alb_dns_name}:${var.collectd_port}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE SECURITY GROUP RULES FOR LOGSTASH AND KIBANA
# This controls which ports are exposed and who can connect to them
# ---------------------------------------------------------------------------------------------------------------------

module "logstash_security_group_rules" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/logstash-security-group-rules?ref=v0.0.1"
  source = "../../modules/logstash-security-group-rules"

  security_group_id = module.elk_cluster.security_group_id
  beats_port        = var.filebeat_port
  collectd_port     = var.collectd_port

  # To keep this example simple, we allow these client-facing ports to be accessed from any IP. In a production
  # deployment, you may want to lock these down just to trusted servers.
  beats_port_cidr_blocks = ["0.0.0.0/0"]

  collectd_port_cidr_blocks = ["0.0.0.0/0"]
}

module "kibana_security_group_rules" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/logstash-security-group-rules?ref=v0.0.1"
  source = "../../modules/kibana-security-group-rules"

  security_group_id         = module.elk_cluster.security_group_id
  kibana_ui_port            = var.kibana_ui_port
  allow_ui_from_cidr_blocks = ["0.0.0.0/0"]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET FOR TESTING PURPOSES ONLY
# We upload a simple text file into this bucket. The Logstash S3 input plugin will grab every line of every file in
# this bucket and send it to the configured output. In production this won't be needed and the cloudtrail bucket should
# be used directly.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "s3_test_bucket" {
  bucket = "${lower(var.elk_cluster_name)}-s3-logs"

  # In a production environment you definitely don't want to destroy your backup bucket as that will remove all your
  # logs.I would strongly recommend using 'prevent_destroy' to stop terraform from destroying this resource.
  # Also 'force_destroy' is only here for testing and SHOULD NOT be used in a production environment
  force_destroy = true
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH LOGGROUP FOR TESTING PURPOSES ONLY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudwatch_test_group" {
  name = "${var.elk_cluster_name}-lg"
}

resource "aws_cloudwatch_log_stream" "cloudwatch_test_stream" {
  name           = "${var.elk_cluster_name}-ls"
  log_group_name = aws_cloudwatch_log_group.cloudwatch_test_group.name
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICIES TO THE SERVER GROUP IAM ROLE SO THAT LOGSTASH COULD WRITE TO S3
# AND CLOUDWATCH
# ---------------------------------------------------------------------------------------------------------------------

module "logstash_iam_roles" {
  source      = "../../modules/logstash-iam-policies"
  iam_role_id = module.elk_cluster.iam_role_id
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY TO THE SERVER GROUP IAM ROLE SO THAT THE AUTO DISCOVERY SCRIPT CAN RETRIVE ASG INFORMATION
# ---------------------------------------------------------------------------------------------------------------------

module "beats_iam_roles" {
  source      = "../../modules/beats-iam-policies"
  iam_role_id = module.elk_cluster.iam_role_id
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ALB TO ROUTE REQUESTS TO THE SERVERS
# We also use it for health checks during deployments
# ---------------------------------------------------------------------------------------------------------------------

module "alb" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/alb?ref=v0.14.1"

  alb_name         = var.alb_name
  environment_name = "example"
  aws_account_id   = data.aws_caller_identity.current.account_id

  is_internal_alb = false

  ssl_policy = "ELBSecurityPolicy-2016-08"

  allow_inbound_from_security_group_ids     = [module.elk_cluster.security_group_id]
  allow_inbound_from_security_group_ids_num = 1

  http_listener_ports = [80, var.collectd_port, var.elasticsearch_api_port]

  aws_region     = var.aws_region
  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnets.default_subnets.ids
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE TARGET GROUPS FOR THE LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

module "es_target_group" {
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group     = true
  http_listener_arns     = [module.alb.http_listener_arns[tostring(var.elasticsearch_api_port)]]
  num_http_listener_arns = 1
  protocol               = "HTTP"

  port              = var.elasticsearch_api_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.elk_cluster_name}-es-lb-tg"
  vpc_id            = data.aws_vpc.default.id
}

module "logstash_target_group_collectd" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/load-balancer-alb-target-group?ref=v0.0.1"
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group     = true
  http_listener_arns     = [module.alb.http_listener_arns[tostring(var.collectd_port)]]
  num_http_listener_arns = 1
  protocol               = "HTTP"

  port              = var.collectd_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.elk_cluster_name}-cd-ls-lb-tg"
  vpc_id            = data.aws_vpc.default.id
}

module "kibana_target_group" {
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group     = true
  http_listener_arns     = [module.alb.http_listener_arns["80"]]
  num_http_listener_arns = 1
  protocol               = "HTTP"

  port              = var.kibana_ui_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.elk_cluster_name}-lb-tg"
  vpc_id            = data.aws_vpc.default.id
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THIS EXAMPLE IN THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we deploy it in the default VPC and subnets. In real-world usage, you'll probably want
# to use a custom VPC and private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_caller_identity" "current" {}
