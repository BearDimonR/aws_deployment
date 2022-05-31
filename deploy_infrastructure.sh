#!/bin/sh

cd infrastructure

terraform init
terraform apply -auto-approve

MYSQL_PASSWORD=$(terraform output -raw rds_db_password)
MYSQL_HOST=$(terraform output -raw rds_instance_public_ip)
MYSQL_USER=$(terraform output -raw rds_db_username)
MYSQL_PORT=$(terraform output -raw rds_db_port)
MYSQL_DB=$MYSQL_USER

EC2_HOST=$(terraform output -raw instance_public_dns)
EC2_PUBLIC_IP=$(terraform output -raw elastic_public_ip)
EC2_KEY_NAME=$(terraform output -raw instance_ssh_key_name)
NAME_SERVERS=$(terraform output -json name_servers)

cd ..

echo "" > .env

echo "MYSQL_USER=${MYSQL_USER}" >> .env
echo "MYSQL_PASSWORD=${MYSQL_PASSWORD}" >> .env
echo "MYSQL_HOST=${MYSQL_HOST}" >> .env
echo "MYSQL_PORT=${MYSQL_PORT}" >> .env
echo "MYSQL_DB=${MYSQL_DB}" >> .env
echo "EC2_HOST=${EC2_HOST}" >> .env
echo "EC2_KEY_NAME=${EC2_KEY_NAME}" >> .env
echo "EC2_PUBLIC_IP=${EC2_PUBLIC_IP}" >> .env
echo "${NAME_SERVERS}" > .name_servers