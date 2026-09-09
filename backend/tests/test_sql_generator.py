import importlib.util
from pathlib import Path
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "app" / "database" / "SQL_generator.py"
SPEC = importlib.util.spec_from_file_location("sql_generator", MODULE_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
SQLGenerator = MODULE.SQLGenerator


class Loader:
    def __init__(self, tables):
        self.tables = tables

    def load_tables(self):
        return self.tables


class SQLGeneratorTests(unittest.TestCase):
    def test_generates_schema_from_list_based_yaml_and_orders_dependencies(self):
        generator = SQLGenerator(Loader([
            {
                "table": "detections",
                "columns": [{
                    "name": "vehicle_id",
                    "type": "INTEGER",
                    "not_null": True,
                    "foreign_key": {
                        "references_table": "vehicles",
                        "references_column": "id",
                        "on_delete": "CASCADE",
                    },
                }],
            },
            {
                "table": "vehicles",
                "columns": [{"name": "id", "type": "SERIAL", "primary_key": True}],
                "indexes": [{"name": "idx_vehicles_id", "columns": ["id"]}],
            },
        ]))

        statements = generator.generate_all()

        self.assertTrue(statements[0].startswith("CREATE TABLE IF NOT EXISTS vehicles"))
        self.assertIn(
            "vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE",
            statements[1],
        )
        self.assertEqual(
            statements[2],
            "CREATE INDEX IF NOT EXISTS idx_vehicles_id ON vehicles (id);",
        )

    def test_generates_checks_constraints_and_specialized_indexes(self):
        generator = SQLGenerator(Loader([{
            "table": "alerts",
            "columns": [{
                "name": "severity",
                "type": "TEXT",
                "check": "severity IN ('LOW', 'HIGH')",
            }],
            "constraints": [{"name": "chk_alert", "expression": "severity IS NOT NULL"}],
            "indexes": [{
                "name": "idx_alerts_active",
                "type": "GIST",
                "columns": ["severity"],
                "partial": "WHERE severity IS NOT NULL",
            }],
        }]))

        statements = generator.generate_all()

        self.assertIn("CHECK (severity IN ('LOW', 'HIGH'))", statements[0])
        self.assertIn("CONSTRAINT chk_alert CHECK (severity IS NOT NULL)", statements[0])
        self.assertEqual(
            statements[1],
            "CREATE INDEX IF NOT EXISTS idx_alerts_active ON alerts USING GIST "
            "(severity) WHERE severity IS NOT NULL;",
        )

    def test_rejects_circular_dependencies(self):
        generator = SQLGenerator(Loader([
            {"table": "alpha", "columns": [{"name": "beta_id", "type": "INTEGER", "foreign_key": {"references_table": "beta", "references_column": "id"}}]},
            {"table": "beta", "columns": [{"name": "id", "type": "INTEGER", "foreign_key": {"references_table": "alpha", "references_column": "beta_id"}}]},
        ]))

        with self.assertRaisesRegex(ValueError, "Circular table dependency"):
            generator.generate_all()


if __name__ == "__main__":
    unittest.main()
