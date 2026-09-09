import re


class SQLGenerator:
    """Convert the database YAML definitions into ordered PostgreSQL DDL."""

    _IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

    def __init__(self, yaml_loader):
        self.yaml_loader = yaml_loader

    @classmethod
    def _identifier(cls, value, context):
        if not isinstance(value, str) or not cls._IDENTIFIER.fullmatch(value):
            raise ValueError(f"Invalid SQL identifier for {context}: {value!r}")
        return value

    def _columns(self, table):
        columns = table.get("columns")
        if not columns:
            raise ValueError(f"No columns defined for table '{table.get('table')}'")
        if isinstance(columns, list):
            normalized = []
            for column in columns:
                if not isinstance(column, dict) or "name" not in column:
                    raise ValueError("Each column must be an object with a 'name' field")
                normalized.append((column["name"], column))
            return normalized
        if isinstance(columns, dict):
            return list(columns.items())
        raise ValueError("Table columns must be a list or object")

    def generate_column(self, column_name, column_config):
        column_name = self._identifier(column_name, "column")
        if not isinstance(column_config, dict):
            raise ValueError(f"Column '{column_name}' must be an object")
        column_type = column_config.get("type")
        if not isinstance(column_type, str) or not column_type.strip():
            raise ValueError(f"No type defined for column '{column_name}'")

        parts = [column_name, column_type]
        if column_config.get("primary_key"):
            parts.append("PRIMARY KEY")
        if column_config.get("not_null") or column_config.get("nullable") is False:
            parts.append("NOT NULL")
        if column_config.get("unique"):
            parts.append("UNIQUE")
        if "default" in column_config:
            parts.append(f"DEFAULT {column_config['default']}")

        foreign_key = column_config.get("foreign_key")
        if foreign_key:
            if not isinstance(foreign_key, dict):
                raise ValueError(f"Invalid foreign key for '{column_name}'")
            foreign_table = foreign_key.get("references_table", foreign_key.get("table"))
            foreign_column = foreign_key.get("references_column", foreign_key.get("column"))
            parts.append(
                "REFERENCES "
                f"{self._identifier(foreign_table, 'foreign table')}"
                f"({self._identifier(foreign_column, 'foreign column')})"
            )
            on_delete = foreign_key.get("on_delete")
            if on_delete:
                parts.append(f"ON DELETE {on_delete}")
        check = column_config.get("check")
        if check:
            parts.append(f"CHECK ({check})")
        return " ".join(parts)

    def generate_table(self, table):
        table_name = self._identifier(table.get("table"), "table")
        definitions = [
            self.generate_column(column_name, column_config)
            for column_name, column_config in self._columns(table)
        ]
        for constraint in table.get("constraints", []):
            if not isinstance(constraint, dict) or not constraint.get("expression"):
                raise ValueError(f"Invalid constraint in table '{table_name}'")
            name = self._identifier(constraint.get("name"), "constraint")
            definitions.append(f"CONSTRAINT {name} CHECK ({constraint['expression']})")
        return (
            f"CREATE TABLE IF NOT EXISTS {table_name} (\n"
            f"    {',\n    '.join(definitions)}\n"
            ");"
        )

    def generate_indexes(self, table):
        table_name = self._identifier(table.get("table"), "table")
        statements = []
        for index in table.get("indexes", []):
            if not isinstance(index, dict):
                raise ValueError(f"Invalid index in table '{table_name}'")
            columns = index.get("columns")
            if not isinstance(columns, list) or not columns:
                raise ValueError(f"Index in '{table_name}' has no columns")
            columns = [self._identifier(column, "index column") for column in columns]
            index_name = index.get("name") or f"idx_{table_name}_{'_'.join(columns)}"
            index_name = self._identifier(index_name, "index")
            index_type = index.get("type")
            using = f" USING {index_type}" if index_type else ""
            partial = index.get("partial")
            where = f" {partial}" if partial else ""
            statements.append(
                f"CREATE INDEX IF NOT EXISTS {index_name} ON {table_name}"
                f"{using} ({', '.join(columns)}){where};"
            )
        return statements

    def extract_dependencies(self, table):
        dependencies = set()
        table_name = self._identifier(table.get("table"), "table")
        for column_name, column_config in self._columns(table):
            foreign_key = column_config.get("foreign_key")
            if foreign_key:
                foreign_table = foreign_key.get("references_table", foreign_key.get("table"))
                dependencies.add(
                    self._identifier(foreign_table, f"foreign table for {table_name}.{column_name}")
                )
        dependencies.discard(table_name)
        return dependencies

    def _ordered_tables(self, tables):
        by_name = {}
        for table in tables:
            name = self._identifier(table.get("table"), "table")
            if name in by_name:
                raise ValueError(f"Duplicate table definition: '{name}'")
            by_name[name] = table

        dependencies = {name: self.extract_dependencies(table) for name, table in by_name.items()}
        for name, required in dependencies.items():
            unknown = required - by_name.keys()
            if unknown:
                raise ValueError(f"Table '{name}' depends on unknown table(s): {', '.join(sorted(unknown))}")

        ordered = []
        while dependencies:
            ready = sorted(name for name, required in dependencies.items() if not required)
            if not ready:
                raise ValueError(f"Circular table dependency: {', '.join(sorted(dependencies))}")
            for name in ready:
                ordered.append(by_name[name])
                del dependencies[name]
            completed = set(ready)
            for required in dependencies.values():
                required.difference_update(completed)
        return ordered

    def generate_all(self):
        tables = self._ordered_tables(self.yaml_loader.load_tables())
        statements = [self.generate_table(table) for table in tables]
        for table in tables:
            statements.extend(self.generate_indexes(table))
        return statements
