class SQLGenerator:

    def __init__(self, yaml_loader):
        self.yaml_loader = yaml_loader

    def generate_column(self, column_name, column_config):

        column_type = column_config.get("type")

        if not column_type:
            raise ValueError(
                f"No type defined for column '{column_name}'"
            )

        sql = f"{column_name} {column_type}"

        if column_config.get("primary_key"):
            sql += " PRIMARY KEY"

        if column_config.get("nullable") is False:
            sql += " NOT NULL"

        if column_config.get("unique"):
            sql += " UNIQUE"

        if "default" in column_config:
            sql += f" DEFAULT {column_config['default']}"

        foreign_key = column_config.get("foreign_key")

        if foreign_key:

            foreign_table = foreign_key.get("table")
            foreign_column = foreign_key.get("column")

            if not foreign_table or not foreign_column:
                raise ValueError(
                    f"Invalid foreign key for '{column_name}'"
                )

            sql += (
                f" REFERENCES "
                f"{foreign_table}({foreign_column})"
            )

            on_delete = foreign_key.get("on_delete")

            if on_delete:
                sql += f" ON DELETE {on_delete}"

        return sql

    def generate_table(self, table):

        table_name = table.get("table")

        if not table_name:
            raise ValueError(
                "Table definition is missing 'table' field"
            )

        columns = table.get("columns")

        if not columns:
            raise ValueError(
                f"No columns defined for table '{table_name}'"
            )

        column_definitions = []

        for column_name, column_config in columns.items():

            column_sql = self.generate_column(
                column_name,
                column_config
            )

            column_definitions.append(column_sql)

        sql = (
            f"CREATE TABLE IF NOT EXISTS {table_name} (\n"
            f"    {',\n    '.join(column_definitions)}\n"
            f");"
        )

        return sql

    def generate_indexes(self, table):

        table_name = table.get("table")

        indexes = table.get("indexes", [])

        statements = []

        for index in indexes:

            columns = index.get("columns")

            if not columns:
                raise ValueError(
                    f"Index in '{table_name}' has no columns"
                )

            column_list = ", ".join(columns)

            index_name = (
                f"idx_{table_name}_"
                f"{'_'.join(columns)}"
            )

            sql = (
                f"CREATE INDEX IF NOT EXISTS "
                f"{index_name} "
                f"ON {table_name} ({column_list});"
            )

            statements.append(sql)

        return statements
    
    def extract_dependancies(self,table):
        dependancies=set()
        columns=table.get("columns",{})
        
        for column_name, column_config in columns.items():
            foreign_key=column_config.get("foreign_key")
            
            if not foreign_key:
                continue
            foreign_table=foreign_key.get("table")
                
            if not foreign_table:
                raise ValueError(
                    f"Foreign key in column "
                    f"'{column_name}' of the table"
                    f"'{table['table']}' is missing "
                    f"'table'"
                )
            
            dependancies.add(foreign_table)
        return dependancies
    
    def build_dependancy_graph(self,tables):
        
        table_names={
            tables["table"]
            for table in tables
        }
        
        graph={}
        
        for table in tables:
            table_name=table["table"]
            
            dependancies =self.extract_dependancies(table)
            
            for dependancy in dependancies:
                if dependancy not in table_names:
                    raise ValueError(
                        f"Table '{table_name}' depends on "
                        f"unknown table '{dependancy}'"
                    )
        
            graph[table_name]=dependancies
            
        return graph

    def generate_all(self):

        tables = self.yaml_loader.load_tables()

        sql_statements = []

        for table in tables:

            sql_statements.append(
                self.generate_table(table)
            )

            sql_statements.extend(
                self.generate_indexes(table)
            )

        return sql_statements