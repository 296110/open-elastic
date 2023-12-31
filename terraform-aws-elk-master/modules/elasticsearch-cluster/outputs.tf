output "eni_private_ips" {
  value = module.elasticsearch_cluster.eni_private_ips
}

output "eni_elastic_ips" {
  value = module.elasticsearch_cluster.eni_elastic_ips
}

output "server_asg_names" {
  value = module.elasticsearch_cluster.server_asg_names
}

output "security_group_id" {
  value = module.elasticsearch_cluster.security_group_id
}

output "iam_role_id" {
  value = module.elasticsearch_cluster.iam_role_id
}
