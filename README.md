# Quant Trading: Infrastructure

## Overview

This repository contains the infrastructure for the quant trading platform.
It uses Docker Compose to orchestrate a local stack with Spark/Jupyter for
data processing, Unity Catalog (Delta Lake) as the data catalog, TimescaleDB
for time-series storage, and Apache Airflow for pipeline orchestration.

The setup targets local development, with cloud scalability in mind.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) (27.4.0 *recommended*)
  and [Docker Compose](https://docs.docker.com/compose/install/)
  (2.31.0 *recommended*) installed on your machine.
- Basic familiarity with command-line tools and Docker.

## Set up & Installation

1. Clone this repository:
   ```sh
   git clone <repo-url>
   cd quant-infrastructure
   ```

2. Clone the [quant-platform](https://github.com/JaviGamero/quant-platform) monorepo
   as a sibling directory:
   ```sh
   git clone <quant-platform-repo-url> ../quant-platform
   ```

3. Create a `.env` file from the example and fill in the values specified.

4. Start the infrastructure (first time — builds images):
   ```sh
   docker compose up --build -d 
   ```
   On subsequent starts (images already built):
   ```sh
   docker compose start
   ```

5. Services available after startup:

   | Service | URL |
   |---|---|
   | Jupyter / Spark | http://localhost:8888 |
   | Unity Catalog API | http://localhost:8081 |
   | Unity Catalog UI | http://localhost:3000 |
   | Airflow | http://localhost:8080 |
   | TimescaleDB | `localhost:5432` |

6. Access your workspace:
   Jupyter notebooks are available from the `../quant-platform` directory,
   mounted as `/home/jovyan/work` inside the Spark container.

7. Stop the services:
   ```sh
   # Stop but preserve data (volumes kept)
   docker compose stop

   # Stop and remove containers (volumes still kept)
   docker compose down
   ```

## Contribute
TODO
