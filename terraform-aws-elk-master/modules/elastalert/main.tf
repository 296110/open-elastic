terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE AUTO SCALING GROUP
# ---------------------------------------------------------------------------------------------------------------------

module "elastalert" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-asg.git//modules/asg-rolling-deploy?ref=v0.14.0"

  launch_configuration_name = aws_launch_configuration.launch_configuration.name
  vpc_subnet_ids            = var.subnet_ids

  target_group_arns = var.target_group_arns

  # We are running ElastAlert on an ASG here to make sure that in the even of the EC2 instance
  # crashing the ASG will manage restarting a new instance. We purposely do not expose min/max/desired
  # sizes because we want to make sure that only one ElastAlert instance runs for a given ELK cluster
  # If multiple instances of ElastAlert were to run, we would potentially see duplicate alerts.
  min_size         = 1
  max_size         = 1
  desired_capacity = 1
  min_elb_capacity = var.min_elb_capacity

  wait_for_capacity_timeout = var.wait_for_capacity_timeout

  custom_tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAUNCH CONFIGURATION THAT DEFINES EACH EC2 INSTANCE IN THE ASG
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_launch_configuration" "launch_configuration" {
  name_prefix   = var.name_prefix
  image_id      = var.ami_id
  instance_type = var.instance_type

  user_data = var.user_data

  key_name        = var.ssh_key_name
  security_groups = [aws_security_group.elastalert_sg.id]

  iam_instance_profile = aws_iam_instance_profile.instance_profile.name

  # Important note: whenever using a launch configuration with an auto scaling group, you must set
  # create_before_destroy = true. However, as soon as you set create_before_destroy = true in one resource, you must
  # also set it in every resource that it depends on, or you'll get an error about cyclic dependencies (especially when
  # removing resources). For more info, see:
  #
  # https://www.terraform.io/docs/providers/aws/r/launch_configuration.html
  # https://terraform.io/docs/configuration/resources.html
  lifecycle {
    create_before_destroy = true
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A SECURITY GROUP TO CONTROL TRAFFIC IN AND OUT OF THE SERVERS
# Note: the ingress/egress rules are defined as separate aws_security_group_rule resources. That way, we can export the
# ID of this security group as an output and users can attach custom rules.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "elastalert_sg" {
  # Note: we are intentionally avoiding including var.name here, or if you change that, it results in the security
  # group being re-created, which fails with this error: https://github.com/hashicorp/terraform/issues/11047.
  # It probably has something to do with manually managing the default ENI for the EC2 instances. To minimize the odds
  # of hitting that bug, we try to reduce the cases where the security group is recreated; at this point, it should only
  # happen if you change the vpc_id, which should be rare, and probably means redeploying everything anyway.
  name_prefix = "elastalert-"

  vpc_id = var.vpc_id

  # See aws_launch_configuration.server_group for why this is here
  lifecycle {
    create_before_destroy = true
  }
}

# Create Security group rules to allow
# for inter-cluster communication

module "security_group_rules" {
  source = "../elastalert-security-group-rules"

  security_group_id = aws_security_group.elastalert_sg.id

  allow_ssh_from_cidr_blocks = var.allow_ssh_from_cidr_blocks

  allow_ssh_from_security_group_ids = var.allow_ssh_from_security_group_ids
  num_ssh_security_group_ids        = var.num_ssh_security_group_ids
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM ROLE TO EACH EC2 INSTANCE
# We can use the IAM role to grant the instance IAM permissions so we can use the AWS CLI without having to figure out
# how to get our secret AWS access keys onto the box. We export the ID of the IAM role as an output variable so users
# can attach custom policies.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_instance_profile" "instance_profile" {
  name_prefix = var.name_prefix
  path        = var.instance_profile_path
  role        = aws_iam_role.instance_role.name

  # aws_launch_configuration.launch_configuration in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "instance_role" {
  name_prefix        = var.name_prefix
  assume_role_policy = data.aws_iam_policy_document.instance_role.json

  # aws_iam_instance_profile.instance_profile in this module sets create_before_destroy to true, which means
  # everything it depends on, including this resource, must set it as well, or you'll get cyclic dependency errors
  # when you try to do a terraform destroy.
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "instance_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
