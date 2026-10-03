CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS users(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),phone VARCHAR(20) UNIQUE NOT NULL,name VARCHAR(120),role VARCHAR(30) NOT NULL DEFAULT 'CUSTOMER',created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS villages(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),name VARCHAR(120) UNIQUE NOT NULL,center_latitude NUMERIC(10,7),center_longitude NUMERIC(10,7),is_active BOOLEAN DEFAULT true);
CREATE TABLE IF NOT EXISTS addresses(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),user_id UUID NOT NULL REFERENCES users(id),label VARCHAR(50),village VARCHAR(120) NOT NULL,details TEXT,latitude NUMERIC(10,7),longitude NUMERIC(10,7),is_default BOOLEAN DEFAULT false,created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS merchants(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),owner_user_id UUID REFERENCES users(id),name VARCHAR(160) NOT NULL,type VARCHAR(40) NOT NULL,village VARCHAR(120) NOT NULL,rating NUMERIC(2,1) DEFAULT 0,delivery_minutes INT DEFAULT 30,delivery_fee NUMERIC(12,2) DEFAULT 0,is_active BOOLEAN NOT NULL DEFAULT true,created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS categories(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),name VARCHAR(120) NOT NULL,icon VARCHAR(120),sort_order INT DEFAULT 0,is_active BOOLEAN DEFAULT true);
CREATE TABLE IF NOT EXISTS products(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),merchant_id UUID NOT NULL REFERENCES merchants(id),category_id UUID REFERENCES categories(id),name VARCHAR(180) NOT NULL,description TEXT,price NUMERIC(12,2) NOT NULL,image_url TEXT,is_available BOOLEAN DEFAULT true,order_count INT NOT NULL DEFAULT 0,created_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE IF NOT EXISTS orders(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),user_id UUID NOT NULL REFERENCES users(id),merchant_id UUID NOT NULL REFERENCES merchants(id),address_id UUID REFERENCES addresses(id),status VARCHAR(40) NOT NULL,subtotal NUMERIC(12,2) NOT NULL,delivery_fee NUMERIC(12,2) DEFAULT 0,discount NUMERIC(12,2) DEFAULT 0,total NUMERIC(12,2) NOT NULL,idempotency_key VARCHAR(160) UNIQUE,notes TEXT,created_at TIMESTAMPTZ DEFAULT now(),updated_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE IF NOT EXISTS order_items(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,product_id UUID NOT NULL REFERENCES products(id),name_snapshot VARCHAR(180) NOT NULL,unit_price NUMERIC(12,2) NOT NULL,quantity INT NOT NULL CHECK(quantity>0),options_json JSONB DEFAULT '{}'::jsonb);
CREATE TABLE IF NOT EXISTS order_status_history(id BIGSERIAL PRIMARY KEY,order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,status VARCHAR(40) NOT NULL,actor_type VARCHAR(30) NOT NULL,actor_id UUID,created_at TIMESTAMPTZ DEFAULT now());
CREATE TABLE IF NOT EXISTS otp_challenges(id UUID PRIMARY KEY,phone VARCHAR(20) NOT NULL,code VARCHAR(10) NOT NULL,expires_at TIMESTAMPTZ NOT NULL,consumed_at TIMESTAMPTZ,attempts INT NOT NULL DEFAULT 0);
CREATE TABLE IF NOT EXISTS riders(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),user_id UUID UNIQUE NOT NULL REFERENCES users(id),vehicle_type VARCHAR(30),is_online BOOLEAN DEFAULT false,latitude NUMERIC(10,7),longitude NUMERIC(10,7));
CREATE TABLE IF NOT EXISTS deliveries(id UUID PRIMARY KEY DEFAULT gen_random_uuid(),order_id UUID UNIQUE NOT NULL REFERENCES orders(id),rider_id UUID REFERENCES riders(id),assigned_at TIMESTAMPTZ,picked_up_at TIMESTAMPTZ,delivered_at TIMESTAMPTZ,proof_url TEXT);
CREATE INDEX IF NOT EXISTS idx_merchants_village ON merchants(village);CREATE INDEX IF NOT EXISTS idx_products_merchant ON products(merchant_id);CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id);CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);CREATE INDEX IF NOT EXISTS idx_products_search ON products USING gin(to_tsvector('simple',name));
INSERT INTO villages(name,center_latitude,center_longitude) VALUES('الديسمي',29.6465,31.3185) ON CONFLICT(name) DO NOTHING;
INSERT INTO categories(name,icon,sort_order) VALUES ('أكل','restaurant',1),('ماركت','shopping_cart',2),('صيدلية','medication',3),('خضار وفاكهة','eco',4),('جزارة','set_meal',5),('مخابز','bakery_dining',6),('محلات متنوعة','storefront',7) ON CONFLICT DO NOTHING;
INSERT INTO merchants(name,type,village,rating,delivery_minutes,delivery_fee) SELECT 'مطعم هابي','FOOD','الديسمي',4.7,30,25 WHERE NOT EXISTS(SELECT 1 FROM merchants WHERE name='مطعم هابي' AND village='الديسمي');
INSERT INTO merchants(name,type,village,rating,delivery_minutes,delivery_fee) SELECT 'سوبر ماركت بلدك','GROCERY','الديسمي',4.6,25,20 WHERE NOT EXISTS(SELECT 1 FROM merchants WHERE name='سوبر ماركت بلدك' AND village='الديسمي');
INSERT INTO merchants(name,type,village,rating,delivery_minutes,delivery_fee) SELECT 'صيدلية الأمان','PHARMACY','الديسمي',4.8,20,15 WHERE NOT EXISTS(SELECT 1 FROM merchants WHERE name='صيدلية الأمان' AND village='الديسمي');
INSERT INTO products(merchant_id,category_id,name,description,price,order_count) SELECT m.id,c.id,'بيتزا مارجريتا','طازة ومجهزة يوميًا',180,30 FROM merchants m,categories c WHERE m.name='مطعم هابي' AND c.name='أكل' AND NOT EXISTS(SELECT 1 FROM products p WHERE p.name='بيتزا مارجريتا' AND p.merchant_id=m.id);
INSERT INTO products(merchant_id,category_id,name,description,price,order_count) SELECT m.id,c.id,'بيتزا خضار','خضار طازة وجبن',200,24 FROM merchants m,categories c WHERE m.name='مطعم هابي' AND c.name='أكل' AND NOT EXISTS(SELECT 1 FROM products p WHERE p.name='بيتزا خضار' AND p.merchant_id=m.id);
INSERT INTO products(merchant_id,category_id,name,description,price,order_count) SELECT m.id,c.id,'بيتزا دجاج','دجاج وتتبيلة خاصة',220,18 FROM merchants m,categories c WHERE m.name='مطعم هابي' AND c.name='أكل' AND NOT EXISTS(SELECT 1 FROM products p WHERE p.name='بيتزا دجاج' AND p.merchant_id=m.id);
INSERT INTO products(merchant_id,category_id,name,description,price,order_count) SELECT m.id,c.id,'طماطم طازجة','كيلو',25,16 FROM merchants m,categories c WHERE m.name='سوبر ماركت بلدك' AND c.name='خضار وفاكهة' AND NOT EXISTS(SELECT 1 FROM products p WHERE p.name='طماطم طازجة' AND p.merchant_id=m.id);
INSERT INTO products(merchant_id,category_id,name,description,price,order_count) SELECT m.id,c.id,'مياه معدنية','عبوة 1.5 لتر',10,12 FROM merchants m,categories c WHERE m.name='سوبر ماركت بلدك' AND c.name='ماركت' AND NOT EXISTS(SELECT 1 FROM products p WHERE p.name='مياه معدنية' AND p.merchant_id=m.id);


CREATE INDEX IF NOT EXISTS idx_deliveries_rider ON deliveries(rider_id);
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_challenges(phone);
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE riders ADD COLUMN IF NOT EXISTS last_location_at TIMESTAMPTZ;

ALTER TABLE merchants ADD COLUMN IF NOT EXISTS owner_user_id UUID REFERENCES users(id);

INSERT INTO users(id,phone,name,role) VALUES
('00000000-0000-4000-8000-000000000001','01000000001','مدير جايك','SUPER_ADMIN'),
('00000000-0000-4000-8000-000000000002','01000000002','مدير المتجر','MERCHANT'),
('00000000-0000-4000-8000-000000000003','01000000003','كابتن جايك','RIDER')
ON CONFLICT(id) DO NOTHING;
UPDATE merchants SET owner_user_id='00000000-0000-4000-8000-000000000002' WHERE name IN ('مطعم هابي','سوبر ماركت بلدك','صيدلية الأمان') AND owner_user_id IS NULL;
INSERT INTO riders(user_id,vehicle_type,is_online) VALUES('00000000-0000-4000-8000-000000000003','MOTORCYCLE',false) ON CONFLICT(user_id) DO NOTHING;

CREATE TABLE IF NOT EXISTS notifications(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 type VARCHAR(40) NOT NULL, title VARCHAR(180) NOT NULL, body TEXT NOT NULL, data_json JSONB DEFAULT '{}'::jsonb,
 read_at TIMESTAMPTZ, created_at TIMESTAMPTZ DEFAULT now(), event_key VARCHAR(220)
);
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS event_key VARCHAR(220);
CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_user_event ON notifications(user_id,event_key) WHERE event_key IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_user_created ON notifications(user_id,created_at DESC);

CREATE TABLE IF NOT EXISTS reviews(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id), merchant_id UUID NOT NULL REFERENCES merchants(id),
 rating INT NOT NULL CHECK(rating BETWEEN 1 AND 5), comment TEXT, created_at TIMESTAMPTZ DEFAULT now(),
 UNIQUE(order_id,user_id)
);

CREATE TABLE IF NOT EXISTS support_tickets(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id), order_id UUID REFERENCES orders(id),
 subject VARCHAR(180) NOT NULL, message TEXT NOT NULL, status VARCHAR(30) NOT NULL DEFAULT 'OPEN',
 priority VARCHAR(20) NOT NULL DEFAULT 'NORMAL', created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_support_status ON support_tickets(status,created_at DESC);

CREATE TABLE IF NOT EXISTS rider_location_events(
 id BIGSERIAL PRIMARY KEY, rider_id UUID NOT NULL REFERENCES riders(id) ON DELETE CASCADE,
 order_id UUID REFERENCES orders(id) ON DELETE SET NULL, latitude NUMERIC(10,7) NOT NULL, longitude NUMERIC(10,7) NOT NULL,
 accuracy NUMERIC(8,2), recorded_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_rider_location_order_time ON rider_location_events(order_id,recorded_at DESC);

CREATE TABLE IF NOT EXISTS device_tokens(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 token TEXT UNIQUE NOT NULL, platform VARCHAR(20) NOT NULL, created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
CREATE TABLE IF NOT EXISTS payments(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id), method VARCHAR(30) NOT NULL, status VARCHAR(30) NOT NULL,
 amount NUMERIC(12,2) NOT NULL, currency CHAR(3) NOT NULL DEFAULT 'EGP', provider VARCHAR(40), provider_reference VARCHAR(180),
 created_at TIMESTAMPTZ DEFAULT now(), updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_payments_provider_ref ON payments(provider,provider_reference) WHERE provider_reference IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_rider_location_rider_time ON rider_location_events(rider_id,recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_rider_location_order_time2 ON rider_location_events(order_id,recorded_at DESC);

CREATE TABLE IF NOT EXISTS refresh_tokens(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 token_hash VARCHAR(128) UNIQUE NOT NULL, expires_at TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ,
 created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user ON refresh_tokens(user_id,expires_at DESC);
CREATE TABLE IF NOT EXISTS audit_logs(
 id BIGSERIAL PRIMARY KEY, user_id UUID REFERENCES users(id) ON DELETE SET NULL,
 action VARCHAR(80) NOT NULL, entity_type VARCHAR(50), entity_id UUID, metadata_json JSONB DEFAULT '{}'::jsonb,
 created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id,created_at DESC);

ALTER TABLE otp_challenges ADD COLUMN IF NOT EXISTS attempts INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS delivery_zones(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 name VARCHAR(120) UNIQUE NOT NULL,
 center_latitude NUMERIC(10,7) NOT NULL,
 center_longitude NUMERIC(10,7) NOT NULL,
 radius_km NUMERIC(8,2) NOT NULL DEFAULT 8,
 base_fee NUMERIC(12,2) NOT NULL DEFAULT 15,
 per_km_fee NUMERIC(12,2) NOT NULL DEFAULT 3,
 min_fee NUMERIC(12,2) NOT NULL DEFAULT 15,
 is_active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ DEFAULT now(),
 updated_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_delivery_zones_active ON delivery_zones(is_active);
INSERT INTO delivery_zones(name,center_latitude,center_longitude,radius_km,base_fee,per_km_fee,min_fee)
VALUES('الديسمي',29.6465,31.3185,8,15,3,15) ON CONFLICT(name) DO NOTHING;


-- v1.5 Customer Growth
CREATE TABLE IF NOT EXISTS favorites (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 merchant_id UUID NOT NULL REFERENCES merchants(id) ON DELETE CASCADE, created_at TIMESTAMPTZ DEFAULT now(),
 UNIQUE(user_id,merchant_id)
);
CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id,created_at DESC);
CREATE TABLE IF NOT EXISTS coupons (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), code VARCHAR(40) UNIQUE NOT NULL,
 discount_type VARCHAR(20) NOT NULL CHECK(discount_type IN ('PERCENT','FIXED')),
 discount_value NUMERIC(12,2) NOT NULL CHECK(discount_value >= 0),
 max_discount NUMERIC(12,2), min_subtotal NUMERIC(12,2) NOT NULL DEFAULT 0,
 usage_limit INT, usage_count INT NOT NULL DEFAULT 0, per_user_limit INT NOT NULL DEFAULT 1,
 starts_at TIMESTAMPTZ NOT NULL DEFAULT now(), expires_at TIMESTAMPTZ, is_active BOOLEAN NOT NULL DEFAULT true,
 created_at TIMESTAMPTZ DEFAULT now()
);
CREATE TABLE IF NOT EXISTS coupon_redemptions (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), coupon_id UUID NOT NULL REFERENCES coupons(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE, order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 discount_amount NUMERIC(12,2) NOT NULL, created_at TIMESTAMPTZ DEFAULT now(), UNIQUE(coupon_id,user_id,order_id)
);
CREATE INDEX IF NOT EXISTS idx_coupon_redemptions_user ON coupon_redemptions(user_id,coupon_id);
INSERT INTO coupons(code,discount_type,discount_value,max_discount,min_subtotal,usage_limit,per_user_limit,expires_at)
VALUES('JAYEK10','PERCENT',10,50,100,1000,2,now()+interval '90 days') ON CONFLICT(code) DO NOTHING;


-- v2.5 merchant operational inventory
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_quantity integer NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0);
ALTER TABLE products ADD COLUMN IF NOT EXISTS low_stock_threshold integer NOT NULL DEFAULT 5 CHECK (low_stock_threshold >= 0);
CREATE INDEX IF NOT EXISTS idx_products_stock ON products(merchant_id, stock_quantity, is_available);


-- v2.6 reliable stock reservation
ALTER TABLE products ADD COLUMN IF NOT EXISTS stock_reserved integer NOT NULL DEFAULT 0 CHECK (stock_reserved >= 0);
CREATE TABLE IF NOT EXISTS order_stock_reservations(
 id BIGSERIAL PRIMARY KEY, order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
 product_id UUID NOT NULL REFERENCES products(id), quantity INT NOT NULL CHECK(quantity>0),
 status VARCHAR(20) NOT NULL CHECK(status IN ('RESERVED','RELEASED','COMMITTED')),
 created_at TIMESTAMPTZ NOT NULL DEFAULT now(), released_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_order_stock_reservations_order ON order_stock_reservations(order_id,status);
CREATE INDEX IF NOT EXISTS idx_order_stock_reservations_product ON order_stock_reservations(product_id,status);
UPDATE products SET stock_quantity=100 WHERE stock_quantity=0;


-- v2.8 support conversation
CREATE TABLE IF NOT EXISTS support_ticket_messages(
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 ticket_id UUID NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
 author_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
 body TEXT NOT NULL,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_support_messages_ticket_time ON support_ticket_messages(ticket_id,created_at);
