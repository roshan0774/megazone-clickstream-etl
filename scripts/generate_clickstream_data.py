"""
Script to generate sample clickstream data and send to Kinesis Firehose
"""

import json
import boto3
import random
import time
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

# Initialize Kinesis Firehose client
firehose_client = boto3.client('firehose')

# Configuration
DELIVERY_STREAM_NAME = 'clickstream-firehose'
EVENTS_PER_BATCH = 100
DELAY_BETWEEN_BATCHES = 1  # seconds

# Sample data
EVENT_TYPES = ['page_view', 'add_to_cart', 'remove_from_cart', 'purchase', 'search', 'login', 'logout']
PRODUCT_CATEGORIES = ['Electronics', 'Clothing', 'Books', 'Home & Garden', 'Sports', 'Toys', 'Food']
DEVICE_TYPES = ['desktop', 'mobile', 'tablet']
BROWSERS = ['Chrome', 'Firefox', 'Safari', 'Edge']

def generate_clickstream_event():
    """Generate a single clickstream event"""
    event_type = random.choice(EVENT_TYPES)
    timestamp = datetime.utcnow().isoformat() + 'Z'

    event = {
        'event_id': fake.uuid4(),
        'event_type': event_type,
        'timestamp': timestamp,
        'user_id': f"user_{random.randint(1, 10000)}",
        'session_id': fake.uuid4(),
        'page_url': fake.url(),
        'device_type': random.choice(DEVICE_TYPES),
        'browser': random.choice(BROWSERS),
        'country': fake.country(),
        'city': fake.city(),
        'ip_address': fake.ipv4(),  # Will be removed in transformation
    }

    # Add product-related fields for relevant events
    if event_type in ['page_view', 'add_to_cart', 'remove_from_cart', 'purchase']:
        event['product_id'] = f"prod_{random.randint(1, 1000)}"
        event['product_name'] = fake.catch_phrase()
        event['product_category'] = random.choice(PRODUCT_CATEGORIES)
        event['product_price'] = round(random.uniform(5.99, 999.99), 2)

        if event_type in ['add_to_cart', 'purchase']:
            event['quantity'] = random.randint(1, 5)
        else:
            event['quantity'] = 1

    return event

def send_to_firehose(events):
    """Send events to Kinesis Firehose"""
    records = [
        {
            'Data': json.dumps(event) + '\n'
        }
        for event in events
    ]

    try:
        response = firehose_client.put_record_batch(
            DeliveryStreamName=DELIVERY_STREAM_NAME,
            Records=records
        )

        failed_count = response['FailedPutCount']
        success_count = len(records) - failed_count

        print(f"Sent {success_count} records successfully, {failed_count} failed")

        return success_count, failed_count
    except Exception as e:
        print(f"Error sending to Firehose: {str(e)}")
        return 0, len(records)

def main():
    """Main function to generate and send clickstream data"""
    print(f"Starting to generate clickstream data...")
    print(f"Delivery Stream: {DELIVERY_STREAM_NAME}")
    print(f"Events per batch: {EVENTS_PER_BATCH}")
    print(f"Delay between batches: {DELAY_BETWEEN_BATCHES} seconds")
    print("-" * 50)

    total_sent = 0
    total_failed = 0

    try:
        while True:
            # Generate batch of events
            events = [generate_clickstream_event() for _ in range(EVENTS_PER_BATCH)]

            # Send to Firehose
            sent, failed = send_to_firehose(events)

            total_sent += sent
            total_failed += failed

            print(f"Total sent: {total_sent}, Total failed: {total_failed}")

            # Wait before next batch
            time.sleep(DELAY_BETWEEN_BATCHES)
    except KeyboardInterrupt:
        print("\n" + "-" * 50)
        print(f"Stopped. Total sent: {total_sent}, Total failed: {total_failed}")

if __name__ == '__main__':
    main()


