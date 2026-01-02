# Architecture Overview
- Athena: Massively parallel query execution
- S3: Unlimited storage
- Lambda: Up to 1000 concurrent executions
- Kinesis Firehose: Auto-scales to GB/sec

## Scalability

- Athena query metrics
- Glue job metrics
- Lambda execution metrics
- Firehose delivery metrics
- CloudWatch Logs for all services

## Monitoring

   - No idle resource costs
   - Pay only for usage
4. **Serverless Architecture**

   - Reduces Athena scan costs
   - Date-based partitions
3. **Partitioning**

   - Snappy for Parquet (Lambda)
   - GZIP for JSON (Firehose)
2. **Data Compression**

   - Query results: 7-day retention
   - Raw data: 30-day retention
1. **S3 Lifecycle Policies**

## Cost Optimization

- CloudWatch logging enabled
- VPC endpoints (optional, not included)
- IAM roles with least privilege
- S3 encryption at rest (SSE-S3)

## Security

- Cost-effective analytics
- Serverless architecture
- Standard SQL interface
- Interactive query service
### Amazon Athena

- **Job**: Alternative ETL processing (PySpark)
- **Data Catalog**: Central metadata repository
- **Crawler**: Automatically discovers schema
### AWS Glue

- Automatic scaling
- AWS Data Wrangler for Parquet conversion
- Python 3.11 runtime
- Event-driven execution
### Lambda Function

4. **Glue Scripts Bucket**: Stores ETL scripts
3. **Athena Results Bucket**: Stores query results
2. **Transformed Data Bucket**: Stores processed Parquet files
1. **Raw Data Bucket**: Stores unprocessed data
### S3 Buckets

- Direct integration with S3
- Built-in data transformation capabilities
- Auto-scaling to handle throughput
- Fully managed streaming data delivery
### Kinesis Data Firehose

## Key Components

   - Integrates with BI tools
   - Serverless, pay-per-query
   - SQL interface for analysis
6. **Analytics**: Athena queries the cataloged data

   - Updates partition information
   - Creates/updates table metadata
   - Discovers schema automatically
5. **Cataloging**: Glue Crawler scans transformed data

   - Columnar storage for efficient querying
   - Data format: Parquet (Snappy compression)
   - Path format: `s3://bucket/year=YYYY/month=MM/day=DD/`
4. **Storage (Processed)**: Transformed data written to S3

   - Converts to Parquet format
   - Adds computed fields (revenue, timestamps)
   - Removes sensitive fields (IP, email)
   - Parses JSON records
   - Decompresses GZIP files
3. **Transformation**: Lambda function triggered by S3 event

   - Data format: JSON (compressed with GZIP)
   - Path format: `s3://bucket/year=YYYY/month=MM/day=DD/`
2. **Storage (Raw)**: Data lands in S3 raw bucket

   - Writes to S3 with date partitioning
   - Compresses data using GZIP
   - Firehose batches data (60 seconds or 5MB)
1. **Ingestion**: Clickstream events are sent to Kinesis Data Firehose

## Data Flow

```
└─────────────────┘
│   (Analytics)   │
│     Athena      │ ← Query Layer
┌─────────────────┐
         v
         │
└────────┬────────┘
│    Catalog      │ ← Metadata Layer
│  Glue Data      │
┌─────────────────┐
         v
         │
└────────┬────────┘
│  Glue Crawler   │ ← Cataloging Layer
┌─────────────────┐
         v
         │
└────────┬────────┘
│   by Date       │
│  Partitioned    │
│  Data (Parquet) │ ← Storage Layer (Processed)
│ S3 Transformed  │
┌─────────────────┐
         v
         │
└────────┬────────┘
│  or Glue Job    │ ← Transformation Layer
│ Lambda Function │
┌─────────────────┐
         v
         │
└────────┬────────┘
│   by Date       │
│  Partitioned    │
│   (JSON/GZIP)   │ ← Storage Layer (Raw)
│  S3 Raw Data    │
┌─────────────────┐
         v
         │
└────────┬────────┘
│   Firehose      │ ← Ingestion Layer
│ Kinesis Data    │
┌─────────────────┐
         v
         │
└────────┬────────┘
│ (Clickstream)   │
│  Data Source    │
┌─────────────────┐
```

## System Architecture


