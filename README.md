# Megazone Cloud - Serverless Clickstream ETL Pipeline

A production-ready serverless data processing pipeline for e-commerce clickstream data using AWS services. This solution ingests, transforms, and prepares streaming JSON data for analytics using Amazon Kinesis Firehose, Lambda, AWS Glue, and Amazon Athena.

[![AWS](https://img.shields.io/badge/AWS-Cloud-orange.svg)](https://aws.amazon.com/)
[![CDK](https://img.shields.io/badge/AWS%20CDK-2.115.0-blue.svg)](https://aws.amazon.com/cdk/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.3.0-blue.svg)](https://www.typescriptlang.org/)
[![Python](https://img.shields.io/badge/Python-3.11-green.svg)](https://www.python.org/)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Deployment](#deployment)
- [Testing](#testing)
- [Athena Queries](#athena-queries)
- [AI Tools Disclosure](#ai-tools-disclosure)
- [Cost Estimation](#cost-estimation)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Cleanup](#cleanup)
- [License](#license)

## 🎯 Overview

This project implements a serverless ETL (Extract, Transform, Load) pipeline that:

1. **Ingests** thousands of JSON-formatted clickstream events per minute via Kinesis Data Firehose
2. **Stores** raw data in S3 with date-based partitioning (year=YYYY/month=MM/day=DD)
3. **Transforms** data using Lambda functions (JSON → Parquet format)
4. **Catalogs** transformed data using AWS Glue Crawler
5. **Enables** SQL analytics using Amazon Athena

### Business Value

- **Real-time Insights**: Process streaming data with minimal latency
- **Cost-Effective**: Serverless architecture with pay-per-use pricing
- **Scalable**: Automatically handles thousands of events per minute
- **Analytics-Ready**: Data optimized for BI tools and SQL queries

## 🏗️ Architecture

```
Data Source → Kinesis Firehose → S3 (Raw/JSON) → Lambda → S3 (Transformed/Parquet) → Glue Crawler → Athena
```

For detailed architecture documentation, see [docs/architecture.md](docs/architecture.md)

### Key AWS Services Used

| Service | Purpose |
|---------|---------|
| **Kinesis Data Firehose** | Stream ingestion and S3 delivery |
| **S3** | Raw and transformed data storage |
| **Lambda** | Data transformation (JSON to Parquet) |
| **Glue** | Data cataloging and ETL jobs |
| **Athena** | SQL-based data analytics |
| **CloudWatch** | Logging and monitoring |
| **IAM** | Security and access control |

## ✨ Features

### Data Ingestion
- ✅ Kinesis Firehose for high-throughput streaming
- ✅ Automatic batching (60 seconds or 5MB)
- ✅ GZIP compression for cost savings
- ✅ Error handling and retry logic

### Data Transformation
- ✅ JSON to Parquet conversion
- ✅ Schema evolution support
- ✅ Data enrichment (computed fields)
- ✅ PII removal (IP addresses, emails)
- ✅ Two implementation options: Lambda (primary) or Glue Job (alternative)

### Data Storage
- ✅ Date-based partitioning for efficient querying
- ✅ Columnar Parquet format with Snappy compression
- ✅ Lifecycle policies for cost optimization
- ✅ S3 encryption at rest

### Data Cataloging
- ✅ Automatic schema discovery via Glue Crawler
- ✅ Partition management
- ✅ Schema versioning

### Analytics
- ✅ SQL queries via Athena
- ✅ 12+ sample analytical queries
- ✅ Integration with BI tools
- ✅ Cost-optimized with partitioning

## 📦 Prerequisites

- **AWS Account** with appropriate permissions
- **AWS CLI** (v2.x) - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- **Node.js** (v18.x or later) - [Download](https://nodejs.org/)
- **AWS CDK** (v2.115.0 or later)
- **Python** (v3.11 or later)
- **Git**

### AWS Permissions Required

Your AWS user/role needs permissions for:
- S3 (create/delete buckets, put/get objects)
- Kinesis Firehose (create/delete delivery streams)
- Lambda (create/update functions)
- Glue (create databases, tables, crawlers, jobs)
- Athena (query execution)
- IAM (create/update roles and policies)
- CloudFormation (create/update/delete stacks)
- CloudWatch Logs

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/megazone-clickstream-etl.git
cd megazone-clickstream-etl
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and Region
```

### 4. Bootstrap CDK (First-time only)

```bash
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

Replace `ACCOUNT-NUMBER` with your AWS account ID and `REGION` with your preferred region (e.g., `us-east-1`).

### 5. Deploy the Stack

```bash
npm run deploy
# or
cdk deploy
```

Approve the IAM changes when prompted. Deployment takes approximately 5-10 minutes.

### 6. Note the Stack Outputs

After deployment, save the output values:
- Firehose Delivery Stream Name
- S3 Bucket Names
- Glue Database Name
- Athena Workgroup Name

## 📁 Project Structure

```
megazone-clickstream-etl/
├── bin/
│   └── clickstream-etl.ts          # CDK app entry point
├── lib/
│   └── clickstream-etl-stack.ts    # Main CDK stack definition
├── lambda/
│   └── transformer/
│       ├── lambda_function.py      # Lambda transformation logic
│       └── requirements.txt        # Python dependencies
├── glue-scripts/
│   └── transform_clickstream.py    # Alternative Glue job script
├── scripts/
│   ├── generate_clickstream_data.py # Sample data generator
│   ├── run_crawler.sh              # Glue crawler execution script
│   └── requirements.txt            # Python dependencies
├── athena-queries/
│   └── sample_queries.sql          # Sample Athena SQL queries
├── docs/
│   ├── architecture.md             # Architecture documentation
│   └── deployment.md               # Deployment guide
├── cdk.json                        # CDK configuration
├── package.json                    # Node.js dependencies
├── tsconfig.json                   # TypeScript configuration
└── README.md                       # This file
```

## 🔧 Deployment

For detailed deployment instructions, see [docs/deployment.md](docs/deployment.md)

### Basic Deployment

```bash
# Install dependencies
npm install

# Review what will be deployed
cdk synth

# Deploy the stack
cdk deploy
```

### Environment Variables

You can customize the deployment by setting environment variables:

```bash
export CDK_DEFAULT_ACCOUNT=123456789012
export CDK_DEFAULT_REGION=us-east-1
cdk deploy
```

## 🧪 Testing

### Generate Sample Clickstream Data

1. Install Python dependencies:
```bash
cd scripts
pip3 install -r requirements.txt
```

2. Run the data generator:
```bash
python3 generate_clickstream_data.py
```

The script will continuously generate and send clickstream events to Kinesis Firehose. Press `Ctrl+C` to stop.

### Sample Event Structure

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "purchase",
  "timestamp": "2026-01-01T12:00:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/product/123",
  "product_id": "prod_123",
  "product_name": "Wireless Mouse",
  "product_category": "Electronics",
  "product_price": 29.99,
  "quantity": 2,
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York"
}
```

### Verify Data Flow

1. **Check Firehose Delivery**:
```bash
aws firehose describe-delivery-stream --delivery-stream-name clickstream-firehose
```

2. **Check Raw Data in S3**:
```bash
aws s3 ls s3://clickstream-raw-ACCOUNT-REGION/ --recursive
```

3. **Check Lambda Logs**:
```bash
aws logs tail /aws/lambda/clickstream-transformer --follow
```

4. **Check Transformed Data**:
```bash
aws s3 ls s3://clickstream-transformed-ACCOUNT-REGION/ --recursive
```

### Run Glue Crawler

After data is transformed:

```bash
cd scripts
./run_crawler.sh
```

Check crawler status:
```bash
aws glue get-crawler --name clickstream-crawler
```

## 📊 Athena Queries

Once the Glue Crawler has run, you can query the data using Athena.

### Using AWS Console

1. Navigate to Amazon Athena
2. Select workgroup: `clickstream-workgroup`
3. Select database: `clickstream_db`
4. Run queries from [athena-queries/sample_queries.sql](athena-queries/sample_queries.sql)

### Sample Queries

#### 1. Count Events by Type
```sql
SELECT 
    event_type,
    COUNT(*) as event_count
FROM clickstream_db.clickstream_events
GROUP BY event_type
ORDER BY event_count DESC;
```

#### 2. Daily Revenue
```sql
SELECT 
    year, month, day,
    COUNT(*) as purchase_count,
    SUM(revenue) as total_revenue,
    AVG(revenue) as avg_order_value
FROM clickstream_db.clickstream_events
WHERE event_type = 'purchase'
GROUP BY year, month, day
ORDER BY year DESC, month DESC, day DESC;
```

#### 3. Top Products by Revenue
```sql
SELECT 
    product_id,
    product_name,
    SUM(revenue) as total_revenue,
    COUNT(*) as purchase_count
FROM clickstream_db.clickstream_events
WHERE event_type = 'purchase'
GROUP BY product_id, product_name
ORDER BY total_revenue DESC
LIMIT 10;
```

See [athena-queries/sample_queries.sql](athena-queries/sample_queries.sql) for 12+ more analytical queries.

## 🤖 AI Tools Disclosure

AI tools were used to assist with certain aspects of this assessment project:

### Usage Areas

1. **Documentation**
   - Generated initial structure for README and technical documentation
   - Created sample query examples and formatting
   - Assisted with Markdown formatting and organization

2. **Code Suggestions**
   - Provided code completion suggestions for boilerplate code
   - Suggested AWS service integration patterns
   - Helped with Python syntax and best practices

3. **Research & Best Practices**
   - Researched AWS service configurations and limits
   - Suggested industry-standard naming conventions
   - Provided examples of data transformation patterns

**Note**: All code was thoroughly reviewed, tested, and validated in the AWS environment. Architecture design, implementation decisions, and troubleshooting were performed independently.

## 💰 Cost Estimation

Estimated monthly costs for processing 1 million events/day (~30 million events/month):

| Service | Usage | Estimated Cost |
|---------|-------|----------------|
| **Kinesis Firehose** | 30M records | ~$8.70 |
| **S3 Storage** | 100 GB | ~$2.30 |
| **Lambda** | 30M invocations | ~$6.00 |
| **Glue Crawler** | 1 hour/day | ~$13.20 |
| **Athena** | 100 GB scanned | ~$0.50 |
| **Data Transfer** | Minimal | ~$1.00 |
| **CloudWatch Logs** | Standard logging | ~$2.00 |

**Total Estimated Cost**: ~$30-35/month

### Cost Optimization Tips

1. **Increase Firehose buffer time** (60s → 300s) to reduce Lambda invocations
2. **Use S3 Lifecycle policies** to archive old data to Glacier
3. **Optimize Athena queries** with partitioning and columnar format
4. **Run Glue Crawler** only when needed (not continuously)
5. **Enable S3 Intelligent-Tiering** for infrequently accessed data

## 📈 Monitoring

### CloudWatch Dashboards

Key metrics to monitor:

1. **Firehose Metrics**
   - IncomingRecords
   - DeliveryToS3.Success
   - DeliveryToS3.DataFreshness

2. **Lambda Metrics**
   - Invocations
   - Errors
   - Duration
   - Throttles

3. **Glue Metrics**
   - Crawler DPU hours
   - Job run status

4. **Athena Metrics**
   - Query execution time
   - Data scanned

### CloudWatch Logs

- Firehose: `/aws/kinesisfirehose/clickstream`
- Lambda: `/aws/lambda/clickstream-transformer`
- Glue: `/aws-glue/crawlers` and `/aws-glue/jobs`

### Alarms

Consider setting up CloudWatch Alarms for:
- Firehose delivery failures
- Lambda error rate > 5%
- Lambda throttling
- S3 bucket size (cost control)

## 🔍 Troubleshooting

### Common Issues

#### Issue 1: Firehose Not Delivering Data

**Symptoms**: No files in raw S3 bucket

**Solutions**:
- Check Firehose IAM role permissions
- Verify S3 bucket exists and is accessible
- Check CloudWatch Logs for errors
- Ensure data is being sent to Firehose

#### Issue 2: Lambda Transformation Failures

**Symptoms**: Raw data exists but no transformed data

**Solutions**:
```bash
# Check Lambda logs
aws logs tail /aws/lambda/clickstream-transformer --follow

# Check Lambda function configuration
aws lambda get-function --function-name clickstream-transformer
```

#### Issue 3: Glue Crawler Not Finding Data

**Symptoms**: No tables created after running crawler

**Solutions**:
- Verify transformed data exists in S3
- Check crawler IAM permissions
- Ensure S3 path is correct in crawler configuration
- Run crawler manually and check logs

#### Issue 4: Athena Query Errors

**Symptoms**: `HIVE_PARTITION_SCHEMA_MISMATCH` or similar errors

**Solutions**:
```sql
-- Repair partitions
MSCK REPAIR TABLE clickstream_db.clickstream_events;

-- Or drop and recreate table
DROP TABLE clickstream_db.clickstream_events;
-- Then re-run Glue Crawler
```

For more troubleshooting tips, see [docs/deployment.md#troubleshooting](docs/deployment.md#troubleshooting)

## 🧹 Cleanup

To avoid ongoing charges, delete all resources:

```bash
cdk destroy
```

Or:
```bash
npm run destroy
```

This will delete:
- All S3 buckets and their contents
- Lambda functions
- Kinesis Firehose delivery stream
- Glue database, crawler, and jobs
- Athena workgroup
- IAM roles and policies
- CloudWatch log groups

**Note**: The CDK stack is configured with `autoDeleteObjects: true`, so S3 buckets will be emptied automatically during deletion.

## 📝 Additional Documentation

- [Architecture Details](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Sample Athena Queries](athena-queries/sample_queries.sql)

## 👤 Author

Submission for Megazone Cloud US Data Engineering Assessment

---

## 📚 References

- [AWS CDK Documentation](https://docs.aws.amazon.com/cdk/)
- [Amazon Kinesis Data Firehose](https://docs.aws.amazon.com/firehose/)
- [AWS Lambda](https://docs.aws.amazon.com/lambda/)
- [AWS Glue](https://docs.aws.amazon.com/glue/)
- [Amazon Athena](https://docs.aws.amazon.com/athena/)
- [AWS Data Wrangler](https://aws-sdk-pandas.readthedocs.io/)

---

**Built with ❤️ using AWS CDK and Serverless Architecture**

