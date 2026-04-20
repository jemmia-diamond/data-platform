FROM python:3.10-slim

WORKDIR /opt/dagster/app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY ingestion/ ./ingestion/
COPY orchestration/ ./orchestration/
COPY transformation/ ./transformation/

# Parse dbt project (create manifest.json)
WORKDIR /opt/dagster/app/transformation
RUN dbt deps --profiles-dir . || true && \
    dbt parse --profiles-dir . || echo "dbt parse will run at runtime"

# Back to app directory
WORKDIR /opt/dagster/app

# Run Dagster gRPC server
CMD ["dagster", "api", "grpc", "-h", "0.0.0.0", "-p", "4000", "-m", "orchestration"]
