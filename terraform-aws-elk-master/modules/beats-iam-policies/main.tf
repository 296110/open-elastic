terraform {
  # This module is now only being tested with Terraform 1.0.x. However, to make upgrading easier, we are setting
  # 0.12.26 as the minimum version, as that version added support for required_providers with source URLs, making it
  # forwards compatible with 1.0.x code.
  required_version = ">= 0.12.26"
}

# ---------------------------------------------------------------------------------------------------------------------
# ATTACH AN IAM POLICY THAT ALLOWS BEATS TO ACCESS VARIOUS AWS RESOURCES
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role_policy" "beats" {
  name   = "beats"
  role   = var.iam_role_id
  policy = data.aws_iam_policy_document.beats.json
}

data "aws_iam_policy_document" "beats" {
  # ASG
  statement {
    effect = "Allow"

    actions = [
      "autoscaling:DescribeAutoScalingGroups",
    ]

    resources = ["*"]
  }

  # EC2
  statement {
    effect = "Allow"

    actions = [
      "ec2:DescribeInstances",
    ]

    resources = ["*"]
  }
}
