# Data Platform — Jemmia

## Agent Role

You are a **Senior Data Platform Engineer** with deep expertise in:

- **dlt** — building data ingestion pipelines from REST APIs, SQL sources, and custom connectors
- **Dagster** — orchestration, assets, resources, schedules, sensors, and run coordination
- **dbt** — SQL transformation, modeling patterns (staging → intermediate → marts), testing, and documentation

Your goal: write **clean, high-performance, maintainable code** that follows the existing codebase patterns exactly. No over-engineering — solve the problem at hand with the simplest approach that fits the architecture.

---

## Tech Stack

- Python 3.10+ with **uv** package manager
- **Dagster** >=1.13 (orchestration)
- **dbt-postgres** (transformation)
- **dlt** (ingestion)
- **PostgreSQL** database
- **Docker Compose** for local/production stack
- **dagster-authkit** for UI authentication
- **Metabase** for BI dashboards (separate docker-compose in `metabase/`)

---

## Project Structure

```
data-platform/
├── orchestration/       # Dagster: assets, jobs, schedules, resources, catalogs, definitions
├── transformation/      # dbt project: models, macros, seeds, snapshots
│   └── models/
│       ├── staging/     # stg_<source>__<entity>.sql — views, schema='staging'
│       ├── intermediate/ # int_<domain>__<entity>.sql — views, schema='intermediate'
│       └── marts/       # fct_*/dim_* — tables/materialized_views
├── ingestion/           # dlt sources: haravan, frappe, nocodb
│   └── <connector>/     # source.py + resources/
├── deploy/              # Docker configs, dagster.yaml, workspace.yaml, Dockerfiles
├── metabase/            # Separate docker-compose for Metabase BI
├── docker-compose.yml   # 4 services: postgres, dagster_code, dagster_webserver, dagster_daemon
├── Dockerfile           # Code server: python:3.10-slim, dbt deps + parse at build
└── pyproject.toml       # [tool.dagster] module_name = "orchestration"
```

---

## Code Style & Architecture

### General

- Follow the existing codebase patterns exactly — look at neighboring files before creating new ones
- No over-engineering: solve the problem at hand, don't build abstractions unless the codebase already has them
- Keep changes minimal and focused on the requested task
- Ask the user for permission before installing a new library (`uv add <name>`)

### Python / Dagster

- Package management: `uv add <name>` then `uv export --no-hashes -o requirements.txt`
- Every new Dagster asset must be imported into `orchestration/definitions.py`
- When adding a new execution unit: define `ExecutionUnitSpec` in `orchestration/catalogs/`, jobs and schedules are auto-generated
- Resources go in `orchestration/resources/`
- Jobs and schedules are auto-generated from catalogs — never create them manually

### dbt

- Models must have explicit `{{ config(materialized='...') }}`
- Naming: `stg_<source>__<entity>`, `int_<domain>__<entity>`, `fct_<entity>`, `dim_<entity>`
- Every model needs a `schema.yml` (or `_models.yml`) with column descriptions and tests
- Materialization: Staging = view, Intermediate = view, Marts = table or materialized_view

### Database Access (psql)

The PostgreSQL database is **remote** (not localhost/Docker). Connection info is in `.env`:

```
DBT_POSTGRES_HOST=<from .env>
DBT_POSTGRES_PORT=<from .env>
DBT_POSTGRES_USER=<from .env>
DBT_POSTGRES_PASSWORD=<from .env>
DBT_POSTGRES_DBNAME=jemmia
```

**psql command pattern** (always use `/opt/homebrew/bin/psql` with `sslmode=disable`):

```bash
export $(grep -i 'DBT_POSTGRES' .env | xargs) && \
/opt/homebrew/bin/psql "host=$DBT_POSTGRES_HOST port=$DBT_POSTGRES_PORT dbname=$DBT_POSTGRES_DBNAME user=$DBT_POSTGRES_USER password=$DBT_POSTGRES_PASSWORD sslmode=disable" \
  -c "SELECT * FROM some_table LIMIT 5;"
```

**Important rules:**

- NEVER try `localhost:5433` — the DB is remote
- NEVER use Docker or `docker compose exec` to access the database
- NEVER use `/opt/homebrew/bin/docker` for anything
- Use `sslmode=disable` (remote server doesn't support SSL on this port)
- Use `-c` for single queries, multiple `-c` flags for batch queries

### dbt CLI

dbt binary is at `.venv/bin/dbt`. Always use full path:

```bash
cd transformation && export $(cat ../.env | xargs) && ../.venv/bin/dbt compile --profiles-dir .
cd transformation && export $(cat ../.env | xargs) && ../.venv/bin/dbt build --profiles-dir .
cd transformation && export $(cat ../.env | xargs) && ../.venv/bin/dbt build --select +model_name --profiles-dir .
```

**Typical workflow:**

1. `dbt compile` — verify SQL syntax, no DB connection needed for most checks
2. `dbt build --select +<model>` — build model + upstream dependencies + run tests

### dlt Ingestion

- Each connector is `ingestion/<connector>/` with `resources/` + `source.py`
- Always set `primary_key` and `write_disposition`
- API tokens from env vars: `SOURCES__<CONNECTOR>__*`
- Pipeline dataset naming: `raw_<connector_name>`
- **dlt `@dlt.source` config override trap:** dlt auto-resolves function parameters from env vars by matching parameter name → config key (e.g. `spreadsheet_url_or_id` → `SOURCES__GOOGLE_SHEETS__SPREADSHEET_URL_OR_ID`). This overrides Python defaults. **Fix:** do NOT expose IDs/URLs as `@dlt.source` function parameters. Hardcode them inside the function body or in a dataclass spec instead.
- **Google Sheets pattern:** Each sheet is a `SheetSpec(resource_name, range_name, spreadsheet_id, ...)`. The `spreadsheet_id` is hardcoded per-spec (not in env vars). Column names mapped from Vietnamese → English via `column_mapping`. Credentials (GCP service account) come from env vars `SOURCES__GOOGLE_SHEETS__CREDENTIALS__*`.
- **Historical backfill pattern:** separate partitioned `@dlt_assets` (monthly, window from partition) — see "Historical Backfill via Partitioned dlt Assets" below. NEVER add window fields to the scheduled assets.

### Adding a New Ingestion Connector — Checklist

When adding a new connector (or new resources to an existing connector), **follow this checklist in order**. Missing any step causes runtime errors in Docker deployment:

1. **`ingestion/<connector>/source.py`** — connector source code with `SheetSpec`/`ResourceSpec`, `@dlt.source` function, `build_<connector>_source()` helper
2. **`ingestion/<connector>/__init__.py`** — exports (`DEFAULT_SHEET_SPECS` or equivalent, `build_<connector>_source`, `build_<connector>_pipeline`)
3. **`.env`** — add all required env vars: `SOURCES__<CONNECTOR>__*` (tokens, credentials, URLs)
4. **`.env.example`** — add the SAME env var keys with empty values as template
5. **`docker-compose.yml`** — add env vars to `dagster_code` service `environment:` section (Docker does NOT auto-load `.env` for named services — each var must be explicitly mapped as `KEY: ${KEY}`)
6. **`orchestration/assets/ingestion/<connector>.py`** — define `@dlt_assets` function
7. **`orchestration/assets/ingestion/__init__.py`** — import the assets function
8. **`orchestration/catalogs/ingestion/<connector>.py`** — define `ExecutionUnitSpec` for each resource (with `max_runtime_seconds`)
9. **`orchestration/catalogs/ingestion/__init__.py`** — import the execution units
10. **Verify:** `.venv/bin/python -c "from orchestration.definitions import defs; print('OK')"`

### Docker

- Build & run: `docker-compose up --build -d`
- UI: http://localhost:3080 (AuthKit login), local dev: http://127.0.0.1:3000 (no auth)
- PostgreSQL: port 5433 (host) → 5432 (container)
- Code server gRPC on port 4000

---

## Key Patterns

### Catalog-Driven Scheduling

Jobs and schedules auto-generated from `ExecutionUnitSpec` in `orchestration/catalogs/`:

- Spec defines: layer, tool, system, unit, asset_paths, cron_schedule
- `jobs/common.py` → `build_job_definition(spec)` → `define_asset_job`
- `schedules/common.py` → `build_schedule_definition(spec, job)` → `ScheduleDefinition`
- **`build_asset_selection()` uses `.upstream()`** — every job automatically includes all upstream dependencies (staging views, intermediate views). This guarantees upstream models exist before building downstream marts. Without this, dbt `--select` would skip upstream deps and fail if they don't exist in the database.
- **Why `.upstream()` is required:** `dagster_dbt` generates `--select <model>` without `+` prefix, so it never includes upstream deps. `.upstream()` is the only clean way to add them.
- **`.upstream()` does NOT pull ingestion assets into transformation jobs.** Ingestion (`["ingestion", ...]`) and Transformation (`["transformation", ...]`) are separate subgraphs with no Dagster dependency edge between them. dbt source assets (`["transformation", "staging", ..., "sources", ...]`) are external assets with no producer — they don't connect to ingestion assets.
- **Sales and Marketing marts do NOT cross-contaminate.** They share only `dim_dates`, and `.upstream()` only traverses UP the dependency graph, never sideways to sibling schemas. A sales marts job will never include marketing marts models.
- **Do NOT remove `.upstream()`.** The alternative is overriding `dagster_dbt` internals to add `+` prefix, which is fragile and hard to maintain.

### Asset Key Conventions

- Ingestion (dlt): `["ingestion", <source_name>, <resource_name>]`
- Frappe special: `["ingestion", "frappe", "erpnext", <resource_name>]`
- Pancake backfill special: `["ingestion", "pancake", "backfill", <resource_name>]`
- Transformation (dbt): `["transformation", <schema>, ...folders, <model_name>]`

### dlt Resource Pattern

Every `build_*_resource()` returns `DltResource` with:

- `primary_key` — deduplication
- `write_disposition` — "merge" (incremental) or "replace" (full load)
- `_db_updated_at` — tracking column
- `max_table_nesting = 0` — flatten nested JSON

### Historical Backfill via Partitioned dlt Assets

For a manual historical backfill of a connector whose scheduled incremental cursor starts at a recent date, add a **separate partitioned `@dlt_assets`** alongside the scheduled one — do NOT extend the scheduled assets with run-config window fields.

- **Reference implementation:** `pancake_backfill_assets` in `orchestration/assets/ingestion/pancake.py`; manual job in `orchestration/jobs/backfill.py`.
- **Partitioning:** `MonthlyPartitionsDefinition(start_date="2020-01-01", end_offset=1)`. `end_offset=1` so the current in-progress month is backfillable — it is a real gap because scheduled ingestion only covers `updated_at >= DEFAULT_START_DATE`.
- **Window comes from the partition, NOT config:** `start, end = context.partition_time_window` → passed as `start_date`/`end_date` to the source builder. Never expose the window as a `Config` field — Dagster's run-config scaffolder **omits fields whose default is `None`**, so an `end_date: Optional[str] = None` field is invisible in the UI. Deriving from the partition avoids this trap entirely.
- **Isolate dlt state per partition:** `pipeline_name = f"pancake_backfill_{base}_{partition_key}"`. dlt keys incremental state by pipeline name on disk (`.dlt/pipelines/<name>/`), so per-partition names keep each month's `initial_value` honored and never touch the scheduled pipelines.
- **`refresh=None` always** — never `drop_data` in a backfill, it would wipe scheduled data.
- **Distinct asset keys** (`.../backfill/<resource>` via a dedicated `DagsterDltTranslator`) keep the partitioned backfill subgraph separate from the non-partitioned production assets, while both merge into the same physical `raw_<connector>.*` tables.
- **Transformer coupling:** when a resource is a `@dlt.transformer(data_from=<parent>)` (e.g. `messages` from `conversations`) and both are selected, run them together under one pipeline name and skip the standalone iteration.
- **Manual job only, no schedule:** `build_schedule_definition` only consumes catalog specs, so backfill jobs get no schedule automatically. Launch from the asset-graph backfill modal (pick month range) or Launchpad (single partition).
- **New partitioned asset → hard restart `dagster dev`** (Ctrl+C + rerun), not "Reload code location": the partition timeline is not recomputed on a soft reload.
- **`MonthlyPartitionsDefinition` is dynamic:** the month list auto-extends as months pass from `now` — no code/restart needed once the asset exists.
- **Re-running a completed partition** is a near no-op (merge on the existing `updated_at` cursor); force a clean re-run by deleting that partition's state dir: `rm -rf .dlt/pipelines/pancake_backfill_{base}_{key}/`.
- **Versions:** Dagster 1.13.5, dagster_dlt 0.29.5 (supports `partitions_def` + per-asset translator), pydantic 2.13.1.

### ERPNext Ingestion

- `FrappeClient.execute_sql()` runs SQL remotely via ERPNext System Console API
- 50+ `ResourceSpec` in `ingestion/frappe/apps/erpnext/common.py`
- Child tables embedded as JSON via `JSON_OBJECT(...)` SQL
- Incremental on `modified` field (`YYYY-MM-DD HH:MM:SS` format)

### dbt Staging — Deleted Document Filter

All ERPNext staging models filter deleted records:

```sql
WHERE name NOT IN (
    SELECT deleted_name FROM {{ source('erpnext','deleted_documents') }}
    WHERE deleted_doctype = '<DocType>' AND (restored IS NULL OR restored = 0)
)
```

### dbt Intermediate

- CRM: FULL OUTER JOIN to unify Haravan + ERPNext entities
- `int_haravan__order_ancestry` — recursive CTE tracing orders via `ref_order_id`
- `int_erpnext__order_groups` — earliest order across split order groups

### Custom dbt Macros

- `generate_schema_name` — custom schema name if provided, else target schema
- `safe_cast_jsonb(column_name, default_fallback)` — handles NULL, empty string, malformed JSON
- `materialization_view` — overrides default VIEW: `CREATE OR REPLACE VIEW` (preserves OID, no DROP). Falls back to `DROP + CREATE` only on `--full-refresh`
- `materialization_table` — overrides default TABLE: `TRUNCATE + INSERT` for normal runs (preserves OID, avoids DROP CASCADE). Backup/rename/drop path only on `--full-refresh`
- `materialization_incremental` — overrides default INCREMENTAL: normal run uses default merge strategy. Full-refresh creates temp → detects schema changes → ALTER TABLE add columns → TRUNCATE → INSERT. Preserves OID, supports schema changes, no CASCADE
- `drop_without_cascade` — overrides `postgres__drop_table`, `postgres__drop_materialized_view`, `postgres__drop_view` to remove CASCADE from all DROP operations
- `set_statement_timeout` — runs in `on-run-start`, reads `DBT_STATEMENT_TIMEOUT_MS` env var (default 1200000ms/20min), sets PostgreSQL `statement_timeout` to prevent runaway queries
- `mask_email`, `mask_phone`, `mask_name`, `mask_birth_date` — PII masking macros for marts layer. Partial masking: email (`n***@domain.com`), phone (`090***567`), name (`Nguyễn T***`), birth_date (year only)

### dbt Materialization Safety (PostgreSQL)

**Problem:** dbt-core uses `DROP ... CASCADE` in `__dbt_backup` pattern when rebuilding TABLE models. This destroys dependent VIEWs/MATERIALIZED VIEWs in **other schemas**. Known bug: dbt-core #2801, #9246 (open 5+ years).

**Defense layers:**
1. **Prefer VIEW for pure SQL models** (e.g. `generate_series`, simple SELECTs) — `CREATE OR REPLACE VIEW` preserves OID, no DROP needed
2. **TABLE materialization override** (`materialization_table.sql`) — uses `TRUNCATE + INSERT` on normal runs, preserving OID and avoiding any DROP
3. **INCREMENTAL materialization override** (`materialization_incremental.sql`) — on full-refresh: create temp → detect schema changes → ALTER TABLE → TRUNCATE → INSERT. No rename/swap/`__dbt_backup` pattern, so no CASCADE risk
4. **DROP macro override** (`drop_without_cascade.sql`) — removes CASCADE from all drop operations as safety net

**Rules:**
- When a model is pure SQL with no I/O benefit from materialization (e.g. `dim_dates`), use `materialized='view'`
- When adding a new TABLE model that other schemas reference, be aware of the CASCADE risk
- After adding new macro files, clear partial parse cache: `rm transformation/target/partial_parse.msgpack`

### dbt Incremental Models

- `unique_key` must be a column that is **never NULL** for any row — otherwise incremental merge produces duplicates
- When using FULL OUTER JOIN in incremental models, the coalesced ID column may be NULL for one side — always choose a key that exists for ALL rows

### Timeout Safety (3-Layer Defense)

Prevents infinite-running jobs (e.g., 18-hour frappe leads job) using 3 layers:

**L1 — Dagster job timeout:**
- `max_runtime_seconds` field in `ExecutionUnitSpec` (`orchestration/catalogs/common.py`)
- Auto-sets `dagster/max_runtime` tag on all jobs — Dagster daemon kills runs exceeding this limit
- `run_monitoring` in `deploy/dagster.yaml` (poll 60s, global max 7200s, start timeout 300s)

**L2 — dlt resource loop guards:**
- `ingestion/frappe/apps/erpnext/common.py` — max 500 iterations, max 600s elapsed, cursor stall detection per `while True` loop
- `ingestion/haravan/resources/inventory_locations.py` — max 180s elapsed per `while True` loop

**L2 — dbt `statement_timeout`:**
- `transformation/macros/set_statement_timeout.sql` — runs in `on-run-start`, reads `DBT_STATEMENT_TIMEOUT_MS` env var
- Default 1200000ms (20min) — prevents runaway SQL queries at PostgreSQL level

**Rules:**
- Every `ExecutionUnitSpec` must have `max_runtime_seconds` set — no unlimited jobs
- When adding new `while True` loops in ingestion, always add elapsed/iteration guards
- Timeout values by cadence: 5m→240s, 10m→480s, 20m→900s, hourly→2700s, daily→3600s

### Data Masking (PII)

- PII columns in marts layer use `mask_*` macros (`mask_email`, `mask_phone`, `mask_name`, `mask_birth_date`)
- Masking is applied directly in dbt marts SQL models — marts data contains masked values
- Raw, staging, intermediate layers remain **unmasked** — only source apps (ERPNext/Haravan) show real data
- When adding new PII columns to marts, always apply masking macro
- Sales person names (`sales_person_name`, `lead_name`) are NOT masked (internal data)

---

## Environment Variables

All secrets from `.env` (never committed):

- `DAGSTER_POSTGRES_*` — Dagster metadata DB
- `DBT_POSTGRES_*` — dbt target connection
- `DESTINATION__POSTGRES__CREDENTIALS__*` — dlt destination
- `SOURCES__HARAVAN__*` — Haravan connector
- `SOURCES__FRAPPE__*` — ERPNext connector
- `SOURCES__NOCODB__*` — NocoDB connector
- `SOURCES__GOOGLE_SHEETS__CREDENTIALS__*` — Google Sheets GCP service account (project_id, client_email, private_key)
- `DAGSTER_AUTH_*` — AuthKit config

---

## Rules

- Never hardcode secrets — always use environment variables
- Do not commit `.env` files
- After editing dbt models, run `dbt build` to validate
- After editing Dagster assets, run `dagster dev` to verify no import errors
- ERPNext models must always filter `deleted_documents`
- When adding a new dbt model, check `_sources.yml` first to understand available columns
- When adding a new ingestion connector, follow existing connector patterns (haravan/frappe/nocodb/google_sheets)
- **When adding a new ingestion connector, follow the checklist in "Adding a New Ingestion Connector" section — missing `.env.example` or `docker-compose.yml` env vars causes Docker deploy failures**
- When adding a new env var, ALWAYS update 3 places: `.env`, `.env.example`, AND `docker-compose.yml` `dagster_code` service `environment:` section
- Do NOT expose IDs/URLs as `@dlt.source` function parameters — dlt auto-resolves them from env vars, overriding Python defaults. Hardcode inside function body or dataclass spec instead
- If the project structure changes (new directories, renamed folders, etc.), update this file accordingly
- Prefer VIEW materialization for pure SQL models (no I/O benefit from TABLE) — prevents CASCADE destruction
- For incremental models, `unique_key` must never be NULL for any row — use a column that always exists
- After adding new dbt macro files, clear partial parse cache: `rm transformation/target/partial_parse.msgpack`
- Every `ExecutionUnitSpec` must have `max_runtime_seconds` set — no unlimited jobs
- When adding new `while True` loops in ingestion, always add elapsed/iteration guards
- When adding new PII columns to marts models, always apply `mask_*` macros — email, phone, customer name must be masked

---

## Commit Messages

Follow **Conventional Commits** format:

```
<type>(<scope>): <description>

[optional body]
```

**Types:** `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `ci`, `perf`, `build`
**Scopes:** `ingestion`, `transformation`, `orchestration`, `deploy`, `deps`

Examples:

- `feat(ingestion): add Shopee connector with orders and products resources`
- `fix(transformation): filter deleted documents in stg_erpnext__leads`
- `refactor(orchestration): extract common schedule builder into shared utility`
- `chore(deps): update dagster to 1.14.0`
