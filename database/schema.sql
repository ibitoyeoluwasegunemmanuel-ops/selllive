-- ============================================================
-- SELLLIVE DATABASE SCHEMA
-- Run this in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USERS TABLE
-- Both sellers and buyers are users
-- ============================================================
CREATE TABLE users (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone         VARCHAR(20) UNIQUE NOT NULL,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(150),
  avatar_url    TEXT,
  role          VARCHAR(10) NOT NULL DEFAULT 'buyer' CHECK (role IN ('buyer', 'seller', 'admin')),
  is_verified   BOOLEAN DEFAULT FALSE,
  fcm_token     TEXT,  -- for push notifications
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SELLER PROFILES TABLE
-- Extra info for sellers only
-- ============================================================
CREATE TABLE seller_profiles (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id        UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  business_name  VARCHAR(150) NOT NULL,
  bio            TEXT,
  bank_account   VARCHAR(20),   -- encrypted in production
  bank_code      VARCHAR(10),   -- Flutterwave bank code
  account_name   VARCHAR(150),
  is_verified    BOOLEAN DEFAULT FALSE,
  trust_score    DECIMAL(3,2) DEFAULT 5.00,  -- out of 5
  total_sales    INTEGER DEFAULT 0,
  total_earnings BIGINT DEFAULT 0,  -- in kobo (multiply naira x 100)
  followers_count INTEGER DEFAULT 0,
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- STREAMS TABLE
-- Every live session
-- ============================================================
CREATE TABLE streams (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  seller_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  title         VARCHAR(200) NOT NULL,
  description   TEXT,
  thumbnail_url TEXT,
  status        VARCHAR(10) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'ended')),
  viewer_count  INTEGER DEFAULT 0,
  peak_viewers  INTEGER DEFAULT 0,
  total_orders  INTEGER DEFAULT 0,
  daily_room_url TEXT,  -- Daily.co room URL
  daily_room_name VARCHAR(100),
  started_at    TIMESTAMPTZ,
  ended_at      TIMESTAMPTZ,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- STREAM PRODUCTS TABLE
-- Products pinned during a stream (up to 3 at a time)
-- ============================================================
CREATE TABLE stream_products (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stream_id   UUID REFERENCES streams(id) ON DELETE CASCADE,
  name        VARCHAR(200) NOT NULL,
  description TEXT,
  price       BIGINT NOT NULL,    -- in kobo
  image_url   TEXT,
  stock       INTEGER DEFAULT 999,
  position    INTEGER DEFAULT 1 CHECK (position BETWEEN 1 AND 3),
  is_active   BOOLEAN DEFAULT TRUE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- ORDERS TABLE
-- Created when buyer types BUY in chat
-- ============================================================
CREATE TABLE orders (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_ref      VARCHAR(20) UNIQUE NOT NULL,  -- e.g. SL-20250101-XXXX
  stream_id      UUID REFERENCES streams(id),
  product_id     UUID REFERENCES stream_products(id),
  buyer_id       UUID REFERENCES users(id),
  seller_id      UUID REFERENCES users(id),
  quantity       INTEGER DEFAULT 1,
  unit_price     BIGINT NOT NULL,  -- in kobo
  total_amount   BIGINT NOT NULL,  -- in kobo
  commission     BIGINT NOT NULL,  -- 10% platform fee in kobo
  seller_payout  BIGINT NOT NULL,  -- 90% to seller in kobo
  status         VARCHAR(20) DEFAULT 'pending' CHECK (
    status IN ('pending', 'payment_initiated', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')
  ),
  delivery_address TEXT,
  delivery_phone   VARCHAR(20),
  flw_tx_ref     VARCHAR(100),   -- Flutterwave transaction reference
  flw_tx_id      VARCHAR(100),   -- Flutterwave transaction ID
  payment_url    TEXT,           -- payment link sent to buyer
  paid_at        TIMESTAMPTZ,
  delivered_at   TIMESTAMPTZ,
  created_at     TIMESTAMPTZ DEFAULT NOW(),
  updated_at     TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CHAT MESSAGES TABLE
-- Real-time chat stored for history
-- ============================================================
CREATE TABLE chat_messages (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  stream_id   UUID REFERENCES streams(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id),
  message     TEXT NOT NULL,
  is_buy_cmd  BOOLEAN DEFAULT FALSE,  -- was this a BUY command?
  order_id    UUID REFERENCES orders(id),  -- linked order if BUY
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FOLLOWS TABLE
-- Buyers following sellers
-- ============================================================
CREATE TABLE follows (
  follower_id UUID REFERENCES users(id) ON DELETE CASCADE,
  seller_id   UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (follower_id, seller_id)
);

-- ============================================================
-- REVIEWS TABLE
-- After delivery, buyer rates seller
-- ============================================================
CREATE TABLE reviews (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id    UUID UNIQUE REFERENCES orders(id),
  buyer_id    UUID REFERENCES users(id),
  seller_id   UUID REFERENCES users(id),
  rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
  comment     TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- COMMISSIONS TABLE
-- Platform's 10% cut per order
-- ============================================================
CREATE TABLE commissions (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  order_id   UUID UNIQUE REFERENCES orders(id),
  amount     BIGINT NOT NULL,   -- in kobo
  status     VARCHAR(10) DEFAULT 'pending' CHECK (status IN ('pending', 'settled')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- OTP TABLE
-- Phone verification codes
-- ============================================================
CREATE TABLE otp_codes (
  id         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone      VARCHAR(20) NOT NULL,
  code       VARCHAR(6) NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used       BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- INDEXES (for performance)
-- ============================================================
CREATE INDEX idx_streams_status ON streams(status);
CREATE INDEX idx_streams_seller ON streams(seller_id);
CREATE INDEX idx_orders_buyer ON orders(buyer_id);
CREATE INDEX idx_orders_seller ON orders(seller_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_chat_stream ON chat_messages(stream_id, created_at);
CREATE INDEX idx_follows_seller ON follows(seller_id);

-- ============================================================
-- FUNCTIONS & TRIGGERS
-- ============================================================

-- Auto-update seller trust score when review added
CREATE OR REPLACE FUNCTION update_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE seller_profiles
  SET trust_score = (
    SELECT AVG(rating) FROM reviews WHERE seller_id = NEW.seller_id
  )
  WHERE user_id = NEW.seller_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_trust_score
AFTER INSERT ON reviews
FOR EACH ROW EXECUTE FUNCTION update_trust_score();

-- Auto-update followers_count
CREATE OR REPLACE FUNCTION update_followers_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE seller_profiles SET followers_count = followers_count + 1
    WHERE user_id = NEW.seller_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE seller_profiles SET followers_count = followers_count - 1
    WHERE user_id = OLD.seller_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_followers_count
AFTER INSERT OR DELETE ON follows
FOR EACH ROW EXECUTE FUNCTION update_followers_count();

-- Generate order reference
CREATE OR REPLACE FUNCTION generate_order_ref()
RETURNS TRIGGER AS $$
BEGIN
  NEW.order_ref := 'SL-' || TO_CHAR(NOW(), 'YYYYMMDD') || '-' || UPPER(SUBSTRING(NEW.id::text, 1, 6));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_order_ref
BEFORE INSERT ON orders
FOR EACH ROW EXECUTE FUNCTION generate_order_ref();

-- ============================================================
-- SUPABASE ROW LEVEL SECURITY (RLS)
-- ============================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE streams ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Users can read their own data
CREATE POLICY "users_read_own" ON users FOR SELECT USING (auth.uid()::text = id::text);
CREATE POLICY "users_update_own" ON users FOR UPDATE USING (auth.uid()::text = id::text);

-- Streams are public to read
CREATE POLICY "streams_public_read" ON streams FOR SELECT USING (true);
CREATE POLICY "streams_seller_write" ON streams FOR INSERT WITH CHECK (auth.uid()::text = seller_id::text);

-- Chat is public within a stream
CREATE POLICY "chat_public_read" ON chat_messages FOR SELECT USING (true);
CREATE POLICY "chat_auth_insert" ON chat_messages FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- Orders: buyer and seller can see their own
CREATE POLICY "orders_buyer_read" ON orders FOR SELECT USING (auth.uid()::text = buyer_id::text);
CREATE POLICY "orders_seller_read" ON orders FOR SELECT USING (auth.uid()::text = seller_id::text);
