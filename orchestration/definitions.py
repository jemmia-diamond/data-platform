from pathlib import Path
from dagster import Definitions
from .assets import all_assets
from .resources import all_resources
from .schedules import all_schedules

# dbt project path
DBT_PROJECT_DIR = Path(__file__).parent.parent / "transformation"

defs = Definitions(
    assets=all_assets,
    schedules=all_schedules,
    resources=all_resources(DBT_PROJECT_DIR, target="dev"),
)
