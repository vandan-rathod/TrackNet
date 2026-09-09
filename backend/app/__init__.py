from flask import Flask

from app.database.manager import DatabaseManager


def create_app():

    app = Flask(__name__)

    database = DatabaseManager(
        "backend/config/tables.yaml"
    )

    database.initialize()

    @app.route("/health", methods=["GET"])
    def health():
        return {
            "status": "ok",
            "message": "TrackNet backend is running"
        }

    return app