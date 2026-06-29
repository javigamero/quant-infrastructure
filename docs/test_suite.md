# Infrastructure Test Suite

Tests run after `docker compose up` to verify the stack is wired correctly. Three layers, each catching a different class of failure.

## Layer 1 — Smoke tests (`tests/smoke_tests.sh`)

Confirms every service is reachable from the host. Fails fast if a container didn't start or a port isn't exposed.

| Check | What it validates |
|---|---|
| TimescaleDB | `pg_isready` — Postgres is accepting connections |
| Unity Catalog | REST API responds and the `lakehouse` catalog exists |
| Spark / Jupyter | Notebook server API returns HTTP 200 |
| Airflow | `/api/v1/health` reports `"status": "healthy"` |

## Layer 2 — PySpark integration tests (`tests/pyspark/`)

Executed inside the Spark container via `docker exec`. Validates that Spark can actually talk to the other services over the internal Docker network — not just that they're reachable from the host.

| Test file | What it validates |
|---|---|
| `test_spark_to_unity_catalog.py` | Spark writes a Delta table to Unity Catalog (`lakehouse.bronze`), reads it back, and confirms the table appears in the catalog listing |
| `test_spark_to_timescaledb.py` | Spark writes a DataFrame to TimescaleDB via JDBC, reads it back through Spark, and cross-checks with a raw `psycopg2` query |

Each test file cleans up its own test table in teardown so reruns are safe.

## Layer 3 — Airflow → Spark DAG (`services/airflow/dags/infra_test_spark_submit.py`)

Triggers `infra_test_spark_submit` via the Airflow REST API and polls until it reaches a terminal state. The DAG runs the Unity Catalog PySpark test suite inside the Spark container using `docker exec`, proving that Airflow can orchestrate PySpark jobs across containers — the primary cross-service dependency in production pipelines.

## Running locally

```bash
bash tests/run_integration_tests.sh          # full run: up → L1 → L2 → L3 → down
bash tests/run_integration_tests.sh --no-up  # stack already running
bash tests/smoke_tests.sh                    # Layer 1 only
```

## CI/CD

`.github/workflows/infrastructure-tests.yml` runs all three layers on every push and PR to `main` and `develop`. Compose logs are uploaded as an artifact on failure.
