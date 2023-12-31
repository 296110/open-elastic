# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "name" {
  description = "The name of the Lambda function. Used to namespace all resources created by this module."
  type        = string
}

variable "schedule_expression" {
  description = "An expression that defines the schedule for this lambda job. For example, cron(0 20 * * ? *) or rate(5 minutes)."
  type        = string
}

variable "alarm_period" {
  description = "How often, in seconds, the backup lambda function is expected to run. You should factor in the amount of time it takes to backup your cluster."
  type        = number
}

variable "elasticsearch_dns" {
  description = "The DNS to the Load Balancer in front of the Elasticsearch cluster"
  type        = string
}

variable "repository" {
  description = "The name of the repository that will be associated with the created snapshots"
  type        = string
}

variable "bucket" {
  description = "The S3 bucket that the specified repository will be associated with and where all snapshots will be stored"
  type        = string
}

variable "cloudwatch_metric_name" {
  description = "The name for the CloudWatch Metric the AWS lambda backup function will increment every time the job completes successfully."
  type        = string
}

variable "cloudwatch_metric_namespace" {
  description = "The namespace for the CloudWatch Metric the AWS lambda backup function will increment every time the job completes successfully."
  type        = string
}

variable "alarm_sns_topic_arns" {
  description = "The ARN of SNS topics to notify if the CloudWatch alarm goes off because the backup job failed."
  type        = list(string)
}

variable "region" {
  description = "The AWS region (e.g us-east-1) where the backup S3 bucket exists."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "elasticsearch_port" {
  description = "The port on which the API requests will be made to the Elasticsearch cluster"
  type        = number
  default     = 9200
}

variable "protocol" {
  description = "Specifies the protocol to use when making the request to the Elasticsearch cluster. Possible values are HTTP or HTTPS"
  type        = string
  default     = "http"
}

variable "run_in_vpc" {
  description = "Set to true to give your Lambda function access to resources within a VPC."
  type        = bool
  default     = false
}

variable "vpc_id" {
  description = "The ID of the VPC the Lambda function should be able to access. Only used if var.run_in_vpc is true."
  type        = string
  default     = null
}

variable "subnet_ids" {
  description = "A list of subnet IDs the Lambda function should be able to access within your VPC. Only used if var.run_in_vpc is true."
  type        = list(string)
  default     = []
}

variable "lambda_runtime" {
  description = "The runtime to use for the Lambda function. Should be a Node.js runtime."
  type        = string
  default     = "nodejs14.x"
}
