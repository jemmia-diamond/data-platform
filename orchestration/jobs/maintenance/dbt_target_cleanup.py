import shutil
import time
from pathlib import Path

from dagster import Config, OpExecutionContext, job, op

# .../orchestration/jobs/maintenance/dbt_target_cleanup.py -> repo_root/transformation
TRANSFORMATION_DIR = Path(__file__).parent.parent.parent.parent / "transformation"
DBT_TARGET_DIR = TRANSFORMATION_DIR / "target"

# dagster-dbt writes one directory per `dbt.cli(...)` invocation, named
# "<op_name>-<run_id>-<uuid>" (see dagster_dbt.core.resource.DbtCliResource._get_unique_target_path),
# to isolate concurrent runs' manifest.json/run_results.json. Nothing in dagster-dbt ever deletes
# them, so on a long-lived container they accumulate unbounded (thousands of dirs, several GiB/day).
DBT_TARGET_INVOCATION_PREFIX = "transformation_dbt_assets-"


class DbtTargetCleanupConfig(Config):
    retention_hours: float = 24.0


@op
def cleanup_dbt_target_invocations(context: OpExecutionContext, config: DbtTargetCleanupConfig) -> None:
    """Delete stale per-invocation dbt target directories older than the retention window."""
    if not DBT_TARGET_DIR.exists():
        context.log.info(f"{DBT_TARGET_DIR} does not exist, nothing to clean up.")
        return

    cutoff = time.time() - (config.retention_hours * 3600)
    removed_count = 0
    removed_bytes = 0
    kept_count = 0

    for entry in DBT_TARGET_DIR.iterdir():
        if not entry.is_dir() or not entry.name.startswith(DBT_TARGET_INVOCATION_PREFIX):
            continue

        if entry.stat().st_mtime >= cutoff:
            kept_count += 1
            continue

        removed_bytes += sum(f.stat().st_size for f in entry.rglob("*") if f.is_file())
        shutil.rmtree(entry, ignore_errors=True)
        removed_count += 1

    context.log.info(
        f"dbt target cleanup: removed {removed_count} stale invocation dirs "
        f"({removed_bytes / (1024 ** 3):.2f} GiB) older than {config.retention_hours}h, "
        f"kept {kept_count} recent ones, under {DBT_TARGET_DIR}."
    )


@job(
    description=(
        "Delete stale per-invocation dbt target directories (transformation_dbt_assets-*) so the "
        "dagster_code container's writable layer doesn't grow unbounded."
    )
)
def dbt_target_cleanup_job() -> None:
    cleanup_dbt_target_invocations()


__all__ = ["DbtTargetCleanupConfig", "cleanup_dbt_target_invocations", "dbt_target_cleanup_job"]
