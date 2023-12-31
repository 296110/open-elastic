# ---------------------------------------------------------------------------------------------------------------------
# ENVIRONMENT VARIABLES
# Define these secrets as environment variables
# ---------------------------------------------------------------------------------------------------------------------

# AWS_ACCESS_KEY_ID
# AWS_SECRET_ACCESS_KEY

# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "ami_id" {
  description = "The AMI which has all ELK components installed"
  type        = string
}

variable "elk_cluster_name" {
  description = "The name of the ELK cluster"
  type        = string
  default     = "es-aio"
}

variable "elasticsearch_cluster_size" {
  description = "The number of nodes in this ELK cluster."
  type        = number
  default     = 1
}

variable "elasticsearch_api_port" {
  description = "This is the port that is used to access Elasticseach API"
  type        = number
  default     = 9200
}

variable "kibana_ui_port" {
  description = "This is the port that is used to access kibana UI"
  type        = number
  default     = 5601
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

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "key_name" {
  description = "The name of the Amazon EC2 Key Pair you wish to use for accessing this instance. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html?icmpid=docs_ec2_console#having-ec2-create-your-key-pair"
  type        = string
  default     = null
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "cloudtrail_dest_log_path" {
  description = "The path to the destination log file that Logstash will pipe cloudtrail logs to"
  type        = string
  default     = "/var/log/destination.log"
}

variable "elk_instance_type" {
  description = "The type of EC2 Instance to run for all of ELK components (e.g. m5.large)."
  type        = string
  default     = "m5.xlarge"
}

variable "filebeat_log_path" {
  description = "Path to the log file that will be watched by Filebeat"
  type        = string
  default     = "/var/log/source.log"
}

variable "alb_name" {
  description = "The name for the ALB. This is used for namespacing."
  type        = string
  default     = "elk-alb"
}
