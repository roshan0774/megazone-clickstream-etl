# Deployment Guide

## Prerequisites

Before deploying the solution, ensure you have:

1. **AWS Account**: Active AWS account with appropriate permissions
2. **AWS CLI**: Installed and configured
   ```bash
   aws --version
   aws configure
   ```

3. **Node.js**: Version 18.x or later
   ```bash
   node --version
   npm --version
   ```

4. **AWS CDK**: Installed globally
   ```bash
   npm install -g aws-cdk
   cdk --version
   ```

5. **Python**: Version 3.11 or later (for scripts)
   ```bash
   python3 --version
   ```

## Installation Steps

### 1. Clone the Repository

```bash
git clone <repository-url>
cd megazone-clickstream-etl
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Bootstrap CDK (First-time only)

If this is your first time using CDK in this AWS account/region:

```bash
cdk bootstrap aws://ACCOUNT-NUMBER/REGION
```

Example:
```bash
cdk bootstrap aws://123456789012/us-east-1
```

### 4. Review the Stack

```bash
cdk synth
```

This generates the CloudFormation template. Review it to understand what will be created.

### 5. Deploy the Stack

```bash
cdk deploy
```

Or use the npm script:
```bash
npm run deploy
```

You'll be prompted to approve IAM role changes and other security-sensitive changes. Type 'y' to proceed.

**Deployment time**: Approximately 5-10 minutes

### 6. Note the Outputs

After successful deployment, note the following outputs:
- Firehose Delivery Stream Name
- S3 Bucket Names (Raw, Transformed, Athena Results)
- Glue Database Name
- Glue Crawler Name
- Athena Workgroup Name

## Post-Deployment Steps

### 1. Upload Glue Script (Optional)

If you want to use the Glue job instead of Lambda:

```bash
# Get the Glue scripts bucket name from stack outputs
GLUE_SCRIPTS_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='GlueScriptsBucketName'].OutputValue" \
    --output text)

# Upload the Glue script
aws s3 cp glue-scripts/transform_clickstream.py \
    s3://$GLUE_SCRIPTS_BUCKET/transform_clickstream.py
```

### 2. Test Data Generation

Install Python dependencies:
```bash
cd scripts
pip3 install -r requirements.txt
```

Generate sample clickstream data:
```bash
python3 generate_clickstream_data.py
```

This will continuously send events to Kinesis Firehose. Press Ctrl+C to stop.

### 3. Wait for Data Processing

- **Firehose**: Buffers data for 60 seconds or until 5MB
- **Lambda**: Triggers automatically when data lands in S3
- **Transformation**: Takes a few seconds per batch

### 4. Run Glue Crawler

After data is transformed and in the transformed bucket:

```bash
cd scripts
./run_crawler.sh
```

Or manually:
```bash
aws glue start-crawler --name clickstream-crawler
```

Check crawler status:
```bash
aws glue get-crawler --name clickstream-crawler
```

Wait for the crawler to complete (usually 2-5 minutes).

### 5. Query with Athena

#### Using AWS Console:

1. Navigate to Amazon Athena
2. Select workgroup: `clickstream-workgroup`
3. Select database: `clickstream_db`
4. Run queries from `athena-queries/sample_queries.sql`

#### Using AWS CLI:

```bash
# Example query
aws athena start-query-execution \
    --query-string "SELECT event_type, COUNT(*) as count FROM clickstream_db.clickstream_events GROUP BY event_type" \
    --work-group clickstream-workgroup \
    --result-configuration OutputLocation=s3://clickstream-athena-results-ACCOUNT-REGION/
```

## Verification Steps

### 1. Check Firehose Delivery

```bash
# Get Firehose metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Firehose \
    --metric-name IncomingRecords \
    --dimensions Name=DeliveryStreamName,Value=clickstream-firehose \
    --start-time 2026-01-01T00:00:00Z \
    --end-time 2026-01-01T23:59:59Z \
    --period 3600 \
    --statistics Sum
```

### 2. Check S3 Raw Data

```bash
# List raw data files
RAW_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='RawDataBucketName'].OutputValue" \
    --output text)

aws s3 ls s3://$RAW_BUCKET/ --recursive
```

### 3. Check S3 Transformed Data

```bash
# List transformed data files
TRANSFORMED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='TransformedDataBucketName'].OutputValue" \
    --output text)

aws s3 ls s3://$TRANSFORMED_BUCKET/ --recursive
```

### 4. Check Lambda Executions

```bash
# View Lambda logs
aws logs tail /aws/lambda/clickstream-transformer --follow
```

### 5. Check Glue Catalog

```bash
# List tables
aws glue get-tables --database-name clickstream_db

# Get table details
aws glue get-table \
    --database-name clickstream_db \
    --name clickstream_events
```

## Troubleshooting

### Issue: Firehose not delivering data

**Solution:**
- Check CloudWatch Logs: `/aws/kinesisfirehose/clickstream`
- Verify IAM role permissions
- Check S3 bucket policies

### Issue: Lambda function failing

**Solution:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/clickstream-transformer --follow

# Check Lambda metrics
aws cloudwatch get-metric-statistics \
    --namespace AWS/Lambda \
    --metric-name Errors \
    --dimensions Name=FunctionName,Value=clickstream-transformer \
    --start-time 2026-01-01T00:00:00Z \
    --end-time 2026-01-01T23:59:59Z \
    --period 300 \
    --statistics Sum
```

### Issue: Glue Crawler not finding data

**Solution:**
- Ensure data exists in transformed bucket
- Check crawler IAM permissions
- Verify S3 path in crawler configuration
- Run crawler manually and check logs

### Issue: Athena queries failing

**Solution:**
- Verify table exists: `SHOW TABLES IN clickstream_db;`
- Check partitions: `SHOW PARTITIONS clickstream_db.clickstream_events;`
- Repair partitions: `MSCK REPAIR TABLE clickstream_db.clickstream_events;`

## Updating the Stack

If you make changes to the CDK code:

```bash
# See what will change
cdk diff

# Apply changes
cdk deploy
```

## Cleanup

To delete all resources:

```bash
cdk destroy
```

Or:
```bash
npm run destroy
```

**Note**: This will delete all S3 buckets and their contents due to `autoDeleteObjects: true` in the CDK code.

## Estimated Costs

For 1 million events per day:

- **Kinesis Firehose**: ~$0.29/day
- **S3 Storage**: ~$0.023/GB/month
- **Lambda**: ~$0.20/million requests
- **Glue Crawler**: ~$0.44/hour (runs on-demand)
- **Athena**: ~$5/TB scanned

**Total estimated cost**: $10-50/month (depending on data volume and query frequency)

## Support

For issues or questions:
1. Check AWS service status
2. Review CloudWatch Logs
3. Check AWS documentation
4. Contact AWS Support (if you have a support plan)

