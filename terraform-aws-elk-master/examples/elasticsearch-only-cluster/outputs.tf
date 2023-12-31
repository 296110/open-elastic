output "eni_ips" {
  value = "[${join(",", formatlist("\"%s\"", module.es_cluster.eni_private_ips))}]"
}

output "server_asg_names" {
  value = module.es_cluster.server_asg_names
}

output "lb_dns_name" {
  value = module.alb.alb_dns_name
}
