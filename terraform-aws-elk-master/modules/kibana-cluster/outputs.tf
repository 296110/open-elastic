output "kibana_security_group_id" {
  value = aws_security_group.kibana_sg.id
}

output "kibana_asg_name" {
  value = module.kibana_cluster.asg_name
}

output "kibana_launch_config_name" {
  value = aws_launch_configuration.launch_configuration.name
}

output "iam_role_arn" {
  value = aws_iam_role.instance_role.arn
}

output "iam_role_id" {
  value = aws_iam_role.instance_role.id
}
