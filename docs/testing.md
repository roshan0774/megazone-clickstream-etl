# Testing Guide

## Overview

This guide explains how to test the serverless clickstream ETL pipeline.

## Pre-Deployment Testing

### 1. Validate CDK Stack

```bash
# Synthesize CloudFormation template
cdk synth

# Check for differences
cdk diff
```

### 2. Lint TypeScript Code

```bash
# Install ESLint (optional)
npm install --save-dev eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin

# Run linter
npx eslint lib/ bin/ --ext .ts
```

### 3. Validate Python Code

```bash
# Install pylint (optional)
pip3 install pylint

# Check Lambda function
pylint lambda/transformer/lambda_function.py

# Check Glue script
pylint glue-scripts/transform_clickstream.py
```

## Post-Deployment Testing

### 1. End-to-End Test

#### Step 1: Generate Sample Data

```bash
cd scripts
pip3 install -r requirements.txt
python3 generate_clickstream_data.py
```

Let it run for 2-3 minutes, then press `Ctrl+C`.

#### Step 2: Verify Raw Data

```bash
# Get bucket name
RAW_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='RawDataBucketName'].OutputValue" \
    --output text)

# List files (should see files in year=YYYY/month=MM/day=DD/ structure)
aws s3 ls s3://$RAW_BUCKET/ --recursive | head -20
```

Expected output:
```
2026-01-01 12:34:56     12345 year=2026/month=01/day=01/file1.gz
2026-01-01 12:35:56     12345 year=2026/month=01/day=01/file2.gz
```

#### Step 3: Verify Lambda Execution

```bash
# Check Lambda invocations
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Invocations \
    --dimensions Name=FunctionName,Value=clickstream-transformer \
    --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# Check Lambda errors
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=clickstream-transformer \
    --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 300 \
    --statistics Sum

# View Lambda logs
aws logs tail /aws/lambda/clickstream-transformer --follow
```

#### Step 4: Verify Transformed Data

```bash
# Get bucket name
TRANSFORMED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='TransformedDataBucketName'].OutputValue" \
    --output text)

# List files (should see Parquet files)
aws s3 ls s3://$TRANSFORMED_BUCKET/ --recursive | head -20
```

Expected output:
```
2026-01-01 12:36:00     45678 year=2026/month=01/day=01/part-0.parquet
```

#### Step 5: Run Glue Crawler

```bash
cd scripts
./run_crawler.sh

# Wait for crawler to complete (2-5 minutes)
# Check status
aws glue get-crawler --name clickstream-crawler --query 'Crawler.State'
```

Wait until status is `READY`.

#### Step 6: Verify Glue Catalog

```bash
# Check database
aws glue get-database --name clickstream_db

# Check tables
aws glue get-tables --database-name clickstream_db

# Get table schema
aws glue get-table \
    --database-name clickstream_db \
    --name clickstream_events \
    --query 'Table.StorageDescriptor.Columns'
```

#### Step 7: Test Athena Queries

```bash
# Start query execution
QUERY_ID=$(aws athena start-query-execution \
    --query-string "SELECT COUNT(*) as total_events FROM clickstream_db.clickstream_events" \
    --work-group clickstream-workgroup \
    --result-configuration OutputLocation=s3://clickstream-athena-results-$ACCOUNT-$REGION/ \
    --query 'QueryExecutionId' \
    --output text)

echo "Query ID: $QUERY_ID"

# Wait a few seconds, then check results
sleep 5

aws athena get-query-results --query-execution-id $QUERY_ID
```

## Performance Testing

### 1. Load Test with Higher Volume

Modify the data generator to send more events:

```python
# In scripts/generate_clickstream_data.py, change:
EVENTS_PER_BATCH = 500  # Increased from 100
DELAY_BETWEEN_BATCHES = 0.5  # Reduced from 1
```

Run for 10-15 minutes and monitor:

```bash
# Monitor Lambda concurrency
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name ConcurrentExecutions \
    --dimensions Name=FunctionName,Value=clickstream-transformer \
    --start-time $(date -u -v-30M +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Maximum

# Monitor Lambda duration
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Duration \
    --dimensions Name=FunctionName,Value=clickstream-transformer \
    --start-time $(date -u -v-30M +%Y-%m-%dT%H:%M:%S) \
    --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
    --period 60 \
    --statistics Average,Maximum
```

### 2. Query Performance Test

Test Athena query performance:

```sql
-- Full table scan (expensive)
SELECT COUNT(*) FROM clickstream_db.clickstream_events;

-- Partitioned query (optimized)
SELECT COUNT(*) 
FROM clickstream_db.clickstream_events
WHERE year = '2026' AND month = '01' AND day = '01';

-- Aggregation test
SELECT 
    product_category,
    COUNT(*) as events,
    SUM(revenue) as total_revenue
FROM clickstream_db.clickstream_events
WHERE year = '2026' AND month = '01'
GROUP BY product_category
ORDER BY total_revenue DESC;
```

Check query execution times and data scanned in Athena console.

## Error Testing

### 1. Test Lambda Error Handling

Send malformed data:

```python
# Create a test script: scripts/send_malformed_data.py
import json
import boto3

firehose_client = boto3.client('firehose')

# Send invalid JSON
firehose_client.put_record(
    DeliveryStreamName='clickstream-firehose',
    Record={'Data': 'invalid json data\n'}
)

# Send incomplete event
firehose_client.put_record(
    DeliveryStreamName='clickstream-firehose',
    Record={'Data': json.dumps({'event_id': 'test123'}) + '\n'}
)
```

Check Lambda logs for error handling:
```bash
aws logs tail /aws/lambda/clickstream-transformer --follow
```

### 2. Test IAM Permissions

Temporarily remove a permission and verify appropriate error:

```bash
# This should fail gracefully
aws lambda invoke \
    --function-name clickstream-transformer \
    --payload '{"test": "data"}' \
    response.json
```

## Integration Testing

### 1. Test Complete Data Flow

Create a script to verify data end-to-end:

```python
# scripts/test_e2e.py
import json
import boto3
import time
from datetime import datetime

firehose = boto3.client('firehose')
athena = boto3.client('athena')

# Generate unique test event
test_event_id = f"test-{int(time.time())}"
event = {
    'event_id': test_event_id,
    'event_type': 'test',
    'timestamp': datetime.utcnow().isoformat() + 'Z',
    'user_id': 'test_user',
    'session_id': 'test_session',
}

# Send to Firehose
print(f"Sending test event: {test_event_id}")
firehose.put_record(
    DeliveryStreamName='clickstream-firehose',
    Record={'Data': json.dumps(event) + '\n'}
)

# Wait for processing (2-3 minutes)
print("Waiting 180 seconds for processing...")
time.sleep(180)

# Query Athena to verify
print("Querying Athena...")
response = athena.start_query_execution(
    QueryString=f"SELECT * FROM clickstream_db.clickstream_events WHERE event_id = '{test_event_id}'",
    WorkGroup='clickstream-workgroup',
    ResultConfiguration={
        'OutputLocation': 's3://clickstream-athena-results-{account}-{region}/'
    }
)

query_id = response['QueryExecutionId']
print(f"Query ID: {query_id}")

# Wait for query to complete
while True:
    status = athena.get_query_execution(QueryExecutionId=query_id)
    state = status['QueryExecution']['Status']['State']
    
    if state in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
        break
    
    time.sleep(2)

if state == 'SUCCEEDED':
    results = athena.get_query_results(QueryExecutionId=query_id)
    if len(results['ResultSet']['Rows']) > 1:  # More than just header
        print("✅ Test PASSED: Event found in Athena")
    else:
        print("❌ Test FAILED: Event not found in Athena")
else:
    print(f"❌ Test FAILED: Query state: {state}")
```

## Cleanup After Testing

```bash
# Remove test data
aws s3 rm s3://$RAW_BUCKET/ --recursive
aws s3 rm s3://$TRANSFORMED_BUCKET/ --recursive

# Delete Athena query history
aws s3 rm s3://clickstream-athena-results-$ACCOUNT-$REGION/ --recursive
```

## Continuous Testing

For production, consider:

1. **Automated Testing**: Set up CI/CD pipeline with automated tests
2. **Monitoring**: CloudWatch alarms for failures
3. **Synthetic Testing**: Regular test data injection
4. **Data Quality**: Validation of transformed data schema

## Test Checklist

- [ ] CDK stack synthesizes without errors
- [ ] Stack deploys successfully
- [ ] Data generator sends events
- [ ] Raw data appears in S3 with partitions
- [ ] Lambda function executes without errors
- [ ] Transformed Parquet files created
- [ ] Glue Crawler discovers schema
- [ ] Athena queries return correct results
- [ ] All CloudWatch logs are accessible
- [ ] No unexpected AWS costs
- [ ] Stack destroys cleanly

## Troubleshooting Tests

If tests fail:

1. Check CloudWatch Logs for all services
2. Verify IAM permissions
3. Ensure S3 buckets are accessible
4. Check Firehose delivery stream status
5. Validate Lambda function configuration
6. Review Glue Crawler logs
7. Test Athena workgroup permissions

