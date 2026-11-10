CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at_cover
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
