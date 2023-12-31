# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "vpc_id" {
  description = "The id of the vpc into which we will deploy Elasticsearch"
  type        = string
}

variable "subnet_ids" {
  description = "The ids of the subnets "
  type        = list(string)
}

variable "ami_id" {
  description = "The AMI id of our custom AMI with Elasticsearch installed"
  type        = string
}

variable "elasticsearch_cluster_name" {
  description = "The name you want to give to this Elasticsearch cluster"
  type        = string
}

variable "instance_type" {
  description = "The instance type for each of the cluster members. eg: t2.micro"
  type        = string
}

variable "alowable_ssh_cidr_blocks" {
  description = "The CIDR blocks from which SSH connections will be allowed"
  type        = list(string)
  default     = []
}

variable "allowed_cidr_blocks" {
  description = "The CIDR blocks from which we can connect to nodes of this cluster"
  type        = list(string)
  default     = []
}

variable "allowed_ssh_security_group_ids" {
  description = "A list of security group IDs from which the EC2 Instances will allow SSH connections"
  type        = list(string)
  default     = []
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

variable "cluster_size" {
  description = "The number of nodes this cluster should have"
  type        = number
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "target_group_arns" {
  description = "A list of target group ARNs to associate with the Elasticsearch cluster."
  type        = list(string)
  default     = []
}

variable "skip_rolling_deploy" {
  description = "If set to true, skip the rolling deployment, and destroy all the servers immediately. You should typically NOT enable this in prod, as it will cause downtime! The main use case for this flag is to make testing and cleanup easier. It can also be handy in case the rolling deployment code has a bug."
  type        = bool
  default     = false
}

variable "num_enis_per_node" {
  description = "The number of ENIs each node in this cluster should have."
  type        = number
  default     = 1
}

variable "key_name" {
  description = "The name of the Amazon EC2 Key Pair you wish to use for accessing this instance. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html?icmpid=docs_ec2_console#having-ec2-create-your-key-pair"
  type        = string
  default     = null
}

variable "user_data" {
  description = "The User Data script to run on each server when it is booting."
  type        = string
  default     = null
}

variable "api_port" {
  description = "This is the port that is used to access elasticsearch for user queries"
  type        = number
  default     = 9200
}

variable "backup_bucket_arn" {
  description = "A list of Amazon S3 bucket ARNs to grant the Elasticsearch instances access to"
  type        = string
  default     = "*"
}

variable "node_discovery_port" {
  description = "This is the port that is used internally by elasticsearch for cluster node discovery"
  type        = number
  default     = 9300
}

variable "tags" {
  description = "A map of key value pairs that represent custom tags to propagate to the resources that correspond to this ElasticSearch cluster."
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
