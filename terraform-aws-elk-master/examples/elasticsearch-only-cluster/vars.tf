# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "cluster_name" {
  description = "The name of the Elasticsearch cluster"
  type        = string
  default     = "ExampleESCluster"
}

variable "cluster_size" {
  description = "The number of nodes in this Elasticsearch cluster."
  type        = number
  default     = 3
}

variable "ami_id" {
  description = "The AMI which has Elasticsearch installed"
  type        = string
}

variable "route53_zone_name" {
  description = "The domain name of the Route53 Hosted Zone we want to use to create an Alias record."
  type        = string
}

variable "elasticsearch_api_port" {
  description = "The port on which Elasticsearch API should be accessed."
  type        = number
  default     = 9200
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
  default     = "us-east-1"
}

variable "instance_type" {
  type    = string
  default = "t2.large"
}

variable "use_ssl" {
  description = "Whether or not we want our Elasticsearch instance to use SSL encryption. If this is set to `true` don't forget to also set"
  type        = bool
  default     = false
}

variable "java_keystore_filename" {
  description = "The filename of the Java Keystore that will be on your AMI. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_certificate_password" {
  description = "The password of SSL certificate insode of the Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_password" {
  description = "The password of the Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_cert_alias" {
  description = "The alias that you gave to your certificate when you generated it and imported it into your Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "key_name" {
  description = "Optional name of key to be used to ssh into the cluster members"
  type        = string
  default     = null
}

variable "schedule_expression" {
  description = "The cron expression to schedule Elasticsearch backups. See valid values here: https://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html"
  type        = string
  default     = "rate(5 minutes)"
}

variable "alarm_period" {
  description = "How often, in seconds, the backup lambda function is expected to run. You should factor in the amount of time it takes to backup your cluster."
  type        = number
  default     = 360
}

variable "repository" {
  description = "The name of the Elasticsearch backup repository "
  type        = string
  default     = "es-backup-repository"
}
