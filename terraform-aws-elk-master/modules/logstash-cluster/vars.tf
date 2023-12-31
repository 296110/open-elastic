# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region the cluster will be deployed in."
  type        = string
}

variable "cluster_name" {
  description = "The name of the Logstash cluster (e.g. logstash-stage). This variable is used to namespace all resources created by this module."
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

variable "size" {
  description = "The number of nodes to have in the Logstash cluster."
  type        = number
}

variable "vpc_id" {
  description = "The ID of the VPC in which to deploy the Logstash cluster"
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

variable "lb_target_group_arns" {
  description = "The ALB taget groups with which to associate instances in this server group"
  type        = list(string)
}

variable "filebeat_port" {
  description = "The port on which Filebeat will communicate with the Logstash cluster"
  type        = number
  default     = 5044
}

variable "collectd_port" {
  description = "The port on which CollectD will communicate with the Logstash cluster"
  type        = number
  default     = 8080
}

variable "beats_port_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which access to the Filebeat port will be allowed"
  type        = list(string)
  default     = []
}

variable "collectd_port_cidr_blocks" {
  description = "A list of IP address ranges in CIDR format from which access to the Collectd port will be allowed"
  type        = list(string)
  default     = []
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These parameters have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "skip_rolling_deploy" {
  description = "If set to true, skip the rolling deployment, and destroy all the servers immediately. You should typically NOT enable this in prod, as it will cause downtime! The main use case for this flag is to make testing and cleanup easier. It can also be handy in case the rolling deployment code has a bug."
  type        = bool
  default     = false
}

variable "ssh_key_name" {
  description = "The name of an EC2 Key Pair that can be used to SSH to the EC2 Instances in this cluster. Set to an empty string to not associate a Key Pair."
  type        = string
  default     = null
}

variable "allowed_ssh_cidr_blocks" {
  description = "A list of CIDR-formatted IP address ranges from which the EC2 Instances will allow SSH connections"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_security_group_ids" {
  description = "A list of security group IDs from which the EC2 Instances will allow SSH connections"
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "If set to true, associate a public IP address with each EC2 Instance in the cluster."
  type        = bool
  default     = false
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

variable "ebs_volumes" {
  description = "A list that defines the EBS Volumes to create for each server. Each item in the list should be a map that contains the keys 'type' (one of standard, gp2, or io1), 'size' (in GB), and 'encrypted' (true or false). Each EBS Volume and server pair will get matching tags with a name of the format ebs-volume-xxx, where xxx is the index of the EBS Volume (e.g., ebs-volume-0, ebs-volume-1, etc). These tags can be used by each server to find and mount its EBS Volume(s)."
  type = list(object({
    type      = string
    size      = number
    encrypted = bool
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     type      = "standard"
  #     size      = 100
  #     encrypted = false
  #   },
  #   {
  #     type      = "gp2"
  #     size      = 300
  #     encrypted = true
  #   }
  # ]
}

variable "ebs_optimized" {
  description = "If true, the launched EC2 instance will be EBS-optimized."
  type        = bool
  default     = false
}

variable "root_volume_type" {
  description = "The type of volume. Must be one of: standard, gp2, or io1."
  type        = string
  default     = "gp2"
}

variable "root_volume_size" {
  description = "The size, in GB, of the root EBS volume."
  type        = number
  default     = 50
}

variable "root_volume_delete_on_termination" {
  description = "Whether the volume should be destroyed on instance termination."
  type        = bool
  default     = true
}

variable "wait_for_capacity_timeout" {
  description = "A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. Setting this to '0' causes Terraform to skip all Capacity Waiting behavior."
  type        = string
  default     = "10m"
}

variable "health_check_type" {
  description = "The type of health check to use. Must be one of: EC2 or ELB. If you associate any load balancers with this server group via var.elb_names or var.alb_target_group_arns, you should typically set this parameter to ELB."
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Time, in seconds, after instance comes into service before checking health."
  type        = number
  default     = 600
}

variable "ssh_port" {
  description = "The port used for SSH connections"
  type        = number
  default     = 22
}

variable "tags" {
  description = "A map of key value pairs that represent custom tags to propagate to the resources that correspond to this logstash cluster."
  # NOTE: The underlying module used is the server-group module, which only allows specifying tags as key value pairs as
  # opposed to a list of tag objects.
  type    = map(string)
  default = {}

  # Example:
  #
  # default = {
  #   foo = "bar"
  # }
}
