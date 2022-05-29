from flask import Flask, jsonify
from sqlalchemy.exc import OperationalError

from config import DATABASE_CONNECTION_URI
from src.models import db, Book

app = Flask(__name__)


def init_app():
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SQLALCHEMY_DATABASE_URI'] = DATABASE_CONNECTION_URI
    app.app_context().push()
    db.init_app(app)
    try:
        db.create_all()
    except OperationalError:
        pass


init_app()


@app.route('/')
def hello_world():
    return 'Hello World!'


@app.route('/all')
def get_all():
    result = list(map(lambda val: val.as_dict(), Book.query.all()))
    return jsonify(result), 200


if __name__ == "__main__":
    app.run()
