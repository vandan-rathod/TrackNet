"""Seed a small, repeatable dataset for exercising the API locally.

This only writes the existing schema tables plus the API-owned processing_jobs
table. It does not touch the video or ANPR pipeline.
"""
from datetime import datetime, timedelta

from sqlalchemy import text

from app import create_app, db
from app.models import ProcessingJob


ZONES = [
    ("City Center", "Central traffic district"),
    ("Airport Road", "Airport corridor"),
    ("Ring Road", "Outer ring corridor"),
]

CAMERAS = [
    ("CAM-012", 23.0262, 72.5728, "City Center", "City Center junction"),
    ("CAM-027", 23.0400, 72.5900, "Ring Road", "Ring Road junction"),
    ("CAM-041", 23.0520, 72.5985, "Airport Road", "Airport Road approach"),
]

VEHICLES = [
    ("GJ01AB1234", "Car"),
    ("MH12AB4521", "SUV"),
    ("RJ14EF1234", "Truck"),
]


def zone_id(name):
    return db.session.execute(text("SELECT zone_id FROM zones WHERE name = :name"), {"name": name}).scalar_one()


def camera_id(name):
    return db.session.execute(text("SELECT camera_id FROM cameras WHERE name = :name"), {"name": name}).scalar_one()


def seed():
    for name, description in ZONES:
        db.session.execute(text(
            "INSERT INTO zones (name, description) VALUES (:name, :description) "
            "ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description"
        ), {"name": name, "description": description})
    db.session.flush()

    for name, lat, lon, zone, description in CAMERAS:
        db.session.execute(text(
            "INSERT INTO cameras (name, latitude, longitude, location, description, is_active, zone_id) "
            "VALUES (:name, :lat, :lon, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, "
            ":description, TRUE, :zone_id) "
            "ON CONFLICT (name) DO UPDATE SET latitude = EXCLUDED.latitude, longitude = EXCLUDED.longitude, "
            "description = EXCLUDED.description, zone_id = EXCLUDED.zone_id"
        ), {"name": name, "lat": lat, "lon": lon, "description": description, "zone_id": zone_id(zone)})

    for plate, vehicle_type in VEHICLES:
        db.session.execute(text(
            "INSERT INTO vehicles (plate_number, vehicle_type, first_seen_at, last_seen_at) "
            "VALUES (:plate, :vehicle_type, :first_seen, :last_seen) "
            "ON CONFLICT (plate_number) DO UPDATE SET vehicle_type = EXCLUDED.vehicle_type, "
            "last_seen_at = EXCLUDED.last_seen_at"
        ), {"plate": plate, "vehicle_type": vehicle_type, "first_seen": datetime.utcnow() - timedelta(hours=2), "last_seen": datetime.utcnow()})

    db.session.execute(text(
        "INSERT INTO blacklist (plate_number, reason, severity, is_active) VALUES "
        "('MH12AB4521', 'Seeded test watchlist entry', 'HIGH', TRUE) "
        "ON CONFLICT (plate_number) DO UPDATE SET is_active = TRUE"
    ))

    now = datetime.utcnow()
    detections = []
    for index, (plate, cam, minutes_ago, confidence) in enumerate([
        ("GJ01AB1234", "CAM-012", 20, 0.978),
        ("GJ01AB1234", "CAM-027", 12, 0.965),
        ("GJ01AB1234", "CAM-041", 4, 0.991),
        ("MH12AB4521", "CAM-027", 9, 0.942),
        ("RJ14EF1234", "CAM-041", 2, 0.956),
    ]):
        detected_at = now - timedelta(minutes=minutes_ago)
        existing = db.session.execute(text(
            "SELECT detection_id FROM plate_detections WHERE plate_number = :plate "
            "AND camera_id = :camera_id AND detected_at = :detected_at"
        ), {"plate": plate, "camera_id": camera_id(cam), "detected_at": detected_at}).scalar()
        if existing:
            detections.append(existing)
            continue
        detection_id = db.session.execute(text(
            "INSERT INTO plate_detections (plate_number, camera_id, detected_at, confidence) "
            "VALUES (:plate, :camera_id, :detected_at, :confidence) RETURNING detection_id"
        ), {"plate": plate, "camera_id": camera_id(cam), "detected_at": detected_at, "confidence": confidence}).scalar_one()
        detections.append(detection_id)

    db.session.execute(text(
        "UPDATE vehicles SET first_seen_at = (SELECT min(detected_at) FROM plate_detections WHERE plate_number = vehicles.plate_number), "
        "last_seen_at = (SELECT max(detected_at) FROM plate_detections WHERE plate_number = vehicles.plate_number)"
    ))
    if len(detections) >= 2:
        db.session.execute(text(
            "INSERT INTO trajectory_hops (plate_number, from_detection_id, to_detection_id, distance_km, "
            "time_diff_seconds, speed_kmh, is_suspicious) VALUES "
            "('GJ01AB1234', :from_id, :to_id, 3.2, 480, 24.0, FALSE) "
            "ON CONFLICT DO NOTHING"
        ), {"from_id": detections[0], "to_id": detections[1]})

    for cam in CAMERAS:
        db.session.execute(text(
            "INSERT INTO camera_health (camera_id, status, last_ping_at, notes) VALUES "
            "(:camera_id, 'ONLINE', :last_ping, 'Seeded health record')"
        ), {"camera_id": camera_id(cam[0]), "last_ping": now})

    db.session.execute(text(
        "INSERT INTO alerts (plate_number, detection_id, alert_type, severity, message, is_resolved) "
        "VALUES ('MH12AB4521', :detection_id, 'BLACKLIST', 'HIGH', 'Seeded blacklist match', FALSE)"
    ), {"detection_id": detections[3]})

    for key, value, description in [
        ("suspicious_speed_kmh_threshold", "150", "Speed threshold"),
        ("duplicate_detection_window_seconds", "5", "Duplicate detection window"),
        ("camera_offline_timeout_seconds", "120", "Camera offline timeout"),
    ]:
        db.session.execute(text(
            "INSERT INTO system_settings (setting_key, setting_value, description) VALUES "
            "(:key, :value, :description) ON CONFLICT (setting_key) DO NOTHING"
        ), {"key": key, "value": value, "description": description})

    db.session.commit()
    print("Seed data inserted or refreshed.")


if __name__ == "__main__":
    application = create_app()
    with application.app_context():
        ProcessingJob.__table__.create(bind=db.engine, checkfirst=True)
        seed()
