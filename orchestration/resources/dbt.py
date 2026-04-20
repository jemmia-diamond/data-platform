from pathlib import Path
import shutil
import sys

from dagster_dbt import DbtCliResource


def get_dbt_executable() -> str:
    """Resolve the dbt executable for both local venv and container environments."""
    dbt_executable = shutil.which("dbt")
    if dbt_executable:
        return dbt_executable

    venv_dbt = Path(sys.executable).parent / "dbt"
    if venv_dbt.exists():
        return str(venv_dbt)

    return "dbt"


def get_dbt_resource(project_dir: Path, target: str = "dev") -> DbtCliResource:
    """
    Get configured dbt resource
    
    Args:
        project_dir: Path to dbt project directory
        target: dbt target (dev, prod, etc.)
    
    Returns:
        Configured DbtCliResource
    """
    return DbtCliResource(
        project_dir=str(project_dir),
        profiles_dir=str(project_dir),
        target=target,
        dbt_executable=get_dbt_executable(),
    )
