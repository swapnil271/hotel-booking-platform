CREATE TABLE IF NOT EXISTS hotel_bookings (
    id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id        UUID           NOT NULL,
    hotel_id      VARCHAR(100)   NOT NULL,
    city          VARCHAR(100)   NOT NULL,
    checkin_date  DATE           NOT NULL,
    checkout_date DATE           NOT NULL,
    amount        NUMERIC(12, 2) NOT NULL,
    status        VARCHAR(50)    NOT NULL,
    created_at    TIMESTAMP      NOT NULL DEFAULT now(),
    CONSTRAINT hotel_bookings_dates_chk CHECK (checkout_date > checkin_date),
    CONSTRAINT hotel_bookings_amount_chk CHECK (amount >= 0),
    CONSTRAINT hotel_bookings_status_chk CHECK (
        status IN ('pending', 'confirmed', 'completed', 'cancelled', 'refunded')
    )
);
