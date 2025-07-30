# Quant Trading: Infrastructure

## Overview

This repository contains the infrastructure setup for a quant trading environment. It leverages Docker to orchestrate a local Spark cluster with Delta Lake support, Project Nessie for data versioning, and MinIO as an S3-compatible object store. The setup is designed for local development and testing of data pipelines and analytics workflows.

## Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) (27.4.0) and 
  [Docker Compose](https://docs.docker.com/compose/install/) (2.31.0) installed 
  on your machine.
- Basic familiarity with command-line tools and docker.

## Set up & Installation

1. **Clone the repository:**
   ```sh
   git clone <repo-url>
   cd qt_infra
   ```
2. Set environment variables: Create a .env file in the project root with the following content:
   ```env
   AWS_ACCESS_KEY_ID=your-access-key
   AWS_SECRET_ACCESS_KEY=your-secret-key
   MINIO_ROOT_USER=minioadmin
   MINIO_ROOT_PASSWORD=minioadmin
   ```
3. In parent directory, clone [qt_data git repo](https://github.com/JaviGamero/qt_data.git)
   with same name
4. In root directory, create a folder `./minio/data/`.
5. Start the infrastructure:
   ```sh
   docker compose up --build
   ```
   or restart it if you have already built it and not downed it:
   ```sh
   docker compose start 
   ```
   This will start the following services:

    - Spark http://localhost:8888
    - Project Nessie: http://localhost:19120
    - MinIO Console: http://localhost:9001
6. Access your workspace:
   Jupyter notebooks and data are available in the ../qt_data directory (mounted as /home/jovyan/work in the Spark container).
7. Stopping the services (and delete them):
   ```sh 
   docker compose down
   ```
   or just stop them:
   ```sh 
   docker compose stop
   ```

## Contribute
TODO