from pathlib import Path
import os
import shutil
import sys

from dagster_dbt import DbtCliResource


def get_dbt_executable() -> str:
    dbt_executable = shutil.which("dbt")
    if dbt_executable:
        return dbt_executable

    venv_dbt = Path(sys.executable).parent / "dbt"
    if venv_dbt.exists():
        return str(venv_dbt)

    return "dbt"


_DEFAULT_STATEMENT_TIMEOUT_MS = "1200000"


def _ensure_statement_timeout_env() -> None:
    if "DBT_STATEMENT_TIMEOUT_MS" not in os.environ:
        os.environ["DBT_STATEMENT_TIMEOUT_MS"] = _DEFAULT_STATEMENT_TIMEOUT_MS


def get_dbt_resource(project_dir: Path, target: str = "dev") -> DbtCliResource:
    _ensure_statement_timeout_env()
    return DbtCliResource(
        project_dir=str(project_dir),
        profiles_dir=str(project_dir),
        target=target,
        dbt_executable=get_dbt_executable(),
    )
