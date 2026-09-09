-- ============================================================
-- ANPR TRAJECTORY SYSTEM — DATABASE SCHEMA
-- ============================================================
-- Run this once against your PostgreSQL database.
-- Requires PostGIS extension.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- 1. CAMERAS
-- Master list of all ANPR camera locations
-- ============================================================
CREATE TABLE cameras (
    camera_id       SERIAL PRIMARY KEY,
    name            TEXT NOT NULL UNIQUE,
    latitude        DOUBLE PRECISION NOT NULL,
    longitude       DOUBLE PRECISION NOT NULL,
    location        GEOGRAPHY(POINT, 4326) NOT NULL,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_cameras_location ON cameras USING GIST (location);


-- ============================================================
-- 2. VEHICLES
-- One row per unique plate number ever seen or registered
-- (Acts as the parent/reference table for detections, blacklist, alerts)
-- ============================================================
CREATE TABLE vehicles (
    plate_number    TEXT PRIMARY KEY,
    vehicle_type    TEXT,               -- e.g. 'car', 'bike', 'truck' (optional)
    first_seen_at   TIMESTAMP,
    last_seen_at    TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);


-- ============================================================
-- 3. PLATE_DETECTIONS
-- Raw event log — every time a camera reads a plate
-- ============================================================
CREATE TABLE plate_detections (
    detection_id    SERIAL PRIMARY KEY,
    plate_number    TEXT NOT NULL REFERENCES vehicles(plate_number) ON DELETE CASCADE,
    camera_id       INTEGER NOT NULL REFERENCES cameras(camera_id) ON DELETE RESTRICT,
    detected_at     TIMESTAMP NOT NULL,
    confidence      NUMERIC(4,3) CHECK (confidence >= 0 AND confidence <= 1),
    image_path      TEXT,               -- optional: path to cropped plate image
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_detections_plate       ON plate_detections(plate_number);
CREATE INDEX idx_detections_camera      ON plate_detections(camera_id);
CREATE INDEX idx_detections_detected_at ON plate_detections(detected_at);
-- composite index: speeds up "get trajectory for a plate, ordered by time"
CREATE INDEX idx_detections_plate_time  ON plate_detections(plate_number, detected_at);


-- ============================================================
-- 4. TRAJECTORY_HOPS
-- One row per consecutive pair of detections for a vehicle
-- (precomputed distance/time/speed between two camera sightings)
-- ============================================================
CREATE TABLE trajectory_hops (
    hop_id              SERIAL PRIMARY KEY,
    plate_number        TEXT NOT NULL REFERENCES vehicles(plate_number) ON DELETE CASCADE,
    from_detection_id   INTEGER NOT NULL REFERENCES plate_detections(detection_id) ON DELETE CASCADE,
    to_detection_id     INTEGER NOT NULL REFERENCES plate_detections(detection_id) ON DELETE CASCADE,
    distance_km         NUMERIC(10,3),
    time_diff_seconds   INTEGER,
    speed_kmh           NUMERIC(10,2),
    is_suspicious       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT chk_hop_order CHECK (from_detection_id <> to_detection_id)
);

CREATE INDEX idx_hops_plate       ON trajectory_hops(plate_number);
CREATE INDEX idx_hops_suspicious  ON trajectory_hops(is_suspicious);


-- ============================================================
-- 5. BLACKLIST
-- Plates flagged for monitoring (may be added before any detection exists,
-- so this intentionally does NOT force a foreign key to vehicles)
-- ============================================================
CREATE TABLE blacklist (
    blacklist_id    SERIAL PRIMARY KEY,
    plate_number    TEXT NOT NULL UNIQUE,
    reason          TEXT,
    severity        TEXT CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_blacklist_plate ON blacklist(plate_number);


-- ============================================================
-- 6. ALERTS
-- Generated when a detection matches the blacklist OR a trajectory
-- hop looks physically implausible (too fast between two cameras)
-- ============================================================
CREATE TABLE alerts (
    alert_id        SERIAL PRIMARY KEY,
    plate_number    TEXT NOT NULL,
    detection_id    INTEGER REFERENCES plate_detections(detection_id) ON DELETE SET NULL,
    hop_id          INTEGER REFERENCES trajectory_hops(hop_id) ON DELETE SET NULL,
    alert_type      TEXT NOT NULL CHECK (alert_type IN ('BLACKLIST', 'SUSPICIOUS_SPEED', 'OTHER')),
    severity        TEXT CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    message         TEXT,
    is_resolved     BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX idx_alerts_plate      ON alerts(plate_number);
CREATE INDEX idx_alerts_created_at ON alerts(created_at);
CREATE INDEX idx_alerts_unresolved ON alerts(is_resolved) WHERE is_resolved = FALSE;


-- ============================================================
-- RELATIONSHIP SUMMARY
-- ============================================================
-- vehicles (1) ───< plate_detections (many)      via plate_number
-- cameras  (1) ───< plate_detections (many)      via camera_id
-- vehicles (1) ───< trajectory_hops (many)       via plate_number
-- plate_detections (1) ───< trajectory_hops.from_detection_id
-- plate_detections (1) ───< trajectory_hops.to_detection_id
-- plate_detections (1) ───< alerts (many, optional) via detection_id
-- trajectory_hops   (1) ───< alerts (many, optional) via hop_id
-- blacklist.plate_number is checked against vehicles.plate_number in app logic
--   (no hard FK, since a plate can be blacklisted before ever being detected)
-- ============================================================
