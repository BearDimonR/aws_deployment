# main.tf
provider "aws" {
  region = "us-east-2"
}

variable "hostname" {
  type = string
  default = "host.ml"
}

variable "key_name" {
  type = string
  default = "key_name"
}

variable "project" {
  type = string
  default = "terraform_project"
}

variable "rds_name_username" {
  type = string
  default = "mysql_database"
}

variable "rds_identifier" {
  type = string
  default = "awsdb"
}

data "aws_vpc" "project_vpc" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.project_vpc.id]
  }
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

### EC2

module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.project_vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]

  tags = {
    project = var.project
  }
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.project_vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
  egress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "mysql-tcp"
      source_security_group_id = module.db_sg.security_group_id
    }
  ]

  tags = {
    project = var.project
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "ec2_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    project = var.project
  }
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name

  tags = {
    project = var.project
  }
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2_policy"
  role = aws_iam_role.ec2_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = var.key_name

  root_block_device {
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
  EOF

  vpc_security_group_ids = [
    module.ec2_sg.security_group_id,
    module.dev_ssh_sg.security_group_id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    project = var.project
  }
}

# resource block for eip #
resource "aws_eip" "ec2_eip" {
  vpc      = true
}

# resource block for ec2 and eip association #
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.ec2_instance.id
  allocation_id = aws_eip.ec2_eip.id
}

output "elastic_public_ip" {
  description = "Elastic public IP address of the EC2 instance"
  value       = aws_eip_association.eip_assoc.public_ip
}

output "instance_ssh_key_name" {
  description = "SSH key name of the EC2 instance"
  value       = aws_instance.ec2_instance.key_name
}

### DATABASE


resource "random_password" "password" {
  length  = 16
  special = false
}

module "db_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "db_sg"
  description = "Security group for db_sg"
  vpc_id      = data.aws_vpc.project_vpc.id

  ingress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "mysql-tcp"
      source_security_group_id = module.ec2_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]

  tags = {
    project = var.project
  }
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = var.rds_identifier

  allocated_storage         = 15
  engine                    = "mysql"
  engine_version            = "8.0.28"
  instance_class            = "db.t3.micro"
  name                      = var.rds_name_username
  username                  = var.rds_name_username
  password                  = random_password.password.result
  skip_final_snapshot       = true
  port                      = "3306"
  final_snapshot_identifier = var.rds_name_username

  family               = "mysql8.0"
  major_engine_version = "8.0"

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [module.db_sg.security_group_id]

  tags = {
    project = var.project
  }

  subnet_ids = data.aws_subnets.all.ids

}

output "rds_instance_public_ip" {
  description = "Public IP address of the RDS instance"
  value       = module.db.this_db_instance_address
}

output "rds_db_username" {
  value       = module.db.this_db_instance_username
  description = "The password for RDS"
  sensitive   = true
}

output "rds_db_password" {
  value       = module.db.this_db_instance_password
  description = "The username for RDS"
  sensitive   = true
}

output "rds_db_port" {
  value       = module.db.this_db_instance_port
  description = "The port for RDS"
}


### HOST

resource "aws_route53_zone" "host" {
  name = var.hostname

  tags = {
    project = var.project
  }
}

resource "aws_route53_record" "redirect_ec2" {
  zone_id = aws_route53_zone.host.zone_id
  name    = var.hostname
  type    = "A"
  ttl     = "300"
  records = [ aws_eip_association.eip_assoc.public_ip ]
}

resource "aws_route53_record" "www_redirect_ec2" {
  zone_id = aws_route53_zone.host.zone_id
  name    = "www"
  type    = "A"
  ttl     = "300"
  records = [ aws_eip_association.eip_assoc.public_ip ]
}

output "name_servers" {
  value       = aws_route53_zone.host.name_servers
  description = "The nameservers for our domain"
}