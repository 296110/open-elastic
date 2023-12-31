terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAMBDA FUNCTION THAT BACKS UP AN ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "backup_lambda" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda.git//modules/lambda?ref=v0.8.1"

  name        = var.name
  description = "Scheduled Elasticsearch cluster backup"

  source_path = "${path.module}/backup"
  runtime     = var.lambda_runtime
  handler     = "index.handler"

  timeout     = 300
  memory_size = 128

  run_in_vpc = var.run_in_vpc
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  environment_variables = {
    ELASTICSEARCH_DNS    = var.elasticsearch_dns
    ELASTICSEARCH_PORT   = var.elasticsearch_port
    REPOSITORY           = var.repository
    BUCKET               = var.bucket
    PROTOCOL             = var.protocol
    S3_BUCKET_AWS_REGION = var.region
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# SCHEDULE THE LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

module "scheduled_lambda" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda.git//modules/scheduled-lambda-job?ref=v0.8.1"

  lambda_function_name = module.backup_lambda.function_name
  lambda_function_arn  = module.backup_lambda.function_arn
  schedule_expression  = var.schedule_expression
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAMBDA FUNCTION THAT WILL BE INVOKED ON SUCCESSFUL BACKUP
# ---------------------------------------------------------------------------------------------------------------------

module "notification_lambda" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda.git//modules/lambda?ref=v0.8.1"

  name        = "${var.name}-notification"
  description = "Backup notification lambda"

  source_path = "${path.module}/notification"
  runtime     = var.lambda_runtime
  handler     = "index.handler"

  timeout     = 300
  memory_size = 128

  run_in_vpc = var.run_in_vpc
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  environment_variables = {
    CLOUDWATCH_METRIC_NAME      = var.cloudwatch_metric_name
    CLOUDWATCH_METRIC_NAMESPACE = var.cloudwatch_metric_namespace
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# GIVE THE NOTIFICATION LAMBDA FUNCTION IAM PERMISSIONS TO PUT CLOUDWATCH METRIC DATA
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "notification_lambda" {
  role   = module.notification_lambda.iam_role_id
  policy = data.aws_iam_policy_document.notification_lambda.json
}

data "aws_iam_policy_document" "notification_lambda" {
  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:PutMetricData",
    ]

    resources = ["*"]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# PERMISSION TO ALLOW S3 BUCKET INVOKE NOTIFICATION LAMBDA FUNCTION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.notification_lambda.function_arn
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.bucket}"
}

# ---------------------------------------------------------------------------------------------------------------------
# INVOKE NOTIFICATION LAMBDA WHEN OBJECT ARE CREATED
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.bucket

  lambda_function {
    lambda_function_arn = module.notification_lambda.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [
    aws_lambda_permission.allow_bucket,
  ]
}

# ---------------------------------------------------------------------------------------------------------------------
# ADD A CLOUDWATCH ALARM THAT GOES OFF IF THE BACKUP JOB FAILS TO RUN
# ---------------------------------------------------------------------------------------------------------------------

module "backup_job_alarm" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-monitoring.git//modules/alarms/scheduled-job-alarm?ref=v0.22.1"

  name        = "${var.name}-backup-job-failed"
  namespace   = var.cloudwatch_metric_namespace
  metric_name = var.cloudwatch_metric_name
  period      = var.alarm_period

  alarm_sns_topic_arns = var.alarm_sns_topic_arns
}
