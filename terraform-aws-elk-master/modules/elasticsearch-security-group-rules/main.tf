terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# Allow access to the cluster
# open up ports for cluster communication.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group_rule" "allow_api_communication_from_cidr_blocks" {
  count             = signum(length(var.allowed_cidr_blocks))
  type              = "ingress"
  from_port         = var.api_port
  to_port           = var.api_port
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = var.allowed_cidr_blocks
}

resource "aws_security_group_rule" "allow_api_communication_from_security_groups" {
  count                    = var.num_api_security_group_ids
  type                     = "ingress"
  from_port                = var.api_port
  to_port                  = var.api_port
  protocol                 = "tcp"
  source_security_group_id = var.allow_api_from_security_group_ids[count.index]
  security_group_id        = var.security_group_id
}

resource "aws_security_group_rule" "allow_node_discovery_from_cidr_blocks" {
  count             = signum(length(var.allowed_cidr_blocks))
  type              = "ingress"
  from_port         = var.node_discovery_port
  to_port           = var.node_discovery_port
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = var.allowed_cidr_blocks
}

resource "aws_security_group_rule" "allow_node_discovery_from_security_groups" {
  count                    = var.num_node_discovery_security_group_ids
  type                     = "ingress"
  from_port                = var.node_discovery_port
  to_port                  = var.node_discovery_port
  protocol                 = "tcp"
  source_security_group_id = var.allow_node_discovery_from_security_group_ids[count.index]
  security_group_id        = var.security_group_id
}

resource "aws_security_group_rule" "allow_node_discovery_from_cluster_node_security_group" {
  type                     = "ingress"
  from_port                = var.node_discovery_port
  to_port                  = var.node_discovery_port
  protocol                 = "tcp"
  source_security_group_id = var.security_group_id
  security_group_id        = var.security_group_id
}
