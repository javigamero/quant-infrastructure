from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id="infra_test_spark_submit",
    description="Infra test: Airflow executes a PySpark pytest suite inside the Spark container.",
    start_date=datetime(2024, 1, 1),
    schedule=None,
    catchup=False,
    tags=["infra", "test"],
) as dag:
    run_pyspark_tests = BashOperator(
        task_id="run_pyspark_tests_in_spark_container",
        bash_command=(
            "docker exec quant-jupyter-spark "
            "python -m pytest /home/jovyan/infra-tests/test_spark_to_unity_catalog.py -v --tb=short"
        ),
    )
