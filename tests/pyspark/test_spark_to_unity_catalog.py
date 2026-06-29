import shutil

import pytest
from pyspark.sql import SparkSession

TABLE = "lakehouse.bronze.infra_smoke_test"
# The OSS unitycatalog-spark connector supports external Delta tables only —
# managed tables (saveAsTable without a location) are not supported, so the
# table is created with an explicit storage location.
LOCATION = "file:///tmp/infra_smoke_test"


@pytest.fixture(scope="module")
def spark():
    session = (
        SparkSession.builder.appName("infra-test-spark-to-uc")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config(
            "spark.sql.catalog.spark_catalog",
            "io.unitycatalog.spark.UCSingleCatalog",
        )
        .config("spark.sql.catalog.spark_catalog.uri", "http://unitycatalog:8080")
        .config("spark.sql.catalog.spark_catalog.token", "")
        .config(
            "spark.sql.catalog.lakehouse",
            "io.unitycatalog.spark.UCSingleCatalog",
        )
        .config("spark.sql.catalog.lakehouse.uri", "http://unitycatalog:8080")
        .config("spark.sql.catalog.lakehouse.token", "")
        .getOrCreate()
    )
    # Clean any residue from an interrupted run — external table files survive a
    # DROP, so a stale location would corrupt the row count on rerun.
    _cleanup(session)
    yield session
    _cleanup(session)
    session.stop()


def _cleanup(session):
    session.sql(f"DROP TABLE IF EXISTS {TABLE}")
    shutil.rmtree(LOCATION.removeprefix("file://"), ignore_errors=True)


def test_write_delta_table(spark):
    df = spark.createDataFrame([(1, "infra_smoke")], ["id", "label"])
    (
        df.write.format("delta")
        .mode("overwrite")
        .option("path", LOCATION)
        .saveAsTable(TABLE)
    )


def test_read_back_written_row(spark):
    result = spark.table(TABLE)
    assert result.count() == 1
    assert result.first()["label"] == "infra_smoke"


def test_lakehouse_catalog_lists_table(spark):
    tables = [
        row.tableName
        for row in spark.sql("SHOW TABLES IN lakehouse.bronze").collect()
    ]
    assert "infra_smoke_test" in tables
