output "lambda_name" {
  value = module.backup_lambda.function_name
}

output "lambda_arn" {
  value = module.backup_lambda.function_arn
}
