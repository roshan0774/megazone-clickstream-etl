-- Sample Athena queries for analyzing clickstream data

-- 1. Count total events by event type
SELECT
    event_type,
    COUNT(*) as event_count
FROM clickstream_db.clickstream_events
GROUP BY event_type
ORDER BY event_count DESC;

-- 2. Daily revenue from purchases
SELECT
    year,
    month,
    day,
    COUNT(*) as purchase_count,
    SUM(revenue) as total_revenue,
    AVG(revenue) as avg_order_value
FROM clickstream_db.clickstream_events
WHERE event_type = 'purchase'
GROUP BY year, month, day
ORDER BY year DESC, month DESC, day DESC;

-- 3. Top 10 products by views
SELECT
    product_id,
    product_name,
    product_category,
    COUNT(*) as view_count
FROM clickstream_db.clickstream_events
WHERE event_type = 'page_view'
    AND product_id IS NOT NULL
GROUP BY product_id, product_name, product_category
ORDER BY view_count DESC
LIMIT 10;

-- 4. User engagement by device type
SELECT
    device_type,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events,
    COUNT(*) * 1.0 / COUNT(DISTINCT user_id) as events_per_user
FROM clickstream_db.clickstream_events
GROUP BY device_type
ORDER BY unique_users DESC;

-- 5. Conversion funnel analysis
SELECT
    'Page Views' as stage,
    COUNT(DISTINCT user_id) as users,
    1 as stage_order
FROM clickstream_db.clickstream_events
WHERE event_type = 'page_view'

UNION ALL

SELECT
    'Add to Cart' as stage,
    COUNT(DISTINCT user_id) as users,
    2 as stage_order
FROM clickstream_db.clickstream_events
WHERE event_type = 'add_to_cart'

UNION ALL

SELECT
    'Purchases' as stage,
    COUNT(DISTINCT user_id) as users,
    3 as stage_order
FROM clickstream_db.clickstream_events
WHERE event_type = 'purchase'

ORDER BY stage_order;

-- 6. Hourly traffic pattern
SELECT
    hour,
    COUNT(*) as event_count,
    COUNT(DISTINCT user_id) as unique_users
FROM clickstream_db.clickstream_events
GROUP BY hour
ORDER BY hour;

-- 7. Top products by revenue
SELECT
    product_id,
    product_name,
    product_category,
    SUM(revenue) as total_revenue,
    COUNT(*) as purchase_count,
    AVG(product_price) as avg_price
FROM clickstream_db.clickstream_events
WHERE event_type = 'purchase'
GROUP BY product_id, product_name, product_category
ORDER BY total_revenue DESC
LIMIT 10;

-- 8. Geographic distribution of users
SELECT
    country,
    city,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events
FROM clickstream_db.clickstream_events
GROUP BY country, city
ORDER BY unique_users DESC
LIMIT 20;

-- 9. Browser usage statistics
SELECT
    browser,
    COUNT(DISTINCT user_id) as unique_users,
    COUNT(*) as total_events,
    SUM(CASE WHEN event_type = 'purchase' THEN revenue ELSE 0 END) as total_revenue
FROM clickstream_db.clickstream_events
GROUP BY browser
ORDER BY unique_users DESC;

-- 10. Day of week performance
SELECT
    day_of_week,
    COUNT(*) as total_events,
    COUNT(DISTINCT user_id) as unique_users,
    SUM(CASE WHEN event_type = 'purchase' THEN 1 ELSE 0 END) as purchases,
    SUM(revenue) as total_revenue
FROM clickstream_db.clickstream_events
GROUP BY day_of_week
ORDER BY
    CASE day_of_week
        WHEN 'Monday' THEN 1
        WHEN 'Tuesday' THEN 2
        WHEN 'Wednesday' THEN 3
        WHEN 'Thursday' THEN 4
        WHEN 'Friday' THEN 5
        WHEN 'Saturday' THEN 6
        WHEN 'Sunday' THEN 7
    END;

-- 11. Query data for a specific date partition
SELECT *
FROM clickstream_db.clickstream_events
WHERE year = '2026'
    AND month = '01'
    AND day = '01'
LIMIT 100;

-- 12. Product category performance
SELECT
    product_category,
    COUNT(DISTINCT CASE WHEN event_type = 'page_view' THEN user_id END) as viewers,
    COUNT(DISTINCT CASE WHEN event_type = 'add_to_cart' THEN user_id END) as cart_additions,
    COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN user_id END) as purchasers,
    SUM(revenue) as total_revenue
FROM clickstream_db.clickstream_events
WHERE product_category IS NOT NULL
GROUP BY product_category
ORDER BY total_revenue DESC;

