terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# BEATS PORT
# OPEN UP PORT FOR THE BEATS INPUT PLUGIN
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "beats_port_cidr_blocks" {
  count     = signum(length(var.beats_port_cidr_blocks))
  type      = "ingress"
  from_port = var.beats_port
  to_port   = var.beats_port
  protocol  = "tcp"

  security_group_id = var.security_group_id
  cidr_blocks       = var.beats_port_cidr_blocks
}

resource "aws_security_group_rule" "beats_port_security_groups" {
  count     = var.num_beats_port_security_groups
  type      = "ingress"
  from_port = var.beats_port
  to_port   = var.beats_port
  protocol  = "tcp"

  security_group_id        = var.security_group_id
  source_security_group_id = var.beats_port_security_groups[count.index]
}

# ---------------------------------------------------------------------------------------------------------------------
# COLLECTD PORT
# OPEN UP PORT FOR THE HTTP INPUT PLUGIN
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "collectd_port_cidr_blocks" {
  count     = signum(length(var.collectd_port_cidr_blocks))
  type      = "ingress"
  from_port = var.collectd_port
  to_port   = var.collectd_port
  protocol  = "tcp"

  security_group_id = var.security_group_id
  cidr_blocks       = var.collectd_port_cidr_blocks
}

resource "aws_security_group_rule" "collectd_port_security_groups" {
  count     = var.num_collectd_port_security_groups
  type      = "ingress"
  from_port = var.collectd_port
  to_port   = var.collectd_port
  protocol  = "tcp"

  security_group_id        = var.security_group_id
  source_security_group_id = var.collectd_port_security_groups[count.index]
}
