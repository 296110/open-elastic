# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "iam_role_id" {
  description = "The ID of the IAM Role to which these IAM policies should be attached"
  type        = string
}

variable "bucket_arns" {
  description = "A list of Amazon S3 bucket ARNs to grant the Logstash instance access to"
  type        = list(string)
  default     = ["*"]
}

