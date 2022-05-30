#!/bin/sh

. .env

EC2_KEY_NAME_WITH_EXTENSION="${EC2_KEY_NAME}.pem"

chmod 400 $EC2_KEY_NAME_WITH_EXTENSION
scp -i $EC2_KEY_NAME_WITH_EXTENSION .env ec2-user@$EC2_HOST:/home/ec2-user/
ssh -tt -i $EC2_KEY_NAME_WITH_EXTENSION ec2-user@$EC2_HOST << "ENDSSH"
sudo yum install git -y
git clone "https://github.com/BearDimonR/sbtree_test.git"

mv .env /home/ec2-user/sbtree_test

cd sbtree_test
git pull

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

sudo cp backend.service /etc/systemd/system/backend.service
sudo systemctl daemon-reload
sudo systemctl start backend
sudo systemctl enable backend

sudo apt-get nginx
sudo unlink /etc/nginx/sites-enabled/default
sudo cp nginx_ec2.conf /etc/nginx/sites-available/nginx_ec2.conf
ln -s /etc/nginx/sites-available/reverse-nginx_ec2.conf /etc/nginx/sites-enabled/nginx_ec2.conf
sudo systemctl start nginx
sudo systemctl enable nginx

exit

ENDSSH