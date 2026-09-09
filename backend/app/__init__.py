from pathlib import Path
import os

from flask import Flask, jsonify
from flask_caching import Cache
from flask_sqlalchemy import SQLAlchemy
from werkzeug.exceptions import HTTPException

from app.database.manager import DatabaseManager

db = SQLAlchemy()
cache = Cache()


def create_app(config_directory=None):
    app = Flask(__name__)

    database = DatabaseManager(
        config_directory or Path(__file__).resolve().parents[1] / "config" / "files"
    )

    database.initialize()
    app.extensions["database"] = database

    app.config["SQLALCHEMY_DATABASE_URI"] = os.getenv(
        "DATABASE_URL",
        "postgresql+psycopg2://{user}:{password}@{host}:{port}/{name}".format(
            user=os.getenv("DB_USER", "postgres"),
            password=os.getenv("DB_PASSWORD", ""),
            host=os.getenv("DB_HOST", "localhost"),
            port=os.getenv("DB_PORT", "5432"),
            name=os.getenv("DB_NAME", "tracknet"),
        ),
    )
    app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False
    app.config["CACHE_TYPE"] = os.getenv("CACHE_TYPE", "SimpleCache")
    app.config["CACHE_DEFAULT_TIMEOUT"] = 30
    db.init_app(app)
    cache.init_app(app)

    from app.models import ProcessingJob
    with app.app_context():
        ProcessingJob.__table__.create(bind=db.engine, checkfirst=True)

    from app.routes.api import api_bp
    app.register_blueprint(api_bp, url_prefix="/api/v1")

    @app.route("/health", methods=["GET"])
    def health():
        return {
            "status": "ok",
            "message": "TrackNet backend is running"
        }

    @app.errorhandler(HTTPException)
    def handle_http_error(error):
        return jsonify({"data": None, "error": error.description}), error.code or 500

    @app.errorhandler(Exception)
    def handle_unexpected_error(error):
        db.session.rollback()
        return jsonify({"data": None, "error": "Internal server error"}), 500

    return app
