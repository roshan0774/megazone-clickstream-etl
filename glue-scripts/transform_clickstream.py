"""
AWS Glue ETL Job for transforming clickstream data
This is an alternative to the Lambda-based transformation
"""

import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
from pyspark.sql.functions import *
from pyspark.sql.types import *
from datetime import datetime

# Get job parameters
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'RAW_BUCKET', 'TRANSFORMED_BUCKET'])

# Initialize Glue context
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

# Define the schema for clickstream data
clickstream_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("timestamp", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("session_id", StringType(), True),
    StructField("page_url", StringType(), True),
    StructField("product_id", StringType(), True),
    StructField("product_name", StringType(), True),
    StructField("product_category", StringType(), True),
    StructField("product_price", DoubleType(), True),
    StructField("quantity", IntegerType(), True),
    StructField("device_type", StringType(), True),
    StructField("browser", StringType(), True),
    StructField("country", StringType(), True),
    StructField("city", StringType(), True),
    StructField("ip_address", StringType(), True),  # Will be removed
    StructField("email", StringType(), True),  # Will be removed
])

# Read raw data from S3
raw_data_path = f"s3://{args['RAW_BUCKET']}/"
print(f"Reading data from: {raw_data_path}")

# Read JSON files (compressed with gzip)
df = spark.read \
    .option("multiLine", "false") \
    .json(raw_data_path)

# Transform the data
transformed_df = df.select(
    col("event_id"),
    col("event_type"),
    col("timestamp").alias("event_timestamp"),
    col("user_id"),
    col("session_id"),
    col("page_url"),
    col("product_id"),
    col("product_name"),
    col("product_category"),
    col("product_price").cast(DoubleType()),
    col("quantity").cast(IntegerType()),
    col("device_type"),
    col("browser"),
    col("country"),
    col("city")
)

# Add computed fields
transformed_df = transformed_df \
    .withColumn("year", year(col("event_timestamp"))) \
    .withColumn("month", month(col("event_timestamp"))) \
    .withColumn("day", dayofmonth(col("event_timestamp"))) \
    .withColumn("hour", hour(col("event_timestamp"))) \
    .withColumn("day_of_week", date_format(col("event_timestamp"), "EEEE")) \
    .withColumn("revenue",
                when(col("event_type") == "purchase",
                     col("product_price") * col("quantity"))
                .otherwise(0.0))

# Remove duplicate records
transformed_df = transformed_df.dropDuplicates(["event_id"])

# Write to S3 as Parquet with partitioning
output_path = f"s3://{args['TRANSFORMED_BUCKET']}/"
print(f"Writing transformed data to: {output_path}")

transformed_df.write \
    .mode("append") \
    .partitionBy("year", "month", "day") \
    .parquet(output_path)

print(f"Successfully transformed {transformed_df.count()} records")

job.commit()

