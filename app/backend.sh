#!/bin/sh

. ../.env

export MYSQL_USER=$MYSQL_USER
export MYSQL_PASSWORD=$MYSQL_PASSWORD
export MYSQL_HOST=$MYSQL_HOST
export MYSQL_DB=$MYSQL_DB
export MYSQL_PORT=$MYSQL_PORT

cd app
source venv/bin/activate
gunicorn -b localhost:8000 app:app
