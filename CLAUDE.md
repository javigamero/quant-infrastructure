# Claude instructions 

## Introduction to the project
This project creates the infrastructure for the quant-trading project.  
The main components are:
* Kubernetes (future)
* Docker (current)

All technologies used must be open source.

## Kubernetes
Not yet implemented. Currently designing and building Docker images.

## Stack (docker-compose)

| Service | Image | Port | Purpose |
|---|---|---|---|
| `spark` | custom (pyspark-notebook:spark-3.4.0) | 8888 | Jupyter + PySpark + ML libs |
| `unitycatalog` | unitycatalog/unitycatalog:main | 8081 | Delta Lake catalog (bronze/silver/gold) |
| `timescaledb` | timescale/timescaledb:latest-pg14 | 5432 | Time-series storage |
| `airflow-db` | postgres:14-alpine | internal | Airflow metadata DB |
| `airflow-webserver` | custom (apache/airflow:2.9.1) | 8080 | Airflow UI |
| `airflow-scheduler` | same as webserver | internal | DAG scheduling |

## Docker services

### Programming - Spark & Python
`services/spark/Dockerfile` — extends `jupyter/pyspark-notebook:spark-3.4.0`.

Python libraries installed via `services/spark/requirements.txt`:
* `delta-spark==2.4.0`
* `scikit-learn==1.4.2`
* `torch==2.2.2` (CPU-only, installed via PyTorch index URL)
* `psycopg2-binary==2.9.9`

JVM packages injected at Spark submit time via `PYSPARK_SUBMIT_ARGS`:
* `io.delta:delta-core_2.12:2.4.0`
* `io.unitycatalog:unitycatalog-spark_2.12:0.2.0`
* `org.postgresql:postgresql:42.7.3`

SparkSession pattern to connect to Unity Catalog:
```python
spark = (
    SparkSession.builder
    .appName("...")
    .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
    .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    .config("spark.sql.catalog.lakehouse", "io.unitycatalog.connectors.spark.UCSingleCatalog")
    .config("spark.sql.catalog.lakehouse.uri", "http://unitycatalog:8080")
    .config("spark.sql.catalog.lakehouse.token", "")
    .getOrCreate()
)
```

Tables are referenced as `lakehouse.bronze.<table>`, `lakehouse.silver.<table>`, `lakehouse.gold.<table>`.

### Storage - Unity Catalog & TimescaleDB
* **Unity Catalog** (`services/unitycatalog/`) — open-source Delta Lake catalog.
  Manages `lakehouse` catalog with bronze/silver/gold schemas. Data persisted to `unitycatalog_data` named volume.
  Accessible at `http://localhost:8081` (UI) and `http://unitycatalog:8080` (internal API).
  The `unitycatalog-init` one-shot container runs `services/unitycatalog/init.sh` on first start to create the catalog and schemas automatically.
* **TimescaleDB** (`services/timescaledb/`) — time-series storage for final app consumption.
  Schemas `market_data` and `analytics` are created by `services/timescaledb/init/01-init.sql`.
  Connect via `psql -h localhost -U $POSTGRES_USER -d $POSTGRES_DB`.

### Orchestration - Apache Airflow
`services/airflow/Dockerfile` — extends `apache/airflow:2.9.1`.  
DAGs are bind-mounted from `services/airflow/dags/` into both webserver and scheduler containers.  
Metadata DB is a dedicated `airflow-db` postgres service (separate from TimescaleDB).

After first start, create the admin user:
```bash
docker compose exec airflow-webserver \
  airflow users create \
  --username admin --firstname Admin --lastname User \
  --role Admin --email admin@example.com \
  --password changeme
```

## Required `.env` keys (see `.env.example`)
* `POSTGRES_USER / POSTGRES_PASSWORD / POSTGRES_DB / POSTGRES_HOST / POSTGRES_PORT`
  — `POSTGRES_HOST` must be `timescaledb` (matches the docker-compose service name)
* `AIRFLOW_DB_USER / AIRFLOW_DB_PASSWORD / AIRFLOW_DB_NAME`
* `AIRFLOW_FERNET_KEY / AIRFLOW_SECRET_KEY`
* `ALPHA_VANTAGE_API_KEY` — Alpha Vantage stock data API
* `ALPACA_API_KEY` — Alpaca markets API
