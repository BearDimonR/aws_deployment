import os
from dotenv import load_dotenv

load_dotenv()

# DATABASE
user = os.environ['MYSQL_USER']
password = os.environ['MYSQL_PASSWORD']
host = os.environ['MYSQL_HOST']
database = os.environ['MYSQL_DB']
port = os.environ['MYSQL_PORT']

DATABASE_CONNECTION_URI = f'mysql+pymysql://{user}:{password}@{host}:{port}/{database}'
