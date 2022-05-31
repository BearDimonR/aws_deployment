#!/bin/sh

. .env

export MYSQL_USER=$MYSQL_USER
export MYSQL_PASSWORD=$MYSQL_USER
export MYSQL_HOST=$MYSQL_USER
export MYSQL_DB=$MYSQL_USER
export MYSQL_PORT=$MYSQL_USER

cd app
venv/bin/gunicorn -b localhost:8000 app:app
