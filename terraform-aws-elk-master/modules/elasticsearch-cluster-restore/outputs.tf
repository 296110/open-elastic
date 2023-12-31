output "lambda_name" {
  value = module.restore_lambda.function_name
}

output "lambda_arn" {
  value = module.restore_lambda.function_arn
}
