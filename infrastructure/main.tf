# main.tf
provider "aws" {
  region = "us-east-2"
}

variable "hostname" {
  type = string
  default = "sbtree.ml"
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
  egress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "mysql-tcp"
      source_security_group_id = module.db_sg.security_group_id
    }
  ]
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
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "sb_backend_ec2_key"

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
}

# resource block for eip #
resource "aws_eip" "ec2_eip" {
  vpc      = true
}

# resource block for ec2 and eip association #
resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.sb.id
  allocation_id = aws_eip.ec2_eip.id
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.sb.id
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.sb.public_ip
}

output "elastic_public_ip" {
  description = "Elastic public IP address of the EC2 instance"
  value       = aws_eip_association.eip_assoc.public_ip
}

output "instance_public_dns" {
  description = "Public HOSTNAME of the EC2 instance"
  value       = aws_instance.sb.public_dns
}

output "instance_ssh_key_name" {
  description = "SSH key name of the EC2 instance"
  value       = aws_instance.sb.key_name
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
  vpc_id      = data.aws_vpc.sb_vpc.id

  ingress_with_source_security_group_id = [
    {
      description              = "db access"
      rule                     = "mysql-tcp"
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
  skip_final_snapshot       = true
  port                      = "3306"
  final_snapshot_identifier = "sb_db_postgres"

  family               = "mysql8.0"
  major_engine_version = "8.0"

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

output "rds_dns" {
  description = "Public RDS instance endpoint"
  value       = module.db.this_db_instance_endpoint
}


### HOST
resource "aws_route53_zone" "host" {
  name = var.hostname
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