# Accessing Resources Locally

How to reach each service in the stack once `docker compose up` is running.
Ports map to the host as defined in [`docker-compose.yml`](../docker-compose.yml);
credentials come from your `.env` (see [`.env.example`](../.env.example)).

| Service | Host endpoint | Internal endpoint (container network) | Container |
|---|---|---|---|
| Jupyter / Spark | http://localhost:8888 | `spark:8888` | `quant-jupyter-spark` |
| Unity Catalog API | http://localhost:8081 | `unitycatalog:8080` | `quant-unitycatalog` |
| Unity Catalog UI | http://localhost:3000 | `unitycatalog-ui:3000` | `quant-unitycatalog-ui` |
| Airflow UI | http://localhost:8080 | `airflow-webserver:8080` | `quant-airflow-webserver` |
| TimescaleDB | `localhost:5432` | `timescaledb:5432` | `quant-timescaledb` |
| Airflow metadata DB | not exposed | `airflow-db:5432` | `quant-airflow-db` |

> **Host vs. internal endpoints** — Use the *host* endpoint from your machine
> (browser, `psql`, scripts). Use the *internal* endpoint from inside another
> container (e.g. Spark connecting to Unity Catalog or TimescaleDB), since
> containers resolve each other by service name over the `quant-net` network.

## Jupyter / Spark

Open http://localhost:8888 in your browser. Notebooks live under the
`../quant-platform` directory, mounted into the container at
`/home/jovyan/work`.

Open a shell in the container:

```sh
docker compose exec spark bash
```

SparkSessions configured per the project convention reach Unity Catalog at
`http://unitycatalog:8080` and TimescaleDB via JDBC at `timescaledb:5432`
(both internal endpoints, already wired through environment variables).

## Unity Catalog

- **UI:** http://localhost:3000 — browse catalogs, schemas, and tables.
- **API:** http://localhost:8081 — REST endpoint. Quick check:

  ```sh
  curl http://localhost:8081/api/2.1/unity-catalog/catalogs
  ```

The `lakehouse` catalog with `bronze` / `silver` / `gold` schemas is created
automatically on first start by the `unitycatalog-init` container. Tables are
referenced as `lakehouse.bronze.<table>`, etc.

## Airflow

Open http://localhost:8080 and log in with the admin credentials from your
`.env`:

- Username: `AIRFLOW_ADMIN_USER` (default `admin`)
- Password: `AIRFLOW_ADMIN_PASSWORD`

The admin user is created automatically on first start. DAGs are bind-mounted
from `services/airflow/dags/`.

REST API health check:

```sh
curl http://localhost:8080/api/v1/health
```

## TimescaleDB

Connect from the host with `psql` using the values from your `.env`:

```sh
psql -h localhost -p 5432 -U "$POSTGRES_USER" -d "$POSTGRES_DB"
# password: $POSTGRES_PASSWORD
```

Or from inside a container, use host `timescaledb` instead of `localhost`.
Schemas `market_data` and `analytics` are created on first start.

## Useful operational commands

```sh
docker compose ps                 # status of every service
docker compose logs -f <service>  # follow logs for one service
docker compose exec <service> bash
```
