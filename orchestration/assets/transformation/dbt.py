from pathlib import Path
from dagster import AssetExecutionContext, Config
from dagster_dbt import DbtCliResource, dbt_assets, DbtProject
from .translator import TransformationDagsterDbtTranslator

DBT_PROJECT_DIR = Path(__file__).parent.parent.parent.parent / "transformation"

dbt_project = DbtProject(
    project_dir=DBT_PROJECT_DIR,
    packaged_project_dir=DBT_PROJECT_DIR,
)

if not dbt_project.manifest_path.exists():
    dbt_project.preparer.prepare(dbt_project)


class DbtFullRefreshConfig(Config):
    full_refresh: bool = False


@dbt_assets(
    manifest=dbt_project.manifest_path,
    project=dbt_project,
    dagster_dbt_translator=TransformationDagsterDbtTranslator(),
)
def transformation_dbt_assets(context: AssetExecutionContext, dbt: DbtCliResource, config: DbtFullRefreshConfig):
    args = ["build", "--indirect-selection", "cautious"]
    if config.full_refresh:
        args.append("--full-refresh")
    yield from dbt.cli(args, context=context).stream()
