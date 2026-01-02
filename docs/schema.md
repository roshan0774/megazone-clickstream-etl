# Sample Clickstream Event Schema

## Event Structure

All clickstream events follow this general structure with event-type-specific fields.

## Common Fields

These fields are present in all events:

```json
{
  "event_id": "string (UUID)",
  "event_type": "string (enum)",
  "timestamp": "string (ISO 8601)",
  "user_id": "string",
  "session_id": "string (UUID)",
  "page_url": "string (URL)",
  "device_type": "string (enum)",
  "browser": "string",
  "country": "string",
  "city": "string",
  "ip_address": "string (removed during transformation)"
}
```

## Event Types

### 1. Page View

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440000",
  "event_type": "page_view",
  "timestamp": "2026-01-01T12:00:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/product/wireless-mouse",
  "product_id": "prod_123",
  "product_name": "Wireless Mouse",
  "product_category": "Electronics",
  "product_price": 29.99,
  "quantity": 1,
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York",
  "ip_address": "192.168.1.1"
}
```

### 2. Add to Cart

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440002",
  "event_type": "add_to_cart",
  "timestamp": "2026-01-01T12:01:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/product/wireless-mouse",
  "product_id": "prod_123",
  "product_name": "Wireless Mouse",
  "product_category": "Electronics",
  "product_price": 29.99,
  "quantity": 2,
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York",
  "ip_address": "192.168.1.1"
}
```

### 3. Purchase

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440003",
  "event_type": "purchase",
  "timestamp": "2026-01-01T12:05:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/checkout/success",
  "product_id": "prod_123",
  "product_name": "Wireless Mouse",
  "product_category": "Electronics",
  "product_price": 29.99,
  "quantity": 2,
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York",
  "ip_address": "192.168.1.1"
}
```

### 4. Search

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440004",
  "event_type": "search",
  "timestamp": "2026-01-01T11:55:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/search?q=wireless+mouse",
  "search_query": "wireless mouse",
  "search_results_count": 42,
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York",
  "ip_address": "192.168.1.1"
}
```

### 5. Login

```json
{
  "event_id": "550e8400-e29b-41d4-a716-446655440005",
  "event_type": "login",
  "timestamp": "2026-01-01T11:50:00.000Z",
  "user_id": "user_1234",
  "session_id": "550e8400-e29b-41d4-a716-446655440001",
  "page_url": "https://example.com/login",
  "device_type": "desktop",
  "browser": "Chrome",
  "country": "United States",
  "city": "New York",
  "ip_address": "192.168.1.1"
}
```

## Transformed Schema

After transformation, the schema in Parquet format includes additional computed fields:

```json
{
  "event_id": "string",
  "event_type": "string",
  "event_timestamp": "timestamp",
  "user_id": "string",
  "session_id": "string",
  "page_url": "string",
  "product_id": "string",
  "product_name": "string",
  "product_category": "string",
  "product_price": "double",
  "quantity": "int",
  "device_type": "string",
  "browser": "string",
  "country": "string",
  "city": "string",
  "year": "string (partition)",
  "month": "string (partition)",
  "day": "string (partition)",
  "hour": "string",
  "day_of_week": "string",
  "revenue": "double (computed: price * quantity for purchases)"
}
```

## Field Descriptions

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| event_id | UUID | Unique event identifier | `550e8400-e29b-41d4-a716-446655440000` |
| event_type | String | Type of event | `page_view`, `purchase`, etc. |
| event_timestamp | Timestamp | When the event occurred | `2026-01-01T12:00:00.000Z` |
| user_id | String | User identifier | `user_1234` |
| session_id | UUID | Session identifier | `550e8400-...` |
| page_url | String | URL where event occurred | `https://example.com/...` |
| product_id | String | Product identifier | `prod_123` |
| product_name | String | Product name | `Wireless Mouse` |
| product_category | String | Product category | `Electronics` |
| product_price | Double | Product price in USD | `29.99` |
| quantity | Integer | Number of items | `2` |
| device_type | String | Device type | `desktop`, `mobile`, `tablet` |
| browser | String | Browser name | `Chrome`, `Firefox`, etc. |
| country | String | User's country | `United States` |
| city | String | User's city | `New York` |
| year | String | Year (partition) | `2026` |
| month | String | Month (partition) | `01` |
| day | String | Day (partition) | `01` |
| hour | String | Hour | `12` |
| day_of_week | String | Day name | `Monday` |
| revenue | Double | Revenue (price × quantity) | `59.98` |

## Removed Fields

These fields are removed during transformation for privacy:
- `ip_address`: IP address of the user
- `email`: User email (if present)

## Data Validation Rules

1. **event_id**: Must be a valid UUID
2. **timestamp**: Must be ISO 8601 format
3. **product_price**: Must be positive number
4. **quantity**: Must be positive integer
5. **event_type**: Must be one of: `page_view`, `add_to_cart`, `remove_from_cart`, `purchase`, `search`, `login`, `logout`
6. **device_type**: Must be one of: `desktop`, `mobile`, `tablet`

