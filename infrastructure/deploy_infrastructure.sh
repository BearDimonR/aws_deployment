#!/bin/sh

terraform init
terraform apply -auto-approve

MYSQL_PASSWORD=$(terraform output -raw rds_db_password)
MYSQL_HOST=$(terraform output -raw rds_instance_public_ip)
MYSQL_USER=$(terraform output -raw rds_db_username)
MYSQL_PORT=$(terraform output -raw rds_db_port)
MYSQL_DB=$MYSQL_USER

EC2_PUBLIC_IP=$(terraform output -raw elastic_public_ip)
EC2_KEY_NAME=$(terraform output -raw instance_ssh_key_name)
NAME_SERVERS=$(terraform output -json name_servers)

echo "" > .infrastructure_output

echo "MYSQL_USER=${MYSQL_USER}" >> .infrastructure_output
echo "MYSQL_PASSWORD=${MYSQL_PASSWORD}" >> .infrastructure_output
echo "MYSQL_HOST=${MYSQL_HOST}" >> .infrastructure_output
echo "MYSQL_PORT=${MYSQL_PORT}" >> .infrastructure_output
echo "MYSQL_DB=${MYSQL_DB}" >> .infrastructure_output
echo "EC2_KEY_NAME=${EC2_KEY_NAME}" >> .infrastructure_output
echo "EC2_PUBLIC_IP=${EC2_PUBLIC_IP}" >> .infrastructure_output
echo "${NAME_SERVERS}" > .name_servers