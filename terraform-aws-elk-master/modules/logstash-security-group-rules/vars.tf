# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "security_group_id" {
  description = "The ID of the Security Group to which all the rules should be attached."
  type        = string
}

variable "beats_port" {
  description = "The port to use for BEATS requests. E.g. Filebeat"
  type        = number
}

variable "collectd_port" {
  description = "The port to use for CollectD requests."
  type        = number
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "beats_port_cidr_blocks" {
  description = "The list of IP address ranges in CIDR notation from which to allow connections to the beats_port."
  type        = list(string)
  default     = []
}

variable "beats_port_security_groups" {
  description = "The list of Security Group IDs from which to allow connections to the beats_port. If you update this variable, make sure to update var.num_beats_port_security_groups too!"
  type        = list(string)
  default     = []
}

variable "num_beats_port_security_groups" {
  description = "The number of security group IDs in var.beats_port_security_groups. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.beats_port_security_groups, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}

variable "collectd_port_cidr_blocks" {
  description = "The list of IP address ranges in CIDR notation from which to allow connections to the collectd_port."
  type        = list(string)
  default     = []
}

variable "collectd_port_security_groups" {
  description = "The list of Security Group IDs from which to allow connections to the collectd_port. If you update this variable, make sure to update var.num_collectd_port_security_groups too!"
  type        = list(string)
  default     = []
}

variable "num_collectd_port_security_groups" {
  description = "The number of security group IDs in var.collectd_port_security_groups. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.collectd_port_security_groups, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}
