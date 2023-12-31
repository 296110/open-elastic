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

variable "allow_ui_from_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which access to the UI will be permitted. Attempts to access the UI from all other IP addresses will be blocked."
  type        = list(string)
  default     = []
}

variable "allow_ui_from_security_group_ids" {
  description = "The IDs of security groups from which access to the UI will be permitted. If you update this variable, make sure to update var.num_ui_security_group_ids too!"
  type        = list(string)
  default     = []
}

variable "num_ui_security_group_ids" {
  description = "The number of security group IDs in var.allow_ui_from_security_group_ids. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.allow_ui_from_security_group_ids, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}

variable "allow_ssh_from_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which SSH access will be permitted. Attempts to access SSH from all other IP addresses will be blocked."
  type        = list(string)
  default     = []
}

variable "allow_ssh_from_security_group_ids" {
  description = "The IDs of security groups from which SSH connections will be allowed. If you update this variable, make sure to update var.num_ssh_security_group_ids too!"
  type        = list(string)
  default     = []
}

variable "num_ssh_security_group_ids" {
  description = "The number of security group IDs in var.allow_ssh_from_security_group_ids. We should be able to compute this automatically, but due to a Terraform limitation, if there are any dynamic resources in var.allow_ssh_from_security_group_ids, then we won't be able to: https://github.com/hashicorp/terraform/pull/11482"
  type        = number
  default     = 0
}

variable "kibana_ui_port" {
  description = "This is the port that is used to access the Kibana UI."
  type        = number
  default     = 5601
}

variable "ssh_port" {
  description = "The port to use for SSH access."
  type        = number
  default     = 22
}
