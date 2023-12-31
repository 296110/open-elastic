terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS LOGSTASH INPUT PLUGINS ACCESS VARIOUS AWS RESOURCES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "logstash" {
  name   = "logstash"
  role   = var.iam_role_id
  policy = data.aws_iam_policy_document.logstash.json
}

data "aws_iam_policy_document" "logstash" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }

  # Cloudwatch
  statement {
    effect = "Allow"

    actions = [
      "logs:Describe*",
      "logs:Get*",
      "logs:List*",
      "logs:TestMetricFilter",
      "logs:FilterLogEvents",
    ]

    resources = ["*"]
  }

  # S3
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]

    resources = var.bucket_arns
  }
}
