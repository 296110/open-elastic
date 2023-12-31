output "server_asg_names" {
  value = module.logstash_cluster.server_asg_names
}

output "security_group_id" {
  value = module.logstash_cluster.security_group_id
}

output "iam_role_id" {
  value = module.logstash_cluster.iam_role_id
}
