-- JAYEK v3.1 incremental migration
-- Safe to run repeatedly. Baseline schema is created by infra/schema.sql.
CREATE INDEX IF NOT EXISTS idx_orders_updated_status ON orders(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_event_key ON notifications(event_key);
CREATE INDEX IF NOT EXISTS idx_support_tickets_updated ON support_tickets(status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_riders_online_location ON riders(is_online, latitude, longitude);
