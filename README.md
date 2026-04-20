# Data Platform - Dagster + dbt + dlt

Modern data orchestration with Dagster, dbt transformations, and dlt ingestion.

---

## 📦 Project Structure

```
data-platform/
├── ingestion/             # dlt sources and pipeline builders
├── orchestration/         # Dagster code (assets, schedules)
├── transformation/        # dbt project (models, tests)
├── deploy/               # Production configs (dagster.yaml, workspace.yaml)
├── Dockerfile            # Dagster code server image
├── docker-compose.yml    # Full stack (postgres, dagster services)
├── .env                  # Environment variables (not in git)
└── pyproject.toml        # Python dependencies
```

---

## 🚀 Getting Started

### Prerequisites
- Python 3.10+
- Docker & Docker Compose
- [uv](https://docs.astral.sh/uv/) (recommended) or pip

### Setup
```bash
# 1. Clone the repository
git clone <repo-url>
cd data-platform

# 2. Setup virtual environment
uv venv && source .venv/bin/activate && uv sync
# OR with pip: python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt

# 3. Configure environment
cp .env.example .env
# Edit .env with your credentials
```

---

## 💻 Development Modes

### Option 1: Local Development (Fastest)
Best for developing new assets, testing dbt models, and quick iterations.

```bash
dagster dev
# UI: http://127.0.0.1:3000
```
- **Features**: Hot-reload, automatic `.env` loading, fast startup (~5s).
- **Storage**: Uses local SQLite for metadata (temporary).

### Option 2: Docker Compose (Production-like)
Best for testing production deployment, networking, and persistent storage.

```bash
docker-compose up --build -d
# UI: http://127.0.0.1:3080
```
- **Features**: Full stack isolation, PostgreSQL persistent storage.
- **Database**: Host: `localhost`, Port: `5432`.

---

## 🛠️ Key Workflows

### 📥 Adding New Ingestion (dlt)
1. **Define Resources**: Create `ingestion/<connector>/resources/` to define endpoints.
   - Use `primary_key` for deduplication.
   - Use `write_disposition="merge"` for Upsert logic.
   - Use `incremental` to fetch only new/updated records.
2. **Setup Source**: In `ingestion/<connector>/source.py`, define the `dlt.source`.
3. **Register Assets**: In `orchestration/assets/ingestion/<connector>.py`, use `@dlt_assets`.
4. **Env Vars**: Add `SOURCES__<CONNECTOR>__API_TOKEN` to `.env`.

### 🔄 Working with dbt
1. **Develop**: Edit models in `transformation/models/`.
2. **Run via UI**: Click "Materialize" on dbt assets in Dagster.
3. **Run via CLI**:
   ```bash
   cd transformation
   export $(cat ../.env | xargs)
   dbt run --profiles-dir .
   ```

---

## 📦 Tooling & Maintenance

### Package Management (uv)
This project uses **uv** for speed and reliability.
```bash
# Add package
uv add package-name

# Export for Docker (required after adding packages)
uv export --no-hashes -o requirements.txt

# Update all
uv sync --upgrade
```

### Docker Operations
```bash
# Build and restart code server
docker-compose up --build -d dagster_code

# View logs
docker-compose logs -f dagster_code

# Clean up volumes
docker-compose down -v
```

---

## 🚢 Production Deployment

1. **Build image**: `docker build -t your-registry/dagster-code:latest .`
2. **Push image**: `docker push your-registry/dagster-code:latest`
3. **Deploy**: Update `image` in `docker-compose.yml` and run `docker-compose pull && docker-compose up -d`.

---

## 🐛 Troubleshooting

- **"Env var not provided"**: Ensure `.env` exists. For dbt CLI, run `export $(cat ../.env | xargs)`.
- **"manifest.json not found"**: Auto-generated on startup. For Docker, it's built into the image.
- **Connection errors**: Check `DBT_POSTGRES_HOST` and credentials in `.env`.

---

**Happy Data Engineering! 🚀**
