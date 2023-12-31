output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "eni_elastic_ips" {
  value = module.elk_cluster.eni_elastic_ips
}

output "server_asg_names" {
  value = module.elk_cluster.server_asg_names
}

output "key_name" {
  value = var.key_name
}

output "bucket" {
  value = aws_s3_bucket.s3_test_bucket.bucket
}

output "log_group" {
  value = aws_cloudwatch_log_group.cloudwatch_test_group.name
}
