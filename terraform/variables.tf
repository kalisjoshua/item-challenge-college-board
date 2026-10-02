# Input variable definitions

variable "aws_region" {
  description = "AWS region for all resources"

  type    = string
  default = "us-east-1"
}

variable "s3_bucket_prefix" {
  description = "S3 bucket prefix"
  type = string
  default = "apigw-lambda-ddb"
  
}

variable "dynamodb_table" {
  description = "name of the DynamoDB table"
  type = string
  default = "Items"
  
}

variable "lambda_name" {
  description = "name of the lambda function"
  type = string
  default = "item-handler"
  
}

variable "apigw_name" {
  description = "name of the api gateway"
  type = string
  default = "apigw-http-lambda"
  
}

variable "lambda_log_retention" {
  description = "lambda log retention in days"
  type = number
  default = 7
}

variable "apigw_log_retention" {
  description = "api gateway log retention in days"
  type = number
  default = 7
}