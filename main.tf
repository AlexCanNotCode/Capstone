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
