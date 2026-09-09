import os
from pathlib import Path
import psycopg2
from dotenv import load_dotenv

# SIH/backend/.env
BASE_DIR = Path(__file__).resolve().parents[2]
ENV_FILE = BASE_DIR / ".env"

load_dotenv(ENV_FILE)


class DatabaseConnection:

    def __init__(self):
        self.connection = None

    def connect(self):

        if self.connection is not None:
            return self.connection

        try:
            self.connection = psycopg2.connect(
                host=os.getenv("DB_HOST"),
                port=os.getenv("DB_PORT", "5432"),
                database=os.getenv("DB_NAME"),
                user=os.getenv("DB_USER"),
                password=os.getenv("DB_PASSWORD"),
                sslmode=os.getenv("DB_SSLMODE", "prefer")
            )

            return self.connection

        except psycopg2.Error as error:
            self.connection = None

            raise RuntimeError(
                f"Database connection failed: {error}"
            ) from error

    def close(self):

        if self.connection is not None:

            try:
                self.connection.close()

            except psycopg2.Error as error:
                raise RuntimeError(
                    f"Failed to close database connection: {error}"
                ) from error

            finally:
                self.connection = None