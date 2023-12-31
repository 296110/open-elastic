terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAMBDA FUNCTION THAT RESTORES A SNAPSHOT TO AN ELASTICSEARCH CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

module "restore_lambda" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda.git//modules/lambda?ref=v0.8.1"

  name        = var.name
  description = "Elasticsearch cluster restore"

  source_path = "${path.module}/restore"
  runtime     = var.lambda_runtime
  handler     = "index.handler"

  run_in_vpc = var.run_in_vpc
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  timeout     = 300
  memory_size = 128

  environment_variables = {
    ELASTICSEARCH_DNS          = var.elasticsearch_dns
    ELASTICSEARCH_PORT         = var.elasticsearch_port
    REPOSITORY                 = var.repository
    BUCKET                     = var.bucket
    PROTOCOL                   = var.protocol
    CLOUDWATCH_EVENT_RULE_NAME = "${var.name}-scheduled-notification"
    NOTIFICATION_FUNCTION_NAME = module.restore_notification_lambda.function_name
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE A LAMBDA FUNCTION THAT WILL BE INVOKED TO MONITOR RESTORE PROGRESSION
# ---------------------------------------------------------------------------------------------------------------------

module "restore_notification_lambda" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-lambda.git//modules/lambda?ref=v0.8.1"

  name        = "${var.name}-notification"
  description = "Restore notification lambda"

  source_path = "${path.module}/notification"
  runtime     = var.lambda_runtime
  handler     = "index.handler"

  timeout     = 300
  memory_size = 128

  run_in_vpc = var.run_in_vpc
  vpc_id     = var.vpc_id
  subnet_ids = var.subnet_ids

  environment_variables = {
    ELASTICSEARCH_DNS          = var.elasticsearch_dns
    ELASTICSEARCH_PORT         = var.elasticsearch_port
    REPOSITORY                 = var.repository
    PROTOCOL                   = var.protocol
    CLOUDWATCH_EVENT_RULE_NAME = "${var.name}-scheduled-notification"
  }
}

resource "aws_cloudwatch_event_rule" "scheduled_notification_job" {
  name                = "${var.name}-scheduled-notification"
  description         = "Event that runs the notification lambda function ${module.restore_notification_lambda.function_name} on a periodic schedule"
  schedule_expression = "rate(5 minutes)"
  is_enabled          = false
}

resource "aws_cloudwatch_event_target" "scheduled_notification_job" {
  rule      = aws_cloudwatch_event_rule.scheduled_notification_job.name
  target_id = "${var.name}-scheduled-notification-target"
  arn       = module.restore_notification_lambda.function_arn
}

resource "aws_lambda_permission" "allow_execution_from_cloudwatch" {
  statement_id  = "${var.name}-allow-execution-from-cloudwatch"
  action        = "lambda:InvokeFunction"
  function_name = module.restore_notification_lambda.function_arn
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.scheduled_notification_job.arn
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE RESTORE LAMBDA TO UPDATE CLOUDWATCH EVENT RULES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "restore_lambda_event_policy" {
  name   = "restore-lambda-event-policy"
  role   = module.restore_lambda.iam_role_id
  policy = data.aws_iam_policy_document.cloudwatch_event_policy_doc.json
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE RESTORE NOTIFICATION LAMBDA TO UPDATE CLOUDWATCH EVENT RULES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "restore_notification_lambda_event_policy" {
  name   = "restore-notification-lambda-event-policy"
  role   = module.restore_notification_lambda.iam_role_id
  policy = data.aws_iam_policy_document.cloudwatch_event_policy_doc.json
}

data "aws_iam_policy_document" "cloudwatch_event_policy_doc" {
  statement {
    effect = "Allow"

    actions = [
      "events:PutRule",
    ]

    resources = [aws_cloudwatch_event_rule.scheduled_notification_job.arn]
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE RESTORE LAMBDA TO UPDATE NOTIFICATION LAMBDA
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "restore_lambda_update_policy" {
  name   = "restore-lambda-update-policy"
  role   = module.restore_lambda.iam_role_id
  policy = data.aws_iam_policy_document.lambda_update_policy_doc.json
}

data "aws_iam_policy_document" "lambda_update_policy_doc" {
  statement {
    effect = "Allow"

    actions = [
      "lambda:UpdateFunctionConfiguration",
    ]

    resources = [module.restore_notification_lambda.function_arn]
  }
}
