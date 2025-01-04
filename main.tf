provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

resource "aws_iot_thing" "iot_thing" {
  name = "MyIoTThing"
}

resource "aws_iot_policy" "iot_policy" {
  name = "MyIoTPolicy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["iot:Connect", "iot:Publish", "iot:Subscribe", "iot:Receive"],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iot_certificate" "iot_certificate" {
  active = true
}

resource "aws_iot_thing_principal_attachment" "thing_principal_attachment" {
  thing     = aws_iot_thing.iot_thing.name
  principal = aws_iot_certificate.iot_certificate.arn
}

resource "aws_iot_policy_attachment" "policy_attachment" {
  policy = aws_iot_policy.iot_policy.name
  target = aws_iot_certificate.iot_certificate.arn
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lam/index.mjs"
  output_path = "lam/lambda_function_payload.zip"
}

resource "aws_lambda_function" "iot_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lam/lambda_function_payload.zip"
  function_name = "lambda_function_name1"
  role          = aws_iam_role.iot_lambda_role.arn
  handler       = "index.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs18.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_iam_role" "iot_lambda_role" {
  name = "iot_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Type: AWS::Lambda::Permission
# Properties:
#   Action: lambda:InvokeFunction
#   FunctionName: !Ref function_name
#   Principal: "iot.amazonaws.com"
#   SourceAccount: account-id
#   SourceArn: arn:aws:iot:region:account-id:rule/rule_name



resource "aws_lambda_permission" "with_iot" {
  statement_id   = "IotRuleInvokeFun"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.iot_lambda.function_name
  principal      = "iot.amazonaws.com"
  source_arn     = aws_iot_topic_rule.data_in_rule.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_iam_role_policy_attachment" "iot_lambda_basic_execution" {
  role       = aws_iam_role.iot_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iot_topic_rule" "data_in_rule" {
  name = "DataInRule"

  sql         = "SELECT * FROM '/data/in/#'"
  sql_version = "2016-03-23"

  lambda {
    function_arn = aws_lambda_function.iot_lambda.arn
  }

  error_action {
    lambda {
      function_arn = aws_lambda_function.iot_lambda.arn
    }
  }

  depends_on = [aws_lambda_permission.allow_iot]
  enabled    = true
}

resource "aws_lambda_permission" "allow_iot" {
  statement_id  = "AllowExecutionFromIoT"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.iot_lambda.function_name
  principal     = "iot.amazonaws.com"
}

resource "local_file" "cert" {
  content  = aws_iot_certificate.iot_certificate.certificate_pem
  filename = "cert.pem"
}

resource "local_file" "private_key" {
  content  = aws_iot_certificate.iot_certificate.private_key
  filename = "private_key.pem"
}

output "certificate_pem" {
  value       = aws_iot_certificate.iot_certificate.certificate_pem
  description = "The certificate PEM to use with the Paho library"
  sensitive   = true
}

output "private_key" {
  value       = aws_iot_certificate.iot_certificate.private_key
  description = "The private key to use with the Paho library"
  sensitive   = true
}

output "iot_endpoint" {
  value       = data.aws_iot_endpoint.iot_endpoint.endpoint_address
  description = "The IoT Endpoint to use with the Paho library"
}

data "aws_iot_endpoint" "iot_endpoint" {
  endpoint_type = "iot:Data-ATS"
}
