# main.tf

provider "aws" {
  region = "us-east-1"
}

resource "aws_key_pair" "cybercity_key" {
  key_name   = "cybercity-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_vpc" "cybercity_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "cybercity_subnet" {
  vpc_id            = aws_vpc.cybercity_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.cybercity_vpc.id
}

resource "aws_security_group" "cybercity_sg" {
  name        = "cybercity-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.cybercity_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "cybercity_vm" {
  ami                         = "ami-0c02fb55956c7d316" # Ubuntu 20.04 LTS
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.cybercity_subnet.id
  key_name                    = aws_key_pair.cybercity_key.key_name
  vpc_security_group_ids      = [aws_security_group.cybercity_sg.id]
  associate_public_ip_address = true

  tags = {
    Name = "CyberCity-VM"
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              echo "CyberCity VM is Ready" > /home/ubuntu/status.txt
              EOF
}

resource "aws_dynamodb_table" "cybercrowds" {
  name           = "CyberCrowds"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "GuestID"
  range_key      = "Timestamp"

  attribute {
    name = "GuestID"
    type = "S"
  }

  attribute {
    name = "Timestamp"
    type = "N"
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach basic Lambda and DynamoDB permissions
resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamo_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBReadOnlyAccess"
}

# Archive the lambda function from local file
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/lambda_function.py"
  output_path = "${path.module}/lambda/lambda_function.zip"
}

# Create Lambda function
resource "aws_lambda_function" "cyber_lambda" {
  function_name = "CyberCityRecommendations"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec_role.arn
}

# Create HTTP API Gateway
resource "aws_apigatewayv2_api" "http_api" {
  name          = "CyberCityAPI"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.cyber_lambda.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cyber_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http_api.execution_arn}/*/*"
}

output "api_gateway_url" {
  value = aws_apigatewayv2_api.http_api.api_endpoint
}
