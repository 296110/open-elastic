terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SERVER GROUP (SG) TO RUN LOGSTASH
# ---------------------------------------------------------------------------------------------------------------------

module "logstash_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-asg.git//modules/server-group?ref=v0.14.0"

  aws_region    = var.aws_region
  name          = var.cluster_name
  size          = var.size
  instance_type = var.instance_type
  ami_id        = var.ami_id

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  user_data     = var.user_data
  key_pair_name = var.ssh_key_name

  ssh_port                          = var.ssh_port
  allow_ssh_from_cidr_blocks        = var.allowed_ssh_cidr_blocks
  allow_ssh_from_security_group_ids = var.allowed_ssh_security_group_ids

  associate_public_ip_address = var.associate_public_ip_address

  ebs_volumes                             = var.ebs_volumes
  ebs_optimized                           = var.ebs_optimized
  root_block_device_volume_type           = var.root_volume_type
  root_block_device_volume_size           = var.root_volume_size
  root_block_device_delete_on_termination = var.root_volume_delete_on_termination

  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  alb_target_group_arns = var.lb_target_group_arns
  skip_rolling_deploy   = var.skip_rolling_deploy

  custom_tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CONFIGURE THE SECURITY GROUP RULES FOR LOGSTASH
# This controls which ports are exposed and who can connect to them
# ---------------------------------------------------------------------------------------------------------------------

module "logstash_security_group_rules" {
  source = "../../modules/logstash-security-group-rules"

  security_group_id = module.logstash_cluster.security_group_id
  beats_port        = var.filebeat_port
  collectd_port     = var.collectd_port

  beats_port_cidr_blocks = var.beats_port_cidr_blocks

  # If using var.beats_port_security_groups, then var.num_beats_port_security_groups must match the number of SGs
  beats_port_security_groups     = var.beats_port_security_groups
  num_beats_port_security_groups = var.num_beats_port_security_groups

  collectd_port_cidr_blocks = var.collectd_port_cidr_blocks

  # If using var.collectd_port_security_groups, then var.num_collectd_port_security_groups must match the number of SGs
  collectd_port_security_groups     = var.collectd_port_security_groups
  num_collectd_port_security_groups = var.num_collectd_port_security_groups
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICIES TO THE SERVER GROUP IAM ROLE
# ---------------------------------------------------------------------------------------------------------------------

module "iam_roles" {
  source      = "../logstash-iam-policies"
  iam_role_id = module.logstash_cluster.iam_role_id
}
