# ---------------------------------------------------------------------------
# LabRole — referenced, never created (Learner Lab denies iam:CreateRole).
# The Lambda runs under this role; it already permits Secrets Manager reads
# and DynamoDB writes in the lab account.
# ---------------------------------------------------------------------------
data "aws_iam_role" "lab_role" {
  name = var.lab_role_name
}

# ---------------------------------------------------------------------------
# The secret created in Phase 1 — looked up, not recreated. We only need its
# name to pass to the function; the value stays out of band.
# ---------------------------------------------------------------------------
data "aws_secretsmanager_secret" "api_key" {
  name = var.secret_name
}

# The DynamoDB table from Phase 0 — looked up so the plan fails loudly if it
# is missing, and so we can wire its name into the function.
data "aws_dynamodb_table" "store" {
  name = var.table_name
}

# ---------------------------------------------------------------------------
# Package the Lambda source into a zip Terraform can deploy.
# ---------------------------------------------------------------------------
data "archive_file" "api_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/build/api.zip"
}

# ---------------------------------------------------------------------------
# Lambda function — now makes the real external API call and writes to
# DynamoDB. Runs under LabRole. The secret's NAME and the table NAME are
# passed as env vars; neither the key value nor any credential is in here.
# ---------------------------------------------------------------------------
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-api"
  description   = "WeatherWatch Phase 2 — calls OpenWeatherMap, stores result in DynamoDB"

  filename         = data.archive_file.api_zip.output_path
  source_code_hash = data.archive_file.api_zip.output_base64sha256

  handler = "index.handler"
  runtime = "python3.12"
  timeout = 10

  role = data.aws_iam_role.lab_role.arn

  environment {
    variables = {
      OWM_SECRET_NAME = data.aws_secretsmanager_secret.api_key.name
      TABLE_NAME      = data.aws_dynamodb_table.store.name
      DEFAULT_CITY    = var.default_city
    }
  }
}

# ---------------------------------------------------------------------------
# API Gateway HTTP API — the public front door. A GET /weather route proxies
# to the Lambda. Browser-openable HTTPS endpoint.
# ---------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-http-api"
  protocol_type = "HTTP"
  description   = "Public front door for the WeatherWatch poller"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "get_weather" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /weather"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true

  # FIX (self-review F2): the public GET /weather route has no auth, so every
  # hit spends compute AND a paid OpenWeatherMap call. Stage-level throttling
  # caps the blast radius and runaway cost. Beyond the limits, API Gateway
  # returns HTTP 429. Pillars: Security + Cost.
  default_route_settings {
    throttling_rate_limit  = 10 # steady-state requests/sec
    throttling_burst_limit = 5  # burst ceiling
  }
}

# Allow API Gateway to invoke the function (resource-based permission).
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
