output "elastalert_security_group_id" {
  value = aws_security_group.elastalert_sg.id
}

output "elastalert_asg_name" {
  value = module.elastalert.asg_name
}

output "iam_role_arn" {
  value = aws_iam_role.instance_role.arn
}

output "iam_role_id" {
  value = aws_iam_role.instance_role.id
}
