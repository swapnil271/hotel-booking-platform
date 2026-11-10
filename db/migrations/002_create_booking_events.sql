CREATE TABLE IF NOT EXISTS booking_events (
    id         BIGSERIAL    PRIMARY KEY,
    booking_id UUID         NOT NULL REFERENCES hotel_bookings (id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload    JSONB,
    created_at TIMESTAMP    NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id_created_at
    ON booking_events (booking_id, created_at);
