# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The ID of the AMI to run in this cluster."
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run for each node in the cluster (e.g. t2.micro)."
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the kibana cluster"
  type        = string
}

variable "subnet_ids" {
  description = "The subnet IDs into which the EC2 Instances should be deployed."
  type        = list(string)
}

variable "user_data" {
  description = "A User Data script to execute while the server is booting."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "name_prefix" {
  description = "The module's name that will be used to prefix various AWS resource names."
  type        = string
  default     = "elastalert-"
}

variable "instance_profile_path" {
  description = "Path in which to create the IAM instance profile."
  type        = string
  default     = "/"
}

variable "min_elb_capacity" {
  description = "Wait for this number of EC2 Instances to show up healthy in the load balancer on creation."
  type        = number
  default     = 0
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for the EC2 Instances to be healthy before timing out."
  type        = string
  default     = "10m"
}

variable "ssh_key_name" {
  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
  type        = string
  default     = null
}

variable "ssh_port" {
  description = "The port used for SSH connections"
  type        = number
  default     = 22
}

variable "allow_ssh_from_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which SSH access will be permitted. Attempts to access the bastion host from all other IP addresses will be blocked."
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

variable "associate_public_ip_address" {
  description = "If set to true, associate a public IP address with each EC2 Instance in the cluster."
  type        = bool
  default     = false
}

variable "target_group_arns" {
  description = "A list of target group ARNs to associate with the Kibana cluster."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "List fo extra tag blocks added to the autoscaling group configuration. Each element in the list is a map containing keys 'key', 'value', and 'propagate_at_launch' mapped to the respective values."
  type = list(object({
    key                 = string
    value               = string
    propagate_at_launch = bool
  }))
  default = []

  # Example:
  #
  # default = [
  #   {
  #     key                 = "foo"
  #     value               = "bar"
  #     propagate_at_launch = true
  #   }
  # ]
}
