terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS THE ELASTICSEARCH NODES TO AUTOMATICALLY DISCOVER EACH OTHER AND FORM A CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "elasticsearch" {
  name   = var.policy_name
  role   = var.iam_role_id
  policy = data.aws_iam_policy_document.elasticsearch.json
}

data "aws_iam_policy_document" "elasticsearch" {
  # Allow access to publish to the specified SNS topic
  statement {
    effect = "Allow"

    actions = [
      "sns:Publish",
    ]

    resources = [var.sns_topic_arn]
  }
}
