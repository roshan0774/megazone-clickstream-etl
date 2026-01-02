#!/bin/bash

# Script to run the Glue Crawler
# This should be run after data has been transformed and written to S3

set -e

echo "Getting stack outputs..."

# Get crawler name from CDK outputs
CRAWLER_NAME=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='GlueCrawlerName'].OutputValue" \
    --output text)

if [ -z "$CRAWLER_NAME" ]; then
    echo "Error: Could not find Glue Crawler name in stack outputs"
    exit 1
fi

echo "Starting Glue Crawler: $CRAWLER_NAME"

# Start the crawler
aws glue start-crawler --name "$CRAWLER_NAME"

echo "Crawler started successfully!"
echo "You can check the status with: aws glue get-crawler --name $CRAWLER_NAME"

