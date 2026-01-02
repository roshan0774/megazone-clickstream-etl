#!/bin/bash

# Complete deployment and testing script for clickstream ETL pipeline

set -e

echo "================================================"
echo "Megazone Clickstream ETL - Deployment Script"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check prerequisites
echo "Checking prerequisites..."

# Add Homebrew to PATH if it exists (for macOS)
if [ -d "/opt/homebrew/bin" ]; then
    export PATH="/opt/homebrew/bin:$PATH"
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI not found. Please install it first."
    exit 1
fi
print_success "AWS CLI installed"

if ! command -v node &> /dev/null; then
    print_error "Node.js not found. Please install it first."
    print_info "On macOS, you can install it with: brew install node"
    exit 1
fi
print_success "Node.js installed"

if ! command -v cdk &> /dev/null; then
    print_error "AWS CDK not found. Installing..."
    npm install -g aws-cdk
fi
print_success "AWS CDK installed"

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    print_error "AWS credentials not configured. Run 'aws configure' first."
    exit 1
fi
print_success "AWS credentials configured"

# Get AWS account and region
export AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=$(aws configure get region)

if [ -z "$AWS_REGION" ]; then
    export AWS_REGION="us-east-1"
    print_info "No region configured, using default: us-east-1"
fi

echo ""
print_info "AWS Account: $AWS_ACCOUNT"
print_info "AWS Region: $AWS_REGION"
echo ""

# Install dependencies
echo "Installing dependencies..."
npm install
print_success "Dependencies installed"

# Check if CDK bootstrap is needed
echo ""
echo "Checking CDK bootstrap status..."
if ! aws cloudformation describe-stacks --stack-name CDKToolkit &> /dev/null; then
    print_info "CDK not bootstrapped. Bootstrapping now..."
    cdk bootstrap aws://${AWS_ACCOUNT}/${AWS_REGION}
    print_success "CDK bootstrapped"
else
    print_success "CDK already bootstrapped"
fi

# Synthesize the stack
echo ""
echo "Synthesizing CloudFormation template..."
cdk synth > /dev/null
print_success "Stack synthesized successfully"

# Deploy the stack
echo ""
echo "Deploying the stack (this will take 5-10 minutes)..."
print_info "You may be prompted to approve IAM changes. Type 'y' to continue."
echo ""

cdk deploy --require-approval never

print_success "Stack deployed successfully!"

# Get stack outputs
echo ""
echo "Retrieving stack outputs..."

FIREHOSE_NAME=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='FirehoseDeliveryStreamName'].OutputValue" \
    --output text)

RAW_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='RawDataBucketName'].OutputValue" \
    --output text)

TRANSFORMED_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='TransformedDataBucketName'].OutputValue" \
    --output text)

DATABASE_NAME=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='GlueDatabaseName'].OutputValue" \
    --output text)

CRAWLER_NAME=$(aws cloudformation describe-stacks \
    --stack-name ClickstreamEtlStack \
    --query "Stacks[0].Outputs[?OutputKey=='GlueCrawlerName'].OutputValue" \
    --output text)

echo ""
echo "================================================"
echo "Deployment Complete!"
echo "================================================"
echo ""
echo "Stack Outputs:"
echo "  Firehose Stream: $FIREHOSE_NAME"
echo "  Raw Bucket: $RAW_BUCKET"
echo "  Transformed Bucket: $TRANSFORMED_BUCKET"
echo "  Glue Database: $DATABASE_NAME"
echo "  Glue Crawler: $CRAWLER_NAME"
echo ""

# Ask if user wants to generate test data
read -p "Would you like to generate test data now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    print_info "Installing Python dependencies..."
    cd scripts
    pip3 install -r requirements.txt > /dev/null 2>&1 || pip install -r requirements.txt > /dev/null 2>&1

    print_info "Generating test data for 2 minutes..."
    print_info "Press Ctrl+C to stop early"

    timeout 120 python3 generate_clickstream_data.py || true

    print_success "Test data generated"

    echo ""
    print_info "Waiting 90 seconds for data to process..."
    sleep 90

    echo ""
    print_info "Starting Glue Crawler..."
    ./run_crawler.sh

    print_success "Crawler started"

    echo ""
    print_info "Waiting for crawler to complete (this may take 3-5 minutes)..."

    while true; do
        STATE=$(aws glue get-crawler --name $CRAWLER_NAME --query 'Crawler.State' --output text)
        if [ "$STATE" = "READY" ]; then
            break
        fi
        echo "  Crawler state: $STATE"
        sleep 10
    done

    print_success "Crawler completed!"

    echo ""
    echo "================================================"
    echo "Setup Complete!"
    echo "================================================"
    echo ""
    echo "Your pipeline is ready to use!"
    echo ""
    echo "Next steps:"
    echo "1. Open AWS Console → Athena"
    echo "2. Select workgroup: clickstream-workgroup"
    echo "3. Select database: $DATABASE_NAME"
    echo "4. Run queries from: athena-queries/sample_queries.sql"
    echo ""
    echo "Or use AWS CLI:"
    echo "  aws athena start-query-execution \\"
    echo "    --query-string \"SELECT COUNT(*) FROM ${DATABASE_NAME}.clickstream_events\" \\"
    echo "    --work-group clickstream-workgroup"
    echo ""

else
    echo ""
    echo "================================================"
    echo "Deployment Complete!"
    echo "================================================"
    echo ""
    echo "To generate test data later, run:"
    echo "  cd scripts"
    echo "  pip3 install -r requirements.txt"
    echo "  python3 generate_clickstream_data.py"
    echo ""
    echo "Then run the Glue Crawler:"
    echo "  ./scripts/run_crawler.sh"
    echo ""
fi

echo "To clean up all resources:"
echo "  cdk destroy"
echo ""
print_success "Deployment script completed successfully!"

