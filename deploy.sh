#!/bin/sh

. .env

EC2_KEY_NAME_WITH_EXTENSION="${EC2_KEY_NAME}.pem"

chmod 400 $EC2_KEY_NAME_WITH_EXTENSION
scp -i $EC2_KEY_NAME_WITH_EXTENSION .env ec2-user@$EC2_PUBLIC_IP:/home/ec2-user/
ssh -tt -i $EC2_KEY_NAME_WITH_EXTENSION ec2-user@$EC2_PUBLIC_IP << "ENDSSH"
sudo yum install git -y
git clone "https://github.com/BearDimonR/sbtree_test.git"

mv .env /home/ec2-user/sbtree_test

cd sbtree_test

git pull

chmod +x backend.sh

cd app

python3 -m venv venv
source venv/bin/activate
pip3 install -r requirements.txt

cd ..

sudo cp backend.service /etc/systemd/system/backend.service
sudo systemctl daemon-reload
sudo systemctl start backend
sudo systemctl enable backend

sudo amazon-linux-extras install nginx1 -y
sudo systemctl start nginx
sudo systemctl enable nginx
sudo systemctl stop nginx

sudo wget -r --no-parent -A 'epel-release-*.rpm' https://dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/
sudo rpm -Uvh dl.fedoraproject.org/pub/epel/7/x86_64/Packages/e/epel-release-*.rpm
sudo yum-config-manager --enable epel*
sudo yum install -y certbot 
sudo yum install -y python-certbot-nginx

sudo certbot certonly --standalone --debug -d sbtree.ml --non-interactive --agree-tos -m webmaster@example.com

sudo cp nginx_ec2.conf  /etc/nginx/nginx.conf
sudo systemctl restart nginx

exit

ENDSSH