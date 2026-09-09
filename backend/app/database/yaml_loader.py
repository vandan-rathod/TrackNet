import yaml
from pathlib import Path


class YAMLLoader:

    def __init__(self, config_directory):
        self.config_directory = Path(config_directory)

    def load_file(self, file_path):
        if not file_path.exists():
            raise FileNotFoundError(
                f"YAML file not found: {file_path}"
            )

        try:
            with open(file_path, "r", encoding="utf-8") as file:
                data = yaml.safe_load(file)

        except yaml.YAMLError as error:
            raise ValueError(
                f"Invalid YAML configuration in {file_path}: {error}"
            ) from error

        except OSError as error:
            raise RuntimeError(
                f"Could not read YAML file {file_path}: {error}"
            ) from error

        if data is None:
            raise ValueError(
                f"YAML file is empty: {file_path}"
            )

        if not isinstance(data, dict):
            raise ValueError(
                f"YAML root must be an object: {file_path}"
            )

        return data

    def load_tables(self):
        if not self.config_directory.exists():
            raise FileNotFoundError(
                f"Configuration directory not found: "
                f"{self.config_directory}"
            )

        if not self.config_directory.is_dir():
            raise ValueError(
                f"Configuration path is not a directory: "
                f"{self.config_directory}"
            )

        yaml_files = sorted(
            self.config_directory.glob("*.yaml")
        )

        if not yaml_files:
            raise ValueError(
                f"No YAML files found in: "
                f"{self.config_directory}"
            )

        tables = []

        for yaml_file in yaml_files:
            table = self.load_file(yaml_file)

            if "table" not in table:
                raise ValueError(
                    f"Missing 'table' field in {yaml_file}"
                )

            tables.append(table)

        return tables

    def get_table(self, table_name):
        tables = self.load_tables()

        for table in tables:
            if table["table"] == table_name:
                return table

        raise ValueError(
            f"Table '{table_name}' not found"
        )