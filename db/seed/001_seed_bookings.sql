WITH series AS (
    SELECT
        g,
        g % 6 AS city_idx,
        date_trunc('second', NOW() - ((g * 53) % 172800) * INTERVAL '1 minute') AS created_at
    FROM generate_series(1, 10000) AS g
)
INSERT INTO hotel_bookings (
    id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at
)
SELECT
    md5('booking-' || g)::uuid,
    md5('org-' || (g % 7))::uuid,
    'htl-' || city_idx || '-' || lpad(((g % 11) + 1)::text, 2, '0'),
    (ARRAY['delhi', 'mumbai', 'bangalore', 'pune', 'chennai', 'hyderabad'])[city_idx + 1],
    (created_at + (((g % 45) + 1) * INTERVAL '1 day'))::date,
    (created_at + (((g % 45) + 1 + (g % 6) + 1) * INTERVAL '1 day'))::date,
    (2500 + ((g * 7919) % 45000) + ((g % 100) / 100.0))::numeric(12, 2),
    (ARRAY['pending', 'confirmed', 'completed', 'cancelled', 'refunded'])[(g % 5) + 1],
    created_at
FROM series
ON CONFLICT (id) DO NOTHING;

INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT e.booking_id, e.event_type, e.payload, e.created_at
FROM (
    SELECT
        b.id AS booking_id,
        'booking_created' AS event_type,
        jsonb_build_object('city', b.city, 'hotel_id', b.hotel_id, 'amount', b.amount, 'source', 'web') AS payload,
        b.created_at AS created_at
    FROM hotel_bookings b
    WHERE b.status <> 'pending'

    UNION ALL

    SELECT
        b.id,
        'payment_received',
        jsonb_build_object('amount', b.amount, 'currency', 'INR', 'gateway', 'razorpay'),
        b.created_at + INTERVAL '2 minutes'
    FROM hotel_bookings b
    WHERE b.status IN ('confirmed', 'completed', 'refunded')

    UNION ALL

    SELECT
        b.id,
        'booking_cancelled',
        jsonb_build_object('reason', 'customer_request'),
        b.created_at + INTERVAL '1 day'
    FROM hotel_bookings b
    WHERE b.status = 'cancelled'

    UNION ALL

    SELECT
        b.id,
        'refund_issued',
        jsonb_build_object('amount', b.amount, 'currency', 'INR'),
        b.created_at + INTERVAL '3 days'
    FROM hotel_bookings b
    WHERE b.status = 'refunded'
) e
WHERE NOT EXISTS (SELECT 1 FROM booking_events)
ORDER BY e.created_at, e.booking_id, e.event_type;

VACUUM (ANALYZE) hotel_bookings;
VACUUM (ANALYZE) booking_events;
