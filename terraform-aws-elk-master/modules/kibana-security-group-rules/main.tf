terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ----------------------------------------------------------------------------------------------------------------------
# SECURITY GROUP RULES OPTIMIZED FOR KIBANA
# - Allow inbound Kibana UI access from specified CIDR blocks and Security Groups
# - Allow inbound SSH from specified CIDR blocks and Security Groups
# ----------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_inbound_ui_from_cidr_blocks" {
  count             = signum(length(var.allow_ui_from_cidr_blocks))
  type              = "ingress"
  from_port         = var.kibana_ui_port
  to_port           = var.kibana_ui_port
  protocol          = "tcp"
  cidr_blocks       = var.allow_ui_from_cidr_blocks
  security_group_id = var.security_group_id
}

resource "aws_security_group_rule" "allow_inbound_ui_from_security_group" {
  count                    = var.num_ui_security_group_ids
  type                     = "ingress"
  from_port                = var.kibana_ui_port
  to_port                  = var.kibana_ui_port
  protocol                 = "tcp"
  source_security_group_id = var.allow_ui_from_security_group_ids[count.index]
  security_group_id        = var.security_group_id
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_cidr_blocks" {
  count             = signum(length(var.allow_ssh_from_cidr_blocks))
  type              = "ingress"
  from_port         = var.ssh_port
  to_port           = var.ssh_port
  protocol          = "tcp"
  cidr_blocks       = var.allow_ssh_from_cidr_blocks
  security_group_id = var.security_group_id
}

resource "aws_security_group_rule" "allow_inbound_ssh_from_security_groups" {
  count                    = var.num_ssh_security_group_ids
  type                     = "ingress"
  from_port                = var.ssh_port
  to_port                  = var.ssh_port
  protocol                 = "tcp"
  source_security_group_id = var.allow_ssh_from_security_group_ids[count.index]
  security_group_id        = var.security_group_id
}
