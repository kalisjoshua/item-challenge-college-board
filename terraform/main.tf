terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region = var.aws_region
}

resource "random_string" "random" {
  length           = 4
  special          = false
}

resource "aws_dynamodb_table" "exams" {
  name           = var.dynamodb_table
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "sk"

  attribute {
    name = "id"
    type = "S"
  }
  
  attribute {
    name = "sk"
    type = "S"
  }

  global_secondary_index {
    name = "subject-index"
    hash_key = "subject"
    projection_type = "KEYS_ONLY"
  }

  attribute {
    name = "subject"
    type = "S"
  }
}

locals {
  routes = {
    create_item         = { method = "POST", path = "/api/items",               handler = "handlers/items.createItem" }
    list_items          = { method = "GET",  path = "/api/items",               handler = "handlers/items.listItems" }
    get_item            = { method = "GET",  path = "/api/items/{id}",          handler = "handlers/items.getItem" }
    update_item         = { method = "PUT",  path = "/api/items/{id}",          handler = "handlers/items.updateItem" }
    create_item_version = { method = "POST", path = "/api/items/{id}/versions", handler = "handlers/items.createItemVersion" }
    get_audit_trail     = { method = "GET",  path = "/api/items/{id}/audit",    handler = "handlers/items.getAuditTrail" }
  }
}

#========================================================================
// lambda setup
#========================================================================

resource "aws_s3_bucket" "lambda_bucket" {
  bucket_prefix = var.s3_bucket_prefix
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket = aws_s3_bucket.lambda_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "archive_file" "lambda_zip" {
  type = "zip"

  source_dir  = "${path.module}/../src"
  output_path = "${path.module}/../src.zip"
}

resource "aws_s3_object" "this" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key    = "src.zip"
  source = data.archive_file.lambda_zip.output_path

  etag = filemd5(data.archive_file.lambda_zip.output_path)
}

resource "aws_lambda_function" "item_handler" {
  depends_on = [aws_cloudwatch_log_group.lambda_logs]
  environment {
    variables = {
      DDB_TABLE = var.dynamodb_table
    }
  }
  for_each = local.routes
  function_name = "${var.lambda_name}-${each.key}-${random_string.random.id}"
  handler = each.value.handler
  role = aws_iam_role.lambda_exec.arn
  runtime = "nodejs22.x"
  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key = aws_s3_object.this.key
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}

resource "aws_cloudwatch_log_group" "lambda_logs" {
  for_each = local.routes
  name = "/aws/lambda/${var.lambda_name}-${each.key}-${random_string.random.id}"
  retention_in_days = var.lambda_log_retention
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.lambda_name}-${random_string.random.id}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid    = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_exec_role" {
  name = "${var.lambda_name}-${random_string.random.id}-exec-policy"

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:Query",
                "dynamodb:UpdateItem"
            ],
            "Resource": [
                "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}",
                "arn:aws:dynamodb:*:*:table/${var.dynamodb_table}/index/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_role.arn
}

#========================================================================
// API Gateway section
#========================================================================

resource "aws_apigatewayv2_api" "http_lambda" {
  name          = "${var.apigw_name}-${random_string.random.id}"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.http_lambda.id

  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn

    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
      }
    )
  }
  depends_on = [aws_cloudwatch_log_group.api_gw]
}

# ___ integration
resource "aws_apigatewayv2_integration" "apigw_lambda" {
  api_id = aws_apigatewayv2_api.http_lambda.id
  for_each = local.routes
  integration_uri = aws_lambda_function.item_handler[each.key].invoke_arn
  integration_type = "AWS_PROXY"
  integration_method = "POST"
}

# ___ routes
resource "aws_apigatewayv2_route" "lambda_routes" {
  api_id = aws_apigatewayv2_api.http_lambda.id
  for_each = local.routes
  route_key = "${each.value.method} ${each.value.path}"
  target = "integrations/${aws_apigatewayv2_integration.apigw_lambda[each.key].id}"
}

# ___ log groups
resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/${var.apigw_name}-${random_string.random.id}"
  retention_in_days = var.apigw_log_retention
}

# ___ lambda permissions
resource "aws_lambda_permission" "api_gw" {
  statement_id = "AllowExecutionFromAPIGateway-${each.key}"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.item_handler[each.key].function_name
  principal = "apigateway.amazonaws.com"
  for_each = local.routes
  source_arn = "${aws_apigatewayv2_api.http_lambda.execution_arn}/*/*"
}
