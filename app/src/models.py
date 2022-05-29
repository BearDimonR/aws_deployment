import uuid
import flask_sqlalchemy

from src.binary_uuid import BinaryUUID

db = flask_sqlalchemy.SQLAlchemy()


class Book(db.Model):
    __tablename__ = 'book'

    id = db.Column(BinaryUUID, primary_key=True, default=uuid.uuid4)
    isbn = db.Column(db.String(13))
    book_title = db.Column(db.String(50))
    category_name = db.Column(db.String(30))
    date_of_publication = db.Column(db.DATE)
    price = db.Column(db.FLOAT)
    copies = db.Column(db.SMALLINT)

    def as_dict(self):
        return {c.name: getattr(self, c.name) for c in self.__table__.columns}
