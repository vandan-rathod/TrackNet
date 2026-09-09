class DatabaseExecutor:

    def __init__(self, connection):
        self.connection = connection

    def execute(self, sql):

        cursor = self.connection.cursor()

        try:
            cursor.execute(sql)
            self.connection.commit()

        except Exception as error:
            self.connection.rollback()

            raise RuntimeError(
                f"SQL execution failed: {error}"
            ) from error

        finally:
            cursor.close()

    def execute_many(self, sql_statements):

        cursor = self.connection.cursor()

        try:

            for sql in sql_statements:
                cursor.execute(sql)

            self.connection.commit()

        except Exception as error:
            self.connection.rollback()

            raise RuntimeError(
                f"Database initialization failed: {error}"
            ) from error

        finally:
            cursor.close()