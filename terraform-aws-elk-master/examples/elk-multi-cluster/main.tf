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

  elasticsearch_cluster_name = var.elasticsearch_cluster_name
  cluster_size               = var.elasticsearch_cluster_size

  ami_id        = var.elasticsearch_ami_id
  aws_region    = var.aws_region
  instance_type = var.elasticsearch_instance_type

  user_data = data.template_file.elasticsearch_user_data.rendered

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default_subnets.ids

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  alowable_ssh_cidr_blocks = ["0.0.0.0/0"]
  allowed_cidr_blocks      = ["0.0.0.0/0"]

  key_name          = var.key_name
  target_group_arns = [module.es_target_group.target_group_arn]
}

# Add IAM policy to be able to read the secrets for configuring authentication of Logstash and Kibana
resource "aws_iam_role_policy" "elasticsearch_secrets_manager_read_policy" {
  count  = var.use_ssl ? 1 : 0
  name   = "read-secrets-manager-entries"
  role   = module.es_cluster.iam_role_id
  policy = data.aws_iam_policy_document.elasticsearch_secrets_manager_read_policy[0].json
}

data "aws_iam_policy_document" "elasticsearch_secrets_manager_read_policy" {
  count = var.use_ssl ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.elasticsearch_password_for_kibana_secrets_manager_arn,
      var.elasticsearch_password_for_logstash_secrets_manager_arn,
    ]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE USER DATA SCRIPT THAT WILL RUN ON BOOT FOR EACH EC2 INSTANCE IN THE ELASTICSEARCH CLUSTER
# This script will call run-elasticsearch and pass along all dynamic runtime variables.
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "elasticsearch_user_data" {
  template = file("${path.module}/user-data/elasticsearch/user-data.sh")

  vars = {
    cluster_name     = var.elasticsearch_cluster_name
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

    # Authentication info for logstash and kibana
    kibana_password_secrets_manager_arn   = var.elasticsearch_password_for_kibana_secrets_manager_arn
    logstash_password_secrets_manager_arn = var.elasticsearch_password_for_logstash_secrets_manager_arn
  }
}

module "es_target_group" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/load-balancer-alb-target-group?ref=v0.0.1"
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group      = true
  http_listener_arns      = [lookup(module.alb.http_listener_arns, var.elasticsearch_api_port, "")]
  https_listener_arns     = [lookup(module.alb.https_listener_non_acm_cert_arns, var.elasticsearch_api_port, "")]
  num_http_listener_arns  = var.use_ssl ? 0 : 1
  num_https_listener_arns = var.use_ssl ? 1 : 0
  protocol                = var.alb_target_group_protocol

  port              = var.elasticsearch_api_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.elasticsearch_cluster_name}-es-tg"
  vpc_id            = data.aws_vpc.default.id
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY A LOGSTASH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "logstash" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/logstash-cluster?ref=v0.0.1"
  source = "../../modules/logstash-cluster"

  aws_region    = var.aws_region
  cluster_name  = var.logstash_cluster_name
  ami_id        = var.logstash_ami_id
  size          = var.logstash_cluster_size
  instance_type = var.logstash_instance_type
  vpc_id        = data.aws_vpc.default.id
  subnet_ids    = data.aws_subnets.default_subnets.ids
  user_data     = data.template_file.logstash_user_data.rendered

  # To make this example simple to test, we allow access from any IP address. In real-world usage, you should keep
  # almost all your servers private, and only allow access from known, trusted servers.
  beats_port_cidr_blocks    = ["0.0.0.0/0"]
  collectd_port_cidr_blocks = ["0.0.0.0/0"]
  allowed_ssh_cidr_blocks   = ["0.0.0.0/0"]

  ssh_key_name         = var.key_name
  lb_target_group_arns = [module.logstash_target_group_collectd.target_group_arn]
}

# Add IAM policy to be able to read the secrets for configuring authentication of Logstash to ES
resource "aws_iam_role_policy" "logstash_secrets_manager_read_policy" {
  count  = var.use_ssl ? 1 : 0
  name   = "read-secrets-manager-entries"
  role   = module.logstash.iam_role_id
  policy = data.aws_iam_policy_document.logstash_secrets_manager_read_policy[0].json
}

data "aws_iam_policy_document" "logstash_secrets_manager_read_policy" {
  count = var.use_ssl ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.elasticsearch_password_for_logstash_secrets_manager_arn,
    ]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN S3 BUCKET FOR TESTING PURPOSES ONLY
# We upload a simple text file into this bucket. The Logstash S3 input plugin will grab every line of every file in
# this bucket and send it to the configured output. In production this won't be needed and the cloudtrail bucket should
# be used directly.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket" "s3_test_bucket" {
  bucket = "${lower(var.logstash_cluster_name)}-s3-logs"

  # In a production environment you definitely don't want to destroy your backup bucket as that will remove all your
  # logs.I would strongly recommend using 'prevent_destroy' to stop terraform from destroying this resource.
  # Also 'force_destroy' is only here for testing and SHOULD NOT be used in a production environment
  force_destroy = true
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A CLOUDWATCH LOGGROUP FOR TESTING PURPOSES ONLY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cloudwatch_test_group" {
  name = "${var.logstash_cluster_name}-lg"
}

resource "aws_cloudwatch_log_stream" "cloudwatch_test_stream" {
  name           = "${var.logstash_cluster_name}-ls"
  log_group_name = aws_cloudwatch_log_group.cloudwatch_test_group.name
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH LOGSTASH EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Logstash
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "logstash_user_data" {
  template = file("${path.module}/user-data/logstash/user-data.sh")

  vars = {
    beats_port         = var.filebeat_port
    collectd_port      = var.collectd_port
    elasticsearch_host = aws_route53_record.elk_alb_subdomain.fqdn
    elasticsearch_port = var.elasticsearch_api_port
    bucket             = aws_s3_bucket.s3_test_bucket.bucket
    output_path        = var.cloudtrail_dest_log_path
    log_group          = aws_cloudwatch_log_group.cloudwatch_test_group.name
    region             = var.aws_region
    jvm_xms            = "4g"
    jvm_xmx            = "4g"
    use_ssl            = var.use_ssl
    keystore_file      = var.logstash_keystore_path
    keystore_pass      = var.java_keystore_password
    ca_auth_path       = var.logstash_ca_auth_path
    cert_pem_path      = var.logstash_cert_pem_path
    cert_key_p8_path   = var.logstash_key_p8_path

    # Authentication credentials for logstash to access ES
    elasticsearch_password_for_logstash_secrets_manager_arn = var.elasticsearch_password_for_logstash_secrets_manager_arn
  }
}

module "logstash_target_group_collectd" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/load-balancer-alb-target-group?ref=v0.0.1"
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group      = true
  http_listener_arns      = [lookup(module.alb.http_listener_arns, var.collectd_port, "")]
  https_listener_arns     = [lookup(module.alb.https_listener_non_acm_cert_arns, var.collectd_port, "")]
  num_http_listener_arns  = var.use_ssl ? 0 : 1
  num_https_listener_arns = var.use_ssl ? 1 : 0
  protocol                = var.alb_target_group_protocol

  port              = var.collectd_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.logstash_cluster_name}-cd-tg"
  vpc_id            = data.aws_vpc.default.id
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THE KIBANA CLUSTR
# ---------------------------------------------------------------------------------------------------------------------

module "kibana_cluster" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/kibana-cluster?ref=v0.0.1"
  source = "../../modules/kibana-cluster"

  ami_id        = var.kibana_ami_id
  instance_type = var.kibana_instance_type
  user_data     = data.template_file.kibana_user_data.rendered

  cluster_name              = var.kibana_cluster_name
  desired_capacity          = 1
  max_size                  = 1
  min_size                  = 1
  wait_for_capacity_timeout = "5m"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default_subnets.ids

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allow_ssh_from_security_group_ids = [module.es_cluster.security_group_id]
  allow_ui_from_cidr_blocks         = ["0.0.0.0/0"]
  ssh_key_name                      = var.key_name
  kibana_ui_port                    = var.kibana_ui_port
  target_group_arns                 = [module.kibana_target_group.target_group_arn]
}

# Add IAM policy to be able to read the secrets for configuring authentication of Logstash to ES
resource "aws_iam_role_policy" "kibana_secrets_manager_read_policy" {
  count  = var.use_ssl ? 1 : 0
  name   = "read-secrets-manager-entries"
  role   = module.kibana_cluster.iam_role_id
  policy = data.aws_iam_policy_document.kibana_secrets_manager_read_policy[0].json
}

data "aws_iam_policy_document" "kibana_secrets_manager_read_policy" {
  count = var.use_ssl ? 1 : 0
  statement {
    effect  = "Allow"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      var.elasticsearch_password_for_kibana_secrets_manager_arn,
    ]
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# CREATE A TARGET GROUP FOR THE LOAD BALANCER
# ---------------------------------------------------------------------------------------------------------------------

module "kibana_target_group" {
  source = "../../modules/load-balancer-alb-target-group"

  using_server_group      = false
  asg_name                = module.kibana_cluster.kibana_asg_name
  http_listener_arns      = [lookup(module.alb.http_listener_arns, "80", "")]
  https_listener_arns     = [lookup(module.alb.https_listener_acm_cert_arns, "443", "")]
  num_http_listener_arns  = var.use_ssl ? 0 : 1
  num_https_listener_arns = var.use_ssl ? 1 : 0
  protocol                = var.alb_target_group_protocol

  port              = var.kibana_ui_port
  health_check_path = "/"

  listener_rule_starting_priority = 100

  target_group_name = "${var.kibana_cluster_name}-lb-tg"
  vpc_id            = data.aws_vpc.default.id
}

# ---------------------------------------------------------------------------------------------------------------------
# THE USER DATA SCRIPT THAT WILL RUN ON EACH EC2 INSTANCE WHEN IT'S BOOTING
# This script will configure and start Kibana
# ---------------------------------------------------------------------------------------------------------------------

data "template_file" "kibana_user_data" {
  template = file("${path.module}/user-data/kibana/user-data.sh")

  vars = {
    server_name       = var.kibana_cluster_name
    elasticsearch_url = "${var.use_ssl ? "https" : "http"}://${aws_route53_record.elk_alb_subdomain.fqdn}:${var.elasticsearch_api_port}"
    kibana_ui_port    = var.kibana_ui_port
    # This is where you copied the templated config file when creating the AMI
    config_file_template = "/tmp/config/kibana.yml"
    use_ssl              = var.use_ssl
    ca_auth_path         = var.kibana_ca_auth_path
    cert_pem_path        = var.kibana_cert_pem_path
    cert_key_path        = var.kibana_cert_key_path

    # Authentication credentials for Kibana to access ES
    elasticsearch_password_for_kibana_secrets_manager_arn = var.elasticsearch_password_for_kibana_secrets_manager_arn
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# LAUNCH APP SERVER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "app_server_profile" {
  name = "${var.logstash_cluster_name}-app-server-profile"
  role = aws_iam_role.app_server_iam_role.name
}

resource "aws_iam_role" "app_server_iam_role" {
  name               = "${var.logstash_cluster_name}-app-server-iam-role"
  assume_role_policy = data.aws_iam_policy_document.app_server_assume_role_policy.json
}

data "aws_iam_policy_document" "app_server_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_security_group" "app_server_sg" {
  name        = "${var.logstash_cluster_name}-app-server-sg"
  description = "Security group for application server"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_instance" "app_server" {
  ami                    = var.app_server_ami_id
  instance_type          = var.app_server_instance_type
  user_data              = data.template_file.app_server_user_data.rendered
  iam_instance_profile   = aws_iam_instance_profile.app_server_profile.name
  vpc_security_group_ids = [module.es_cluster.security_group_id, module.logstash.security_group_id, aws_security_group.app_server_sg.id]
  key_name               = var.key_name

  tags = {
    Name = var.app_server_name
  }
}

data "template_file" "app_server_user_data" {
  template = file("${path.module}/user-data/app-server/user-data.sh")

  vars = {
    log_path     = var.filebeat_log_path
    log_content  = "TODO: I don't think we need this"
    logstash_url = "${var.use_ssl ? "https" : "http"}://${aws_route53_record.elk_alb_subdomain.fqdn}:${var.collectd_port}"

    # We use this region and tag to auto discover the Logstash nodes
    region = var.aws_region
    tag    = "ServerGroupName=${var.logstash_cluster_name}"

    port = var.filebeat_port
    # This bit is only here to ensure the Logstash cluster gets deployed
    # before the app server, so tagged that instances will already exist
    asg_names     = module.logstash.server_asg_names[0]
    use_ssl       = var.use_ssl
    ca_path       = var.collectd_ca_path
    ca_auth_path  = var.filebeat_ca_auth_path
    cert_pem_path = var.filebeat_cert_pem_path
    cert_key_path = var.filebeat_cert_key_path
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY ELASTALERT
# ---------------------------------------------------------------------------------------------------------------------

module "elastalert" {
  # When using these modules in your own code, you will need to use a Git URL with a ref attribute that pins you
  # to a specific version of the modules, such as the following example:
  # source = "git::git@github.com:gruntwork-io/terraform-aws-elk.git//modules/elastalert?ref=v0.0.1"
  source = "../../modules/elastalert"

  ami_id        = var.elastalert_ami_id
  instance_type = var.elastalert_instance_type

  ssh_key_name = var.key_name
  vpc_id       = data.aws_vpc.default.id
  subnet_ids   = data.aws_subnets.default_subnets.ids

  user_data = data.template_file.elastalert_user_data.rendered

  # To make testing easier, we allow SSH requests from any IP address here. In a production deployment, we strongly
  # recommend you limit this to the IP address ranges of known, trusted servers inside your VPC.
  allow_ssh_from_cidr_blocks = ["0.0.0.0/0"]
}

data "template_file" "elastalert_user_data" {
  template = file("${path.module}/user-data/elastalert/user-data.sh")

  vars = {
    elasticsearch_url    = aws_route53_record.elk_alb_subdomain.fqdn
    elasticsearch_port   = var.elasticsearch_api_port
    use_ssl              = var.use_ssl
    ca_auth_path         = var.elastalert_ca_auth_path
    cert_pem_path        = var.elastalert_cert_pem_path
    cert_key_path        = var.elastalert_cert_key_path
    sns_topic_arn        = module.sns.topic_arn
    sns_topic_aws_region = var.aws_region
    rules_folder_path    = "/etc/elastalert/elastalert-rules"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICIES TO THE ELASTALERT IAM ROLE SO THAT ELASTALERT COULD WRITE TO SNS
# ---------------------------------------------------------------------------------------------------------------------

module "elastalert_iam_roles" {
  source        = "../../modules/elastalert-iam-policies"
  iam_role_id   = module.elastalert.iam_role_id
  policy_name   = "${var.subdomain_name}-cluster-policy"
  sns_topic_arn = module.sns.topic_arn
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE SNS TOPIC FOR ELASTALERT SAMPLE ALERT
# ---------------------------------------------------------------------------------------------------------------------

module "sns" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-messaging.git//modules/sns?ref=v0.3.4"

  name         = var.sns_topic_name
  display_name = var.sns_topic_display_name

  allow_publish_accounts    = var.allow_publish_accounts
  allow_subscribe_accounts  = var.allow_subscribe_accounts
  allow_subscribe_protocols = var.allow_subscribe_protocols
}

resource "aws_iam_server_certificate" "server_cert" {
  certificate_body  = file("${path.module}/../elk-amis/ssl/localhost.pem")
  certificate_chain = file("${path.module}/../elk-amis/ssl/caFile")
  private_key       = file("${path.module}/../elk-amis/ssl/localhost.key")
}

module "alb" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-load-balancer.git//modules/alb?ref=v0.20.4"

  alb_name        = var.alb_name
  is_internal_alb = false
  ssl_policy      = var.ssl_policy

  allow_inbound_from_security_group_ids     = [module.kibana_cluster.kibana_security_group_id, aws_security_group.app_server_sg.id, module.es_cluster.security_group_id, module.logstash.security_group_id]
  allow_inbound_from_security_group_ids_num = 4

  http_listener_ports                        = local.http_listener_ports[var.use_ssl ? "with_ssl" : "no_ssl"]
  https_listener_ports_and_ssl_certs         = local.https_listener_ports_and_ssl_certs[var.use_ssl ? "with_ssl" : "no_ssl"]
  https_listener_ports_and_ssl_certs_num     = var.use_ssl ? 2 : 0
  https_listener_ports_and_acm_ssl_certs     = local.https_listener_ports_and_acm_ssl_certs[var.use_ssl ? "with_ssl" : "no_ssl"]
  https_listener_ports_and_acm_ssl_certs_num = var.use_ssl ? 1 : 0

  vpc_id         = data.aws_vpc.default.id
  vpc_subnet_ids = data.aws_subnets.default_subnets.ids
}

locals {
  http_listener_ports = {
    with_ssl = []
    no_ssl   = [80, var.collectd_port, var.elasticsearch_api_port]
  }

  https_listener_ports_and_ssl_certs = {
    no_ssl = []
    with_ssl = [
      {
        port    = var.collectd_port
        tls_arn = aws_iam_server_certificate.server_cert.arn
      },
      {
        port    = var.elasticsearch_api_port
        tls_arn = aws_iam_server_certificate.server_cert.arn
      },
    ]
  }

  https_listener_ports_and_acm_ssl_certs = {
    no_ssl = []
    with_ssl = [
      {
        port            = "443"
        tls_domain_name = "*.${var.route53_zone_name}"
      },
    ]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY TO APP SERVER INSTANCE IAM ROLE SO THAT THE AUTO DISCOVERY SCRIPT CAN RETRIVE ASG INFORMATION
# ---------------------------------------------------------------------------------------------------------------------

module "beats_iam_roles" {
  source      = "../../modules/beats-iam-policies"
  iam_role_id = aws_iam_role.app_server_iam_role.id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE AN ALIAS RECORD
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_route53_record" "elk_alb_subdomain" {
  zone_id = data.aws_route53_zone.gruntwork_sandbox.zone_id
  name    = var.subdomain_name
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_hosted_zone_id
    evaluate_target_health = false
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY THIS EXAMPLE IN THE DEFAULT VPC AND SUBNETS
# To keep this example simple, we deploy it in the default VPC and subnets. In real-world usage, you'll probably want
# to use a custom VPC and private subnets.
# ---------------------------------------------------------------------------------------------------------------------

data "aws_route53_zone" "gruntwork_sandbox" {
  private_zone = false

  zone_id = var.route53_zone_id
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}
