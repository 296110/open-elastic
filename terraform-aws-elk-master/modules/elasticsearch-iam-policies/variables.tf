# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# You must provide a value for each of these parameters.
# ---------------------------------------------------------------------------------------------------------------------

variable "iam_role_id" {
  description = "The ID of the IAM Role to which these IAM policies should be attached"
  type        = string
}

variable "backup_bucket_arn" {
  description = "The Amazon S3 bucket ARNs to grant the Elasticsearch instances access to for storing backup snapshots"
  type        = string
  default     = "*"
}
