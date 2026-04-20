# Data Platform - Dagster + dbt + dlt

Modern data orchestration with Dagster, dbt transformations, dlt ingestion, and `dagster-authkit` for self-hosted Dagster UI authentication.

---

## 📦 Project Structure

```text
data-platform/
├── ingestion/                    # dlt sources and pipeline builders
├── orchestration/                # Dagster code (assets, schedules, resources)
├── transformation/               # dbt project (models, tests)
├── deploy/                       # Dagster deployment configs and AuthKit webserver image
├── Dockerfile                    # Dagster code server image
├── docker-compose.yml            # Full stack (postgres, dagster services)
├── .env                          # Environment variables (not in git)
└── pyproject.toml                # Python dependencies
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

### Required AuthKit Environment Variables

The Docker stack uses `dagster-authkit` to wrap `dagster-webserver`. These values must be set in `.env` for authenticated access:

```env
DAGSTER_AUTH_SECRET_KEY=
DAGSTER_AUTH_ADMIN_USERNAME=admin
DAGSTER_AUTH_ADMIN_PASSWORD=
```

Generate a strong session secret with:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

Notes:
- `DAGSTER_AUTH_SECRET_KEY` signs session cookies and must stay stable across restarts.
- `DAGSTER_AUTH_ADMIN_USERNAME` / `DAGSTER_AUTH_ADMIN_PASSWORD` are the initial Dagster UI credentials.
- These are application credentials for `dagster-authkit`, not PostgreSQL user credentials.

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
- **Auth**: Does **not** use the Docker Compose `dagster-authkit` flow.

### Option 2: Docker Compose (Production-like)
Best for testing the full self-hosted stack with PostgreSQL-backed Dagster metadata and AuthKit login.

```bash
docker-compose up --build -d
# UI: http://localhost:3080
```
- **Features**: Full stack isolation, PostgreSQL persistent storage, authenticated Dagster UI.
- **Database**: Host: `localhost`, Port: `5432`.
- **Auth bootstrap**: On startup, `dagster_webserver` initializes AuthKit tables, creates the admin user if missing, and syncs the admin password from `.env`.

### First Login

After `docker-compose up --build -d` completes, sign in with:

- **Username**: `DAGSTER_AUTH_ADMIN_USERNAME`
- **Password**: `DAGSTER_AUTH_ADMIN_PASSWORD`

Example:

```env
DAGSTER_AUTH_ADMIN_USERNAME=admin
DAGSTER_AUTH_ADMIN_PASSWORD=my-strong-password
```

Then log in at [http://localhost:3080](http://localhost:3080) with:

- username: `admin`
- password: `my-strong-password`

---

## 🛠️ Key Workflows

### 📥 Adding New Ingestion (dlt)
1. **Define Resources**: Create `ingestion/<connector>/resources/` to define endpoints.
   - Use `primary_key` for deduplication.
   - Use `write_disposition="merge"` for upsert logic.
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
   dbt build --profiles-dir .
   ```

### 🔐 AuthKit Bootstrap Flow
The Docker Compose webserver runs this flow automatically on startup:
1. Wait for PostgreSQL to become healthy.
2. Initialize AuthKit tables.
3. Create the configured admin user if it does not exist.
4. If the user already exists, update its password from `.env`.
5. Start Dagster behind `dagster-authkit`.

This means `docker-compose up --build -d` is enough to provision login for a fresh environment.

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
# Build and start the full stack
docker-compose up --build -d

# View webserver logs
docker-compose logs -f dagster_webserver

# View daemon logs
docker-compose logs -f dagster_daemon

# Clean up volumes
docker-compose down -v
```

### Reset Admin Password
Update `.env`:

```env
DAGSTER_AUTH_ADMIN_PASSWORD=new-password
```

Then restart the stack:

```bash
docker-compose up --build -d
```

The bootstrap flow will update the existing admin password on startup.

---

## 🚢 Production Deployment

1. **Build image**: `docker build -t your-registry/dagster-code:latest .`
2. **Build AuthKit webserver image**: `docker build -t your-registry/dagster-webserver-authkit:latest -f deploy/Dockerfile.authkit-webserver deploy`
3. **Push images**: Push both images to your registry.
4. **Deploy**: Update image references in `docker-compose.yml` or your deployment manifests and run your normal rollout process.

If you run behind HTTPS in production, set:

```env
DAGSTER_AUTH_COOKIE_SECURE=true
```

---

## 🐛 Troubleshooting

- **"Env var not provided"**: Ensure `.env` exists. For dbt CLI, run `export $(cat ../.env | xargs)`.
- **"manifest.json not found"**: Auto-generated on startup. For Docker, it is built into the image.
- **Connection errors**: Check `DBT_POSTGRES_HOST` and credentials in `.env`.
- **Cannot log in to Dagster UI**: Verify `DAGSTER_AUTH_SECRET_KEY`, `DAGSTER_AUTH_ADMIN_USERNAME`, and `DAGSTER_AUTH_ADMIN_PASSWORD` are set in `.env`.
- **Admin user exists but password is wrong**: Update `DAGSTER_AUTH_ADMIN_PASSWORD` in `.env` and rerun `docker-compose up --build -d`.
- **Session lost after restart**: Make sure `DAGSTER_AUTH_SECRET_KEY` did not change.
- **Browser auth issues**: Use [http://localhost:3080](http://localhost:3080) rather than `0.0.0.0:3080`.

---

**Happy Data Engineering! 🚀**
