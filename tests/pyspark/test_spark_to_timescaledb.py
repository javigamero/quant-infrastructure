import os

import psycopg2
import pytest
from pyspark.sql import SparkSession

TEST_TABLE = "market_data.infra_smoke_test"
_JDBC_TABLE = TEST_TABLE  # psycopg2 uses the same schema.table notation


def _jdbc_url():
    host = os.environ["POSTGRES_HOST"]
    port = os.environ.get("POSTGRES_PORT", "5432")
    db = os.environ["POSTGRES_DB"]
    return f"jdbc:postgresql://{host}:{port}/{db}"


def _jdbc_props():
    return {
        "user": os.environ["POSTGRES_USER"],
        "password": os.environ["POSTGRES_PASSWORD"],
        "driver": "org.postgresql.Driver",
    }


def _pg_conn():
    return psycopg2.connect(
        host=os.environ["POSTGRES_HOST"],
        port=int(os.environ.get("POSTGRES_PORT", 5432)),
        dbname=os.environ["POSTGRES_DB"],
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
    )


@pytest.fixture(scope="module")
def spark():
    session = (
        SparkSession.builder.appName("infra-test-spark-to-timescaledb")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config(
            "spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog",
        )
        .getOrCreate()
    )
    yield session
    with _pg_conn() as conn, conn.cursor() as cur:
        cur.execute(f"DROP TABLE IF EXISTS {TEST_TABLE}")
    session.stop()


def test_write_dataframe_via_jdbc(spark):
    df = spark.createDataFrame([(1, "infra_smoke")], ["id", "label"])
    df.write.jdbc(
        url=_jdbc_url(),
        table=_JDBC_TABLE,
        mode="overwrite",
        properties=_jdbc_props(),
    )


def test_read_back_via_jdbc(spark):
    result = spark.read.jdbc(
        url=_jdbc_url(),
        table=_JDBC_TABLE,
        properties=_jdbc_props(),
    )
    assert result.count() == 1
    assert result.first()["label"] == "infra_smoke"


def test_table_visible_in_postgres():
    with _pg_conn() as conn, conn.cursor() as cur:
        cur.execute(f"SELECT COUNT(*) FROM {TEST_TABLE}")
        (count,) = cur.fetchone()
    assert count == 1
