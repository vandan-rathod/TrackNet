from datetime import datetime

from app import db
from sqlalchemy.types import UserDefinedType


class GeographyPoint(UserDefinedType):
    """PostGIS type used by schema.sql for cameras.location."""
    cache_ok = True

    def get_col_spec(self, **kwargs):
        return "GEOGRAPHY(POINT, 4326)"


class Camera(db.Model):
    __tablename__ = "cameras"
    camera_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Text, nullable=False, unique=True)
    latitude = db.Column(db.Float, nullable=False)
    longitude = db.Column(db.Float, nullable=False)
    location = db.Column(GeographyPoint, nullable=False)
    description = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    zone_id = db.Column(db.Integer, db.ForeignKey("zones.zone_id", ondelete="SET NULL"))


class Vehicle(db.Model):
    __tablename__ = "vehicles"
    plate_number = db.Column(db.Text, primary_key=True)
    vehicle_type = db.Column(db.Text)
    first_seen_at = db.Column(db.DateTime)
    last_seen_at = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class PlateDetection(db.Model):
    __tablename__ = "plate_detections"
    detection_id = db.Column(db.Integer, primary_key=True)
    plate_number = db.Column(db.Text, db.ForeignKey("vehicles.plate_number", ondelete="CASCADE"), nullable=False)
    camera_id = db.Column(db.Integer, db.ForeignKey("cameras.camera_id", ondelete="RESTRICT"), nullable=False)
    detected_at = db.Column(db.DateTime, nullable=False)
    confidence = db.Column(db.Numeric(4, 3))
    image_path = db.Column(db.Text)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class TrajectoryHop(db.Model):
    __tablename__ = "trajectory_hops"
    hop_id = db.Column(db.Integer, primary_key=True)
    plate_number = db.Column(db.Text, db.ForeignKey("vehicles.plate_number", ondelete="CASCADE"), nullable=False)
    from_detection_id = db.Column(db.Integer, db.ForeignKey("plate_detections.detection_id", ondelete="CASCADE"), nullable=False)
    to_detection_id = db.Column(db.Integer, db.ForeignKey("plate_detections.detection_id", ondelete="CASCADE"), nullable=False)
    distance_km = db.Column(db.Numeric(10, 3))
    time_diff_seconds = db.Column(db.Integer)
    speed_kmh = db.Column(db.Numeric(10, 2))
    is_suspicious = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class Blacklist(db.Model):
    __tablename__ = "blacklist"
    blacklist_id = db.Column(db.Integer, primary_key=True)
    plate_number = db.Column(db.Text, nullable=False, unique=True)
    reason = db.Column(db.Text)
    severity = db.Column(db.Text)
    is_active = db.Column(db.Boolean, nullable=False, default=True)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class Alert(db.Model):
    __tablename__ = "alerts"
    alert_id = db.Column(db.Integer, primary_key=True)
    plate_number = db.Column(db.Text, nullable=False)
    detection_id = db.Column(db.Integer, db.ForeignKey("plate_detections.detection_id", ondelete="SET NULL"))
    hop_id = db.Column(db.Integer, db.ForeignKey("trajectory_hops.hop_id", ondelete="SET NULL"))
    alert_type = db.Column(db.Text, nullable=False)
    severity = db.Column(db.Text)
    message = db.Column(db.Text)
    is_resolved = db.Column(db.Boolean, nullable=False, default=False)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class Zone(db.Model):
    __tablename__ = "zones"
    zone_id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.Text, nullable=False, unique=True)
    description = db.Column(db.Text)
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class CameraHealth(db.Model):
    __tablename__ = "camera_health"
    health_id = db.Column(db.Integer, primary_key=True)
    camera_id = db.Column(db.Integer, db.ForeignKey("cameras.camera_id", ondelete="CASCADE"), nullable=False)
    status = db.Column(db.Text, nullable=False)
    last_ping_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    notes = db.Column(db.Text)


class SystemSetting(db.Model):
    __tablename__ = "system_settings"
    setting_key = db.Column(db.Text, primary_key=True)
    setting_value = db.Column(db.Text, nullable=False)
    description = db.Column(db.Text)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)


class ProcessingJob(db.Model):
    """API-owned table; the video pipeline may update its status later."""
    __tablename__ = "processing_jobs"
    job_id = db.Column(db.Integer, primary_key=True)
    camera_id = db.Column(db.Integer, db.ForeignKey("cameras.camera_id", ondelete="CASCADE"), nullable=False)
    status = db.Column(db.Text, nullable=False, default="queued")
    created_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)
