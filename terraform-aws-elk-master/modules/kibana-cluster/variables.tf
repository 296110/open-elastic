# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the kibana cluster (e.g. kibana-stage). This variable is used to namespace all resources created by this module."
  type        = string
}

variable "ami_id" {
  description = "The ID of the AMI to run in this cluster."
  type        = string
}

variable "instance_type" {
  description = "The type of EC2 Instances to run for each node in the cluster (e.g. t2.micro)."
  type        = string
}

variable "min_size" {
  description = "The minimum number of nodes to have in the kibana cluster."
  type        = number
}

variable "max_size" {
  description = "The maximum number of nodes to have in the kibana cluster."
  type        = number
}

variable "desired_capacity" {
  description = "The desired number of EC2 Instances to run in the ASG initially. Note that auto scaling policies may change this value. If you're using auto scaling policies to dynamically resize the cluster, you should actually leave this value as null."
  type        = number
  default     = null
}

variable "min_elb_capacity" {
  description = "Wait for this number of EC2 Instances to show up healthy in the load balancer on creation."
  type        = number
  default     = 0
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

variable "kibana_ui_port" {
  description = "This is the port that is used to access kibana UI"
  type        = number
  default     = 5601
}

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

variable "ssh_key_name" {
  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "If set to true, associate a public IP address with each EC2 Instance in the cluster."
  type        = bool
  default     = false
}

variable "instance_profile_path" {
  description = "Path in which to create the IAM instance profile."
  type        = string
  default     = "/"
}

variable "target_group_arns" {
  description = "A list of target group ARNs to associate with the Kibana cluster."
  type        = list(string)
  default     = []
}

variable "ssh_port" {
  description = "The port used for SSH connections"
  type        = number
  default     = 22
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for the EC2 Instances to be healthy before timing out."
  type        = string
  default     = "10m"
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
