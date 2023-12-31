output "app_server_id" {
  value = aws_instance.app_server.id
}

output "app_server_ip" {
  value = aws_instance.app_server.public_ip
}

output "logstash_server_asg_names" {
  value = module.logstash.server_asg_names
}

output "es_server_asg_names" {
  value = module.es_cluster.server_asg_names
}

output "bucket" {
  value = aws_s3_bucket.s3_test_bucket.bucket
}

output "log_group" {
  value = aws_cloudwatch_log_group.cloudwatch_test_group.name
}

output "alb_url" {
  value = "${lower(var.alb_target_group_protocol)}://${aws_route53_record.elk_alb_subdomain.fqdn}"
}

output "sns_topic_name" {
  value = module.sns.topic_name
}

output "sns_topic_display_name" {
  value = module.sns.topic_display_name
}

output "sns_topic_arn" {
  value = module.sns.topic_arn
}
