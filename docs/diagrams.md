# Visual Architecture Diagrams

## High-Level Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         E-Commerce Platform                               │
│                    (Generates Clickstream Events)                         │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Streaming Events (JSON)
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      INGESTION LAYER                                      │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              Amazon Kinesis Data Firehose                           │  │
│  │  • Batching: 60s or 5MB                                            │  │
│  │  • Compression: GZIP                                               │  │
│  │  • Buffering & Retry Logic                                         │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Batched, Compressed Data
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      STORAGE LAYER (RAW)                                  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              Amazon S3 - Raw Data Bucket                            │  │
│  │  • Format: JSON (GZIP compressed)                                  │  │
│  │  • Partitioning: year=YYYY/month=MM/day=DD/                       │  │
│  │  • Retention: 30 days                                              │  │
│  │  • Encryption: SSE-S3                                              │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ S3 Event Notification
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                    TRANSFORMATION LAYER                                   │
│  ┌──────────────────────────┐      ┌──────────────────────────────────┐  │
│  │   AWS Lambda Function    │      │      AWS Glue Job                │  │
│  │  • Runtime: Python 3.11  │  OR  │  • Engine: PySpark               │  │
│  │  • Trigger: S3 Event     │      │  • Workers: 2x G.1X              │  │
│  │  • Memory: 1024 MB       │      │  • Job Bookmark: Enabled         │  │
│  └──────────────────────────┘      └──────────────────────────────────┘  │
│                                                                            │
│  Transformations:                                                          │
│  • Decompress GZIP files                                                  │
│  • Parse JSON records                                                     │
│  • Remove PII (IP, email)                                                 │
│  • Add computed fields (revenue, hour, day_of_week)                      │
│  • Convert to Parquet format (Snappy compression)                        │
│  • Write with date partitioning                                           │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Transformed Data
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                   STORAGE LAYER (TRANSFORMED)                             │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │           Amazon S3 - Transformed Data Bucket                       │  │
│  │  • Format: Parquet (Snappy compressed)                             │  │
│  │  • Partitioning: year=YYYY/month=MM/day=DD/                       │  │
│  │  • Columnar storage for fast queries                               │  │
│  │  • Encryption: SSE-S3                                              │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Crawl Schedule / On-Demand
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                      CATALOGING LAYER                                     │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                    AWS Glue Crawler                                 │  │
│  │  • Discovers schema automatically                                  │  │
│  │  • Creates/updates table metadata                                  │  │
│  │  • Manages partitions                                              │  │
│  └───────────────────────────┬────────────────────────────────────────┘  │
│                               │                                            │
│                               ▼                                            │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │              AWS Glue Data Catalog                                  │  │
│  │  • Database: clickstream_db                                        │  │
│  │  • Table: clickstream_events                                       │  │
│  │  • Schema: Auto-discovered                                         │  │
│  │  • Partitions: Auto-managed                                        │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Query via Glue Catalog
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                       ANALYTICS LAYER                                     │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                   Amazon Athena                                     │  │
│  │  • Serverless SQL queries                                          │  │
│  │  • Workgroup: clickstream-workgroup                                │  │
│  │  • Presto-based query engine                                       │  │
│  │  • Results stored in S3                                            │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────┬─────────────────────────────────────────┘
                                 │
                                 │ Query Results
                                 │
                                 ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                         BUSINESS USERS                                    │
│  • Data Analysts                                                          │
│  • Business Intelligence Teams                                            │
│  • Data Scientists                                                        │
│  • BI Tools (Tableau, PowerBI, etc.)                                     │
└──────────────────────────────────────────────────────────────────────────┘
```

## Data Flow Sequence

```
1. Event Generation
   ├─ E-commerce platform generates clickstream events
   ├─ Format: JSON
   └─ Rate: Thousands per minute

2. Ingestion (Kinesis Firehose)
   ├─ Receives streaming events via PutRecord API
   ├─ Buffers for 60 seconds OR 5MB (whichever comes first)
   ├─ Compresses with GZIP (saves ~70% space)
   └─ Delivers to S3 with date partitioning

3. Raw Storage (S3)
   ├─ Path: s3://raw-bucket/year=2026/month=01/day=01/file.gz
   ├─ Format: JSON (compressed)
   └─ Triggers Lambda function on object creation

4. Transformation (Lambda)
   ├─ Triggered by S3 event notification
   ├─ Downloads and decompresses file
   ├─ Parses JSON records line by line
   ├─ Applies transformations:
   │  ├─ Remove PII fields
   │  ├─ Add computed fields (revenue, timestamps)
   │  ├─ Validate data types
   │  └─ Enrich with derived attributes
   ├─ Converts to Parquet format
   └─ Writes to transformed bucket with partitions

5. Transformed Storage (S3)
   ├─ Path: s3://transformed-bucket/year=2026/month=01/day=01/part.parquet
   ├─ Format: Parquet (Snappy compressed)
   └─ Ready for cataloging

6. Cataloging (Glue Crawler)
   ├─ Scans transformed S3 bucket
   ├─ Infers schema from Parquet metadata
   ├─ Creates table in Glue Data Catalog
   ├─ Discovers and registers partitions
   └─ Updates schema on changes

7. Query (Athena)
   ├─ Users write SQL queries
   ├─ Athena reads from Glue Catalog for metadata
   ├─ Executes massively parallel query on S3 data
   ├─ Uses partition pruning for efficiency
   └─ Returns results to users
```

## Component Interaction

```
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Firehose  │────────▶│   S3 Raw    │────────▶│   Lambda    │
└─────────────┘ writes  └─────────────┘ triggers└─────────────┘
                                                        │
                                                        │ writes
                                                        ▼
┌─────────────┐         ┌─────────────┐         ┌─────────────┐
│   Athena    │◀────────│Glue Catalog │◀────────│S3Transformed│
└─────────────┘ queries └─────────────┘ catalogs└─────────────┘
                               ▲
                               │ updates
                               │
                        ┌─────────────┐
                        │Glue Crawler │
                        └─────────────┘
```

## IAM Permissions Flow

```
Firehose Role
├─ PutObject on S3 Raw Bucket
└─ Write to CloudWatch Logs

Lambda Execution Role
├─ GetObject from S3 Raw Bucket
├─ PutObject to S3 Transformed Bucket
└─ Write to CloudWatch Logs

Glue Crawler Role
├─ GetObject from S3 Transformed Bucket
├─ UpdateTable in Glue Catalog
└─ Write to CloudWatch Logs

Athena (User-based)
├─ GetObject from S3 Transformed Bucket (via Glue)
├─ GetTable from Glue Catalog
└─ PutObject to Athena Results Bucket
```

## Data Size Transformation

```
Raw Data (JSON + GZIP)
┌──────────────────┐
│   100 MB JSON    │
│   ↓ GZIP         │
│   30 MB          │  (70% reduction)
└──────────────────┘
         │
         ▼
Transformed Data (Parquet + Snappy)
┌──────────────────┐
│   30 MB GZIP     │
│   ↓ Decompress   │
│   100 MB JSON    │
│   ↓ To Parquet   │
│   40 MB Parquet  │  (60% reduction from original)
└──────────────────┘
         │
         ▼
Query Performance
┌──────────────────┐
│  Columnar Format │
│  + Partitioning  │  = Fast Queries
│  + Compression   │    Low Cost
└──────────────────┘
```

## Cost Breakdown

```
Monthly Cost (~30M events)

Kinesis Firehose      ████████░░░░░░░░░░  $8.70  (25%)
Lambda                ████████░░░░░░░░░░  $6.00  (17%)
S3 Storage           ███░░░░░░░░░░░░░░░  $2.30  (7%)
Glue Crawler         ████████████████░░  $13.20 (38%)
Athena               ██░░░░░░░░░░░░░░░░  $0.50  (1%)
Other (CloudWatch)   ███░░░░░░░░░░░░░░░  $3.00  (9%)

Total: ~$35/month
```

## Scalability Profile

```
Events/Minute    Lambda Concurrency    Monthly Cost
─────────────────────────────────────────────────────
     100              1-2                  $10-15
   1,000              5-10                 $30-50
  10,000             50-100               $200-300
 100,000            500-1000            $1,500-2,500
```

## Monitoring Dashboard

```
CloudWatch Metrics

Firehose
├─ IncomingRecords (count/min)
├─ DeliveryToS3.Success (%)
├─ DeliveryToS3.DataFreshness (seconds)
└─ IncomingBytes (MB/min)

Lambda
├─ Invocations (count)
├─ Errors (count)
├─ Duration (ms)
├─ ConcurrentExecutions (count)
└─ Throttles (count)

Glue
├─ Crawler.DPUHour (cost)
├─ Crawler.Status (state)
└─ Table.LastUpdated (timestamp)

Athena
├─ QueryExecutionTime (seconds)
├─ DataScanned (GB)
└─ QueryCost ($)
```

## Deployment Timeline

```
Step 1: CDK Bootstrap         ████░░░░░░░░░░░░░░░░  2 min
Step 2: CDK Deploy           ████████████░░░░░░░░  8 min
Step 3: Generate Data        ████░░░░░░░░░░░░░░░░  2 min
Step 4: Wait for Processing  ████░░░░░░░░░░░░░░░░  3 min
Step 5: Run Crawler          ████░░░░░░░░░░░░░░░░  3 min
Step 6: Query Athena         ██░░░░░░░░░░░░░░░░░░  1 min

Total: ~19 minutes (end-to-end)
```

