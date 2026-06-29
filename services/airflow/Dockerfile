FROM apache/airflow:2.9.1

USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl docker.io \
    && rm -rf /var/lib/apt/lists/*

USER airflow

RUN pip install --no-cache-dir \
    apache-airflow-providers-postgres==5.10.2 \
    apache-airflow-providers-common-sql==1.12.0
