terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SERVER GROUP (SG) TO RUN ELASTICSEARCH
# ---------------------------------------------------------------------------------------------------------------------

module "elasticsearch_cluster" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-asg.git//modules/server-group?ref=v0.14.0"

  aws_region    = var.aws_region
  name          = var.elasticsearch_cluster_name
  size          = var.cluster_size
  instance_type = var.instance_type
  ami_id        = var.ami_id

  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  num_enis = var.num_enis_per_node

  key_pair_name                     = var.key_name
  allow_ssh_from_cidr_blocks        = var.alowable_ssh_cidr_blocks
  allow_ssh_from_security_group_ids = var.allowed_ssh_security_group_ids
  user_data                         = var.user_data

  alb_target_group_arns = var.target_group_arns
  skip_rolling_deploy   = var.skip_rolling_deploy

  custom_tags = var.tags

  ebs_volumes                             = var.ebs_volumes
  ebs_optimized                           = var.ebs_optimized
  root_block_device_volume_type           = var.root_volume_type
  root_block_device_volume_size           = var.root_volume_size
  root_block_device_delete_on_termination = var.root_volume_delete_on_termination
}

# Create Security group rules to allow
# for inter-cluster communication

module "security_group_rules" {
  source                            = "../elasticsearch-security-group-rules"
  security_group_id                 = module.elasticsearch_cluster.security_group_id
  allowed_cidr_blocks               = var.allowed_cidr_blocks
  allow_api_from_security_group_ids = var.allow_api_from_security_group_ids
  num_api_security_group_ids        = var.num_api_security_group_ids
  api_port                          = var.api_port
  node_discovery_port               = var.node_discovery_port

  allow_node_discovery_from_security_group_ids = var.allow_node_discovery_from_security_group_ids
  num_node_discovery_security_group_ids        = var.num_node_discovery_security_group_ids
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM ROLE TO EACH EC2 INSTANCE
# We can use the IAM role to grant the instance IAM permissions so we can use the AWS CLI without having to figure out
# how to get our secret AWS access keys onto the box. We export the ID of the IAM role as an output variable so users
# can attach custom policies.
# ---------------------------------------------------------------------------------------------------------------------

module "iam_roles" {
  source            = "../elasticsearch-iam-policies"
  iam_role_id       = module.elasticsearch_cluster.iam_role_id
  backup_bucket_arn = var.backup_bucket_arn
}
