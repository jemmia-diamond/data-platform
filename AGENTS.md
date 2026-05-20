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
- Run dbt CLI: `cd transformation && export $(cat ../.env | xargs) && dbt build --profiles-dir .`

### dlt Ingestion

- Each connector is `ingestion/<connector>/` with `resources/` + `source.py`
- Always set `primary_key` and `write_disposition`
- API tokens from env vars: `SOURCES__<CONNECTOR>__*`
- Pipeline dataset naming: `raw_<connector_name>`

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

### Asset Key Conventions

- Ingestion (dlt): `["ingestion", <source_name>, <resource_name>]`
- Frappe special: `["ingestion", "frappe", "erpnext", <resource_name>]`
- Transformation (dbt): `["transformation", <schema>, ...folders, <model_name>]`

### dlt Resource Pattern

Every `build_*_resource()` returns `DltResource` with:

- `primary_key` — deduplication
- `write_disposition` — "merge" (incremental) or "replace" (full load)
- `_db_updated_at` — tracking column
- `max_table_nesting = 0` — flatten nested JSON

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

---

## Environment Variables

All secrets from `.env` (never committed):

- `DAGSTER_POSTGRES_*` — Dagster metadata DB
- `DBT_POSTGRES_*` — dbt target connection
- `DESTINATION__POSTGRES__CREDENTIALS__*` — dlt destination
- `SOURCES__HARAVAN__*` — Haravan connector
- `SOURCES__FRAPPE__*` — ERPNext connector
- `SOURCES__NOCODB__*` — NocoDB connector
- `DAGSTER_AUTH_*` — AuthKit config

---

## Rules

- Never hardcode secrets — always use environment variables
- Do not commit `.env` files
- After editing dbt models, run `dbt build` to validate
- After editing Dagster assets, run `dagster dev` to verify no import errors
- ERPNext models must always filter `deleted_documents`
- When adding a new dbt model, check `_sources.yml` first to understand available columns
- When adding a new ingestion connector, follow existing connector patterns (haravan/frappe/nocodb)
- If the project structure changes (new directories, renamed folders, etc.), update this file accordingly

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
