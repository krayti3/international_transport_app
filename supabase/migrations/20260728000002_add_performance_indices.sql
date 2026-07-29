-- Performance indices for frequently filtered trip_orders queries
CREATE INDEX IF NOT EXISTS idx_trip_orders_status ON trip_orders(status);
CREATE INDEX IF NOT EXISTS idx_trip_orders_driver_date ON trip_orders(driver_id, departure_date);
CREATE INDEX IF NOT EXISTS idx_advances_status_driver ON advances(driver_id, status);

-- Note: PostgreSQL can use the index in either ASC or DESC order, so we do NOT specify DESC in the index definition.
