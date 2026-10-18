# Edge node in a customer's AWS account. Private subnet, egress only, IMDSv2 enforced.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
    }
  }
}

variable "subnet_id" { type = string }
variable "vpc_id" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.medium"
}
variable "userdata" { type = any }

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

resource "aws_security_group" "edge" {
  name_prefix = "${var.userdata.edge_node}-"
  vpc_id      = var.vpc_id
  description = "Edge node: inbound syslog/OTLP from the site, outbound HTTPS"

  ingress {
    description = "OTLP from servers"
    from_port   = 4317
    to_port     = 4318
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  ingress {
    description = "Syslog from network devices"
    from_port   = 514
    to_port     = 514
    protocol    = "udp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "edge" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.edge.id]
  user_data_base64       = base64encode(var.userdata.user_data)

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = var.userdata.edge_node
  }

  lifecycle {
    ignore_changes = [user_data_base64]
  }
}

output "name" {
  value = aws_instance.edge.tags["Name"]
}
