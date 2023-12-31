# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ELASTICSEARCH CLUSTER WITH ALB
# This is an example of how to deploy an Elasticsearch cluster of 3 nodes with load balancer in front of it to handle
# providing the public interface into the cluster as well as health checking the cluster members.
# ---------------------------------------------------------------------------------------------------------------------

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
# DEPLOY THE SERVERS
# ---------------------------------------------------------------------------------------------------------------------

module "es_cluster" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/elasticsearch-cluster?ref=v0.0.1"
  source = "../../modules/elasticsearch-cluster"

  elasticsearch_cluster_name = var.cluster_name
  cluster_size               = var.cluster_size

  ami_id        = var.ami_id
  aws_region    = var.aws_region
  instance_type = var.instance_type

  user_data = data.template_file.user_data.rendered

  vpc_id            = data.aws_vpc.default.id
  subnet_ids        = data.aws_subnets.default_subnets.ids
  backup_bucket_arn = "${aws_s3_bucket.es_backup_bucket.arn}*"

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  alowable_ssh_cidr_blocks = ["0.0.0.0/0"]

  allowed_cidr_blocks = ["0.0.0.0/0"]

  key_name          = var.key_name
  target_group_arns = [module.es_target_group.target_group_arn]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET
# The Elasticsearch snapshots will be stored in this bucket.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "es_backup_bucket" {
  bucket = "${lower(var.cluster_name)}-es-backup-bucket"

  # In a production environment you definitely don't want to destroy your backup bucket as that will remove all your
  # snapshots.I would strongly recommend using 'prevent_destroy' to stop terraform from destroying this resource.
  # Also 'force_destroy' is only here for testing and SHOULD NOT be used in a production environment
  force_destroy = true

  # Add a sleep to avoid eventual consistency errors post create. This ensures that the S3 bucket exists and is ready by
  # the time references to it are created.
  provisioner "local-exec" {
    command = "echo 'Sleeping 30 seconds to ensure backup bucket exists'; sleep 60"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON BOOT FOR EACH EC2 INSTANCE IN THE ELASTICSEARCH CLUSTER
# This script will call run-elasticsearch and pass along all dynamic runtime variables.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "user_data" {
  template = file("${path.module}/user-data/user-data.sh")

  vars = {
    cluster_name     = var.cluster_name
    network_host     = "0.0.0.0" # IP address of the network interface that elasticsearch will bind to.
    jvm_xms          = "4g"
    jvm_xmx          = "4g"
    min_master_nodes = 2
    aws_region       = var.aws_region
    use_ssl          = var.use_ssl
    keystore_file    = var.java_keystore_filename
    keystore_pass    = var.java_keystore_password
    key_pass         = var.java_keystore_certificate_password
    key_alias        = var.java_keystore_cert_alias
  }
}

module "es_target_group" {
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group      = true
  http_listener_arns      = values(module.alb.http_listener_arns)
  https_listener_arns     = values(module.alb.https_listener_acm_cert_arns)
  num_http_listener_arns  = var.use_ssl ? 0 : 1
  num_https_listener_arns = var.use_ssl ? 1 : 0
  protocol                = var.use_ssl ? "HTTPS" : "HTTP"

  port              = var.elasticsearch_api_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.cluster_name}-es-lb-tg"
  vpc_id            = data.aws_vpc.default.id
}

module "es_cluster_backup" {
  source = "../../modules/elasticsearch-cluster-backup"

  name                = "${var.cluster_name}-backup"
  region              = var.aws_region
  schedule_expression = var.schedule_expression
  alarm_period        = var.alarm_period
  elasticsearch_dns   = module.alb.alb_dns_name
  repository          = var.repository
  bucket              = aws_s3_bucket.es_backup_bucket.bucket
  protocol            = var.use_ssl ? "https" : "http"

  cloudwatch_metric_name      = "${var.cluster_name}-backup"
  cloudwatch_metric_namespace = "Custom/${var.cluster_name}"

  alarm_sns_topic_arns = [aws_sns_topic.cloudwatch_alarms.arn]
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN SNS TOPIC FOR THE ELASTICSEARCH BACKUP JOB ALARMS
# We create a topic in this code to make testing easier, but in real-world usage, you probably have a single, shared
# topic where you send all your alarms.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_sns_topic" "cloudwatch_alarms" {
  name = "cloudwatch-alarms-${var.cluster_name}"
}

module "es_cluster_restore" {
  source = "../../modules/elasticsearch-cluster-restore"

  name              = "${var.cluster_name}-restore"
  elasticsearch_dns = module.alb.alb_dns_name
  repository        = var.repository
  bucket            = aws_s3_bucket.es_backup_bucket.bucket
  protocol          = var.use_ssl ? "https" : "http"
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY AN ALB TO ROUTE REQUESTS TO THE SERVERS
# We also use it for health checks during deployments
# ---------------------------------------------------------------------------------------------------------------------

module "alb" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/alb?ref=v0.14.1"

  alb_name         = "${var.cluster_name}-alb"
  environment_name = "example"
  aws_account_id   = data.aws_caller_identity.current.account_id

  is_internal_alb = false

  ssl_policy = "ELBSecurityPolicy-2016-08"

  allow_inbound_from_security_group_ids     = [module.es_cluster.security_group_id]
  allow_inbound_from_security_group_ids_num = 1

  http_listener_ports                        = local.http_listener_ports[var.use_ssl ? "with_ssl" : "no_ssl"]
  https_listener_ports_and_acm_ssl_certs     = local.https_listener_ports_and_acm_ssl_certs[var.use_ssl ? "with_ssl" : "no_ssl"]
  https_listener_ports_and_acm_ssl_certs_num = var.use_ssl ? 1 : 0

  aws_region     = var.aws_region
  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnets.default_subnets.ids
}

locals {
  http_listener_ports = {
    with_ssl = []
    no_ssl   = [var.elasticsearch_api_port]
  }

  https_listener_ports_and_acm_ssl_certs = {
    with_ssl = [
      {
        port            = var.elasticsearch_api_port
        tls_domain_name = "*.${var.route53_zone_name}"
      },
    ]
    no_ssl = []
  }
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
