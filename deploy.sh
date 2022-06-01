#!/bin/sh

# import .env
. .env

# certificate name
EC2_KEY_NAME_WITH_EXTENSION="${EC2_KEY_NAME}.pem"

# add permission to the certificate
chmod 400 $EC2_KEY_NAME_WITH_EXTENSION
# copy .env to the ec2
scp -i $EC2_KEY_NAME_WITH_EXTENSION .env ec2-user@$EC2_PUBLIC_IP:/home/ec2-user/
# establish ssh and execute the following script
ssh -tt -i $EC2_KEY_NAME_WITH_EXTENSION ec2-user@$EC2_PUBLIC_IP << "ENDSSH"
# install git
sudo yum install git -y

set -a

# clone current repo into ec2
git clone "https://github.com/BearDimonR/aws_deployment.git"

# import .env
. .env

# move .env file to the project root
mv .env /home/ec2-user/aws_deployment

cd aws_deployment

# pull changes if they exist
git pull


# setup Flask project
cd app

python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt

cd ..

# start backend service
chmod +x app/backend.sh
sudo cp app/backend.service /etc/systemd/system/backend.service
sudo systemctl daemon-reload
sudo systemctl start backend
sudo systemctl enable backend

# install nginx and stop it to configure SSL
sudo amazon-linux-extras install nginx1 -y
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl stop nginx

# install certbot
sudo wget -r --no-parent -A 'epel-release-*.rpm' https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/
sudo rpm -Uvh dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-*.rpm
sudo yum-config-manager --enable epel*
sudo yum install -y certbot 
sudo yum install -y python-certbot-nginx

# generate sertificate for your domain
sudo certbot certonly --noninteractive --agree-tos --standalone --debug -d $DOMAIN_NAME -m $DOMAIN_EMAIL

# create nginx.conf from template replacing the DOMAIN_NAME with actual and restart nginx
envsubst '${DOMAIN_NAME}' < nginx_ec2.conf.template > nginx_ec2.conf
sudo cp nginx_ec2.conf  /etc/nginx/nginx.conf

sudo systemctl restart nginx

set +a

exit

ENDSSH