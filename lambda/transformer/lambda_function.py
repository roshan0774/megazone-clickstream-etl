import json
import boto3
import gzip
import os
from datetime import datetime
import urllib.parse
import awswrangler as wr
import pandas as pd

s3_client = boto3.client('s3')
TRANSFORMED_BUCKET = os.environ['TRANSFORMED_BUCKET']

def lambda_handler(event, context):
    """
    Lambda function to transform JSON clickstream data to Parquet format.
    Triggered by S3 events when new data lands in the raw bucket.
    """
    try:
        # Get the S3 bucket and key from the event
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = urllib.parse.unquote_plus(record['s3']['object']['key'])

            print(f"Processing file: s3://{bucket}/{key}")

            # Download and decompress the file
            response = s3_client.get_object(Bucket=bucket, Key=key)

            # Handle gzipped files
            if key.endswith('.gz'):
                with gzip.GzipFile(fileobj=response['Body']) as gzipfile:
                    content = gzipfile.read().decode('utf-8')
            else:
                content = response['Body'].read().decode('utf-8')

            # Parse JSON records (newline-delimited JSON)
            records = []
            for line in content.strip().split('\n'):
                if line:
                    try:
                        json_record = json.loads(line)
                        # Transform and enrich the data
                        transformed_record = transform_record(json_record)
                        records.append(transformed_record)
                    except json.JSONDecodeError as e:
                        print(f"Error parsing JSON: {e}")
                        continue

            if not records:
                print("No valid records found")
                return {
                    'statusCode': 200,
                    'body': json.dumps('No valid records to process')
                }

            # Convert to Parquet using awswrangler
            df = pd.DataFrame(records)

            # Extract date partition from the original key
            # Expected format: year=YYYY/month=MM/day=DD/
            parts = key.split('/')
            year = month = day = None
            for part in parts:
                if part.startswith('year='):
                    year = part.split('=')[1]
                elif part.startswith('month='):
                    month = part.split('=')[1]
                elif part.startswith('day='):
                    day = part.split('=')[1]

            # If date partitions not found in path, use event timestamp
            if not all([year, month, day]):
                event_time = records[0].get('event_timestamp', datetime.utcnow().isoformat())
                dt = datetime.fromisoformat(event_time.replace('Z', '+00:00'))
                year = dt.strftime('%Y')
                month = dt.strftime('%m')
                day = dt.strftime('%d')

            # Define output path with partitioning
            output_path = f"s3://{TRANSFORMED_BUCKET}/year={year}/month={month}/day={day}/"

            # Write Parquet file with partitioning
            wr.s3.to_parquet(
                df=df,
                path=output_path,
                dataset=True,
                mode='append',
                compression='snappy',
                database='clickstream_db',
                table='clickstream_events',
                partition_cols=['year', 'month', 'day']
            )

            print(f"Successfully processed {len(records)} records to {output_path}")

        return {
            'statusCode': 200,
            'body': json.dumps(f'Successfully processed {len(records)} records')
        }

    except Exception as e:
        print(f"Error processing file: {str(e)}")
        raise e


def transform_record(record):
    """
    Transform and enrich a single clickstream record.
    Removes sensitive fields and adds computed fields.
    """
    # Extract and transform fields
    transformed = {
        'event_id': record.get('event_id', ''),
        'event_type': record.get('event_type', ''),
        'event_timestamp': record.get('timestamp', ''),
        'user_id': record.get('user_id', ''),
        'session_id': record.get('session_id', ''),
        'page_url': record.get('page_url', ''),
        'product_id': record.get('product_id', ''),
        'product_name': record.get('product_name', ''),
        'product_category': record.get('product_category', ''),
        'product_price': float(record.get('product_price', 0.0)),
        'quantity': int(record.get('quantity', 0)),
        'device_type': record.get('device_type', ''),
        'browser': record.get('browser', ''),
        'country': record.get('country', ''),
        'city': record.get('city', ''),
    }

    # Add computed fields
    if record.get('timestamp'):
        try:
            dt = datetime.fromisoformat(record['timestamp'].replace('Z', '+00:00'))
            transformed['year'] = dt.strftime('%Y')
            transformed['month'] = dt.strftime('%m')
            transformed['day'] = dt.strftime('%d')
            transformed['hour'] = dt.strftime('%H')
            transformed['day_of_week'] = dt.strftime('%A')
            transformed['date'] = dt.strftime('%Y-%m-%d')
        except:
            pass

    # Calculate revenue for purchase events
    if record.get('event_type') == 'purchase':
        transformed['revenue'] = transformed['product_price'] * transformed['quantity']
    else:
        transformed['revenue'] = 0.0

    # Remove sensitive fields (example: IP address, email)
    # These fields are intentionally not included in transformed record

    return transformed

