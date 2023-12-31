# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "security_group_id" {
  description = "The ID of the Security Group to which all the rules should be attached."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "allowed_cidr_blocks" {
  description = "The list of IP address ranges in CIDR notation from which to allow connections to the rest_port."
  type        = list(string)
  default     = []
}

variable "api_port" {
  description = "This is the port that is used to access elasticsearch for user queries"
  type        = number
  default     = 9200
}

variable "node_discovery_port" {
  description = "This is the port that is used internally by elasticsearch for cluster node discovery"
  type        = number
  default     = 9300
}

variable "allow_api_from_security_group_ids" {
  description = "The IDs of security groups from which ES API connections will be allowed. If you update this variable, make sure to update var.num_api_security_group_ids too!"
  type        = list(string)
  default     = []
}

variable "num_api_security_group_ids" {
  description = "The number of security group IDs in var.allow_api_from_security_group_ids. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.allow_api_from_security_group_ids, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}

variable "allow_node_discovery_from_security_group_ids" {
  description = "The IDs of security groups from which ES API connections will be allowed. If you update this variable, make sure to update var.num_node_discovery_security_group_ids too!"
  type        = list(string)
  default     = []
}

variable "num_node_discovery_security_group_ids" {
  description = "The number of security group IDs in var.allow_node_discovery_from_security_group_ids. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.allow_node_discovery_from_security_group_ids, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}
