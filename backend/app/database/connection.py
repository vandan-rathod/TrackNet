import os
from pathlib import Path
import psycopg2 as pg
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
            database_url=os.getenv("DATABASE_URL")
            
            if database_url:
                self.connection=pg.connect(
                    database_url
                )
            self.connection = pg.connect(
                host=os.getenv("DB_HOST"),
                port=os.getenv("DB_PORT", "5432"),
                database=os.getenv("DB_NAME"),
                user=os.getenv("DB_USER"),
                password=os.getenv("DB_PASSWORD"),
                sslmode=os.getenv("DB_SSLMODE", "prefer")
            )

            return self.connection

        except pg.Error as error:
            self.connection = None

            raise RuntimeError(
                f"Database connection failed: {error}"
            ) from error

    def close(self):

        if self.connection is not None:

            try:
                self.connection.close()

            except pg.Error as error:
                raise RuntimeError(
                    f"Failed to close database connection: {error}"
                ) from error

            finally:
                self.connection = None