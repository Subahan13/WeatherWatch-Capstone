output "api_base_url" {
  description = "Base URL of the HTTP API front door"
  value       = aws_apigatewayv2_api.http.api_endpoint
}

output "weather_endpoint" {
  description = "Full public URL to open in a browser or hit with curl"
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/weather?city=${var.default_city}"
}

output "lambda_function_name" {
  value = aws_lambda_function.api.function_name
}

output "lambda_execution_role_arn" {
  description = "Should end in /LabRole"
  value       = data.aws_iam_role.lab_role.arn
}

output "secret_name" {
  description = "Secret the handler reads at runtime (value set out of band)"
  value       = data.aws_secretsmanager_secret.api_key.name
}

output "table_name" {
  description = "DynamoDB table results are written to"
  value       = data.aws_dynamodb_table.store.name
}
