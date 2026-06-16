import pytest
from pyspark.sql import SparkSession

TABLE = "lakehouse.bronze.infra_smoke_test"


@pytest.fixture(scope="module")
def spark():
    session = (
        SparkSession.builder.appName("infra-test-spark-to-uc")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config(
            "spark.sql.catalog.spark_catalog",
            "org.apache.spark.sql.delta.catalog.DeltaCatalog",
        )
        .config(
            "spark.sql.catalog.lakehouse",
            "io.unitycatalog.connectors.spark.UCSingleCatalog",
        )
        .config("spark.sql.catalog.lakehouse.uri", "http://unitycatalog:8080")
        .config("spark.sql.catalog.lakehouse.token", "")
        .getOrCreate()
    )
    yield session
    spark_session = session
    spark_session.sql(f"DROP TABLE IF EXISTS {TABLE}")
    spark_session.stop()


def test_write_delta_table(spark):
    df = spark.createDataFrame([(1, "infra_smoke")], ["id", "label"])
    df.write.format("delta").mode("overwrite").saveAsTable(TABLE)


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
