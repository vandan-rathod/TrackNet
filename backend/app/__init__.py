from pathlib import Path

from flask import Flask

from app.database.manager import DatabaseManager


def create_app(config_directory=None):
    app = Flask(__name__)

    database = DatabaseManager(
        config_directory or Path(__file__).resolve().parents[1] / "config" / "files"
    )

    database.initialize()
    app.extensions["database"] = database

    @app.route("/health", methods=["GET"])
    def health():
        return {
            "status": "ok",
            "message": "TrackNet backend is running"
        }

    return app
