# main.tf
provider "aws" {
  region = "us-east-2"
}

data "aws_vpc" "sb_vpc" {
  default = true
}

data "aws_subnets" "all" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.sb_vpc.id]
  }
}


### ECR


resource "aws_ecr_repository" "sb_repo" {
  name                 = "sb_repo"
  image_tag_mutability = "MUTABLE"

  tags = {
    project = "sb"
  }
}


### EC2


module "dev_ssh_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.sb_vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
}

module "ec2_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "ec2_sg"
  description = "Security group for ec2_sg"
  vpc_id      = data.aws_vpc.sb_vpc.id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp", "https-443-tcp", "all-icmp"]
  egress_rules        = ["all-all"]
}

resource "aws_iam_role" "ec2_role_sb" {
  name = "ec2_role_sb"

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
    project = "sb"
  }
}

resource "aws_iam_instance_profile" "ec2_profile_sb" {
  name = "ec2_profile_sb"
  role = aws_iam_role.ec2_role_sb.name
}

resource "aws_iam_role_policy" "ec2_policy_sb" {
  name = "ec2_policy_sb"
  role = aws_iam_role.ec2_role_sb.id

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

resource "aws_instance" "sb" {
  ami           = "ami-0eea504f45ef7a8f7"
  instance_type = "t2.micro"

  root_block_device {
    volume_size = 8
  }

  user_data = <<-EOF
    #!/bin/bash
    set -ex
    sudo yum update -y
    sudo amazon-linux-extras install docker -y
    sudo service docker start
    sudo usermod -a -G docker ec2-user
    sudo curl -L https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  EOF

  vpc_security_group_ids = [
    module.ec2_sg.security_group_id,
    module.dev_ssh_sg.security_group_id
  ]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile_sb.name

  tags = {
    project = "sb"
  }

  monitoring              = true
  disable_api_termination = false
  ebs_optimized           = true
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sb.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sb.public_ip
}


### DATABASE


resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "db_sg" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "db_sg"
  description = "Security group for db_sg"
  vpc_id      = data.aws_vpc.sb_vpc.id

  ingress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "postgresql-tcp"
      source_security_group_id = module.ec2_sg.security_group_id
    }
  ]
  egress_rules = ["all-all"]
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 2.0"

  identifier = "sbdb"

  allocated_storage         = 15
  engine                    = "mysql"
  engine_version            = "8.0.28"
  instance_class            = "db.t3.micro"
  name                      = "sb_database"
  username                  = "sb_database"
  password                  = random_password.password.result
  parameter_group_name      = "sbmysql"
  skip_final_snapshot       = true
  port                      = "3306"
  final_snapshot_identifier = "sb_db_postgres"

  maintenance_window = "Mon:00:00-Mon:03:00"
  backup_window      = "03:00-06:00"

  iam_database_authentication_enabled = true

  vpc_security_group_ids = [module.db_sg.security_group_id]

  tags = {
    project = "sb"
  }

  subnet_ids = data.aws_subnets.all.ids

}


output "rds_instance_id" {
  description = "ID of the RDS instance"
  value       = module.db.this_db_instance_id
}

output "rds_instance_public_ip" {
  description = "Public IP address of the RDS instance"
  value       = module.db.this_db_instance_address
}

output "rds_db_password" {
  value       = module.db.this_db_instance_password
  description = "The password for RDS"
  sensitive   = true
}
