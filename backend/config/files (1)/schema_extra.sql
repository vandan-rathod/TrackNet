-- ============================================================
-- ANPR PROJECT — ADDITIONAL SCHEMA (beyond trajectory core)
-- Run AFTER schema.sql
-- ============================================================

-- ============================================================
-- 7. ZONES
-- Groups cameras by area/region (e.g. "SG Highway", "Ring Road")
-- Useful for filtering the map view and for regional reporting
-- ============================================================
CREATE TABLE zones (
    zone_id         SERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    description     TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- Link cameras to zones (nullable — a camera can be unassigned)
ALTER TABLE cameras
    ADD COLUMN zone_id INTEGER REFERENCES zones(zone_id) ON DELETE SET NULL;

CREATE INDEX idx_cameras_zone ON cameras(zone_id);


-- ============================================================
-- 8. USERS
-- Dashboard/admin accounts (operators, admins) who view alerts,
-- search trajectories, manage the blacklist
-- ============================================================
CREATE TABLE users (
    user_id         SERIAL PRIMARY KEY,
    username        TEXT NOT NULL UNIQUE,
    email           TEXT UNIQUE,
    password_hash   TEXT NOT NULL,
    role            TEXT NOT NULL DEFAULT 'operator'
                    CHECK (role IN ('admin', 'operator', 'viewer')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT now(),
    last_login_at   TIMESTAMP
);


-- ============================================================
-- 9. CAMERA_HEALTH
-- Heartbeat/status log — is a camera online, offline, or lagging?
-- Lets the dashboard show "3 cameras offline" style status
-- ============================================================
CREATE TABLE camera_health (
    health_id       SERIAL PRIMARY KEY,
    camera_id       INTEGER NOT NULL REFERENCES cameras(camera_id) ON DELETE CASCADE,
    status          TEXT NOT NULL CHECK (status IN ('ONLINE', 'OFFLINE', 'DEGRADED')),
    last_ping_at    TIMESTAMP NOT NULL DEFAULT now(),
    notes           TEXT
);

CREATE INDEX idx_camera_health_camera ON camera_health(camera_id);
CREATE INDEX idx_camera_health_ping   ON camera_health(last_ping_at);


-- ============================================================
-- 10. AUDIT_LOGS
-- Tracks user actions for accountability
-- (e.g. "operator X added plate Y to blacklist at time Z")
-- ============================================================
CREATE TABLE audit_logs (
    log_id          SERIAL PRIMARY KEY,
    user_id         INTEGER REFERENCES users(user_id) ON DELETE SET NULL,
    action          TEXT NOT NULL,          -- e.g. 'BLACKLIST_ADD', 'ALERT_RESOLVE'
    target_table    TEXT,                   -- e.g. 'blacklist', 'alerts'
    target_id       TEXT,                   -- id of the affected row (kept generic)
    details         TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs_user       ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);


-- ============================================================
-- 11. NOTIFICATIONS
-- Tracks how/whether an alert was actually delivered
-- (SMS, email, dashboard push, etc.) — separate from the alert itself
-- ============================================================
CREATE TABLE notifications (
    notification_id SERIAL PRIMARY KEY,
    alert_id         INTEGER NOT NULL REFERENCES alerts(alert_id) ON DELETE CASCADE,
    channel          TEXT NOT NULL CHECK (channel IN ('EMAIL', 'SMS', 'DASHBOARD', 'WEBSOCKET')),
    recipient        TEXT,                  -- email/phone/user_id as text
    status           TEXT NOT NULL DEFAULT 'PENDING'
                     CHECK (status IN ('PENDING', 'SENT', 'FAILED')),
    sent_at          TIMESTAMP,
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_alert  ON notifications(alert_id);
CREATE INDEX idx_notifications_status ON notifications(status);


-- ============================================================
-- 12. SYSTEM_SETTINGS
-- Simple key-value config table (thresholds, feature flags, etc.)
-- so values like "suspicious speed threshold" aren't hardcoded
-- ============================================================
CREATE TABLE system_settings (
    setting_key     TEXT PRIMARY KEY,
    setting_value   TEXT NOT NULL,
    description     TEXT,
    updated_at      TIMESTAMP NOT NULL DEFAULT now()
);

-- Seed a few defaults
INSERT INTO system_settings (setting_key, setting_value, description) VALUES
('suspicious_speed_kmh_threshold', '150', 'Speed above which a trajectory hop is flagged suspicious'),
('duplicate_detection_window_seconds', '5', 'Ignore repeat detections at the same camera within this window'),
('camera_offline_timeout_seconds', '120', 'Mark a camera OFFLINE if no ping received within this window');


-- ============================================================
-- RELATIONSHIP SUMMARY (additional tables)
-- ============================================================
-- zones     (1) ───< cameras (many)         via zone_id
-- users     (1) ───< audit_logs (many)      via user_id
-- cameras   (1) ───< camera_health (many)   via camera_id
-- alerts    (1) ───< notifications (many)   via alert_id
-- system_settings — standalone key-value store, no relations
-- ============================================================
