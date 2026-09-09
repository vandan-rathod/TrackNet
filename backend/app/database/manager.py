from app.database.yaml_loader import YAMLLoader
from app.database.SQL_generator import SQLGenerator
from app.database.connection import DatabaseConnection
from app.database.executor import DatabaseExecutor


class DatabaseManager:

    def __init__(self, yaml_path):
        self.loader = YAMLLoader(yaml_path)
        self.generator = SQLGenerator(self.loader)
        self.connection = DatabaseConnection()

    def initialize(self):
    
        try:
            connection = self.connection.connect()
    
            executor = DatabaseExecutor(connection)
    
            sql_statements = self.generator.generate_all()
    
            executor.execute_many(sql_statements)
    
        except Exception as error:
            raise RuntimeError(
                f"Database initialization failed: {error}"
            ) from error

    def close(self):
        self.connection.close()