from datetime import datetime, timedelta
from decimal import Decimal

from flask import Blueprint, jsonify, request
from werkzeug.exceptions import BadRequest, HTTPException, NotFound
from sqlalchemy import and_, desc, func, or_
from sqlalchemy.exc import SQLAlchemyError

from app import cache, db
from app.models import (
    Alert,
    Blacklist,
    Camera,
    CameraHealth,
    PlateDetection,
    ProcessingJob,
    SystemSetting,
    TrajectoryHop,
    Vehicle,
    Zone,
)

api_bp = Blueprint("api", __name__)


def envelope(data=None, error=None, status=200):
    return jsonify({"data": data, "error": error}), status


def _iso(value):
    return value.isoformat() if value else None


def _value(value):
    if isinstance(value, Decimal):
        return float(value)
    return value


def _int_arg(name, default, maximum=None):
    raw = request.args.get(name)
    if raw is None or raw == "":
        return default
    try:
        value = int(raw)
    except (TypeError, ValueError) as exc:
        raise BadRequest(f"{name} must be a positive integer") from exc
    if value <= 0 or (maximum is not None and value > maximum):
        if maximum:
            raise BadRequest(f"{name} must be between 1 and {maximum}")
        raise BadRequest(f"{name} must be a positive integer")
    return value


def _page(query):
    page = _int_arg("page", 1)
    limit = _int_arg("limit", 20, 100)
    total = query.order_by(None).count()
    rows = query.offset((page - 1) * limit).limit(limit).all()
    return {"items": rows, "page": page, "limit": limit, "total": total}


def _result_page(query, serializer):
    page = _int_arg("page", 1)
    limit = _int_arg("limit", 20, 100)
    total = query.order_by(None).count()
    rows = query.offset((page - 1) * limit).limit(limit).all()
    return {"items": [serializer(row) for row in rows], "page": page, "limit": limit, "total": total}


def _camera_or_404(identifier):
    camera = None
    try:
        camera = Camera.query.get(int(identifier))
    except (TypeError, ValueError):
        camera = Camera.query.filter(Camera.name == identifier).first()
    if not camera:
        raise NotFound("Camera not found")
    return camera


def _latest_health(camera_id):
    return CameraHealth.query.filter_by(camera_id=camera_id).order_by(desc(CameraHealth.last_ping_at)).first()


def _camera_status(camera_id):
    health = _latest_health(camera_id)
    if not health:
        return None, None
    status = {"ONLINE": "online", "OFFLINE": "off", "DEGRADED": "warn"}.get(health.status, health.status.lower())
    return status, health.last_ping_at


def _camera_payload(camera):
    now = datetime.utcnow()
    recent_count = db.session.query(func.count(PlateDetection.detection_id)).filter(
        PlateDetection.camera_id == camera.camera_id,
        PlateDetection.detected_at >= now - timedelta(minutes=1),
    ).scalar()
    avg_speed = db.session.query(func.avg(TrajectoryHop.speed_kmh)).join(
        PlateDetection, PlateDetection.detection_id == TrajectoryHop.to_detection_id
    ).filter(PlateDetection.camera_id == camera.camera_id).scalar()
    avg_conf = db.session.query(func.avg(PlateDetection.confidence)).filter(
        PlateDetection.camera_id == camera.camera_id
    ).scalar()
    last = PlateDetection.query.filter_by(camera_id=camera.camera_id).order_by(desc(PlateDetection.detected_at)).first()
    status, ping = _camera_status(camera.camera_id)
    zone = Zone.query.get(camera.zone_id) if camera.zone_id else None
    return {
        "id": camera.name,
        "camera_id": camera.camera_id,
        "pt": [camera.latitude, camera.longitude],
        "name": camera.name,
        "zone": zone.name if zone else None,
        "zone_id": camera.zone_id,
        "status": status,
        "is_active": camera.is_active,
        "description": camera.description,
        "vpm": recent_count,
        "speed": _value(avg_speed),
        "acc": round(float(avg_conf) * 100, 2) if avg_conf is not None else None,
        "lastPlate": last.plate_number if last else None,
        "lastTs": _iso(last.detected_at if last else None),
        "last_ping_at": _iso(ping),
        # The schema has no stream source column. This stays null until the team decides where it lives.
        "stream_url": None,
        "stream_path": None,
    }


def _detection_payload(row):
    detection, camera, vehicle = row
    blacklist = Blacklist.query.filter_by(plate_number=detection.plate_number, is_active=True).first()
    suspicious = TrajectoryHop.query.filter_by(to_detection_id=detection.detection_id, is_suspicious=True).first()
    status = "Blacklisted" if blacklist else ("Flagged" if suspicious else "Normal")
    speed = db.session.query(TrajectoryHop.speed_kmh).filter_by(to_detection_id=detection.detection_id).scalar()
    return {
        "detection_id": detection.detection_id,
        "plate": detection.plate_number,
        "plate_number": detection.plate_number,
        "type": vehicle.vehicle_type if vehicle else None,
        "cam": {"id": camera.name, "camera_id": camera.camera_id, "name": camera.name, "pt": [camera.latitude, camera.longitude]},
        "camera_id": camera.camera_id,
        "loc": camera.name,
        "t": _iso(detection.detected_at),
        "detected_at": _iso(detection.detected_at),
        # Speed is only available when the pipeline has written a trajectory hop.
        "speed": _value(speed),
        "conf": float(detection.confidence) * 100 if detection.confidence is not None else None,
        "confidence": _value(detection.confidence),
        "image_path": detection.image_path,
        "status": status,
        "src": "pipeline",
    }


def _detection_query():
    return db.session.query(PlateDetection, Camera, Vehicle).join(
        Camera, Camera.camera_id == PlateDetection.camera_id
    ).outerjoin(Vehicle, Vehicle.plate_number == PlateDetection.plate_number)


def _job_payload(job):
    return {"job_id": job.job_id, "camera_id": job.camera_id, "status": job.status, "created_at": _iso(job.created_at), "updated_at": _iso(job.updated_at)}


@api_bp.get("/dashboard/kpis")
@cache.cached(timeout=5, query_string=True)
def dashboard_kpis():
    today = datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
    total_cameras = Camera.query.count()
    online = sum(1 for camera in Camera.query.all() if _camera_status(camera.camera_id)[0] == "online")
    detected_today = PlateDetection.query.filter(PlateDetection.detected_at >= today).count()
    plates_today = db.session.query(func.count(func.distinct(PlateDetection.plate_number))).filter(PlateDetection.detected_at >= today).scalar()
    active_alerts = Alert.query.filter_by(is_resolved=False).count()
    high_alerts = Alert.query.filter_by(is_resolved=False, severity="HIGH").count()
    avg_speed = db.session.query(func.avg(TrajectoryHop.speed_kmh)).scalar()
    return envelope({
        "cams": online,
        "total_cams": total_cameras,
        "detect": detected_today,
        "plates": plates_today,
        "alerts": active_alerts,
        "high_priority_alerts": high_alerts,
        "speed": _value(avg_speed),
        "avg_speed": _value(avg_speed),
    })


@api_bp.get("/detections/live")
@cache.cached(timeout=5, query_string=True)
def live_detections():
    limit = _int_arg("limit", 20, 100)
    query = _detection_query().filter(PlateDetection.detected_at >= datetime.utcnow() - timedelta(minutes=5)).order_by(desc(PlateDetection.detected_at))
    rows = query.limit(limit).all()
    return envelope({"items": [_detection_payload(row) for row in rows], "limit": limit, "total": len(rows)})


@api_bp.get("/detections")
@cache.cached(timeout=5, query_string=True)
def detections():
    query = _detection_query()
    search = request.args.get("search", "").strip()
    if search:
        term = f"%{search}%"
        query = query.filter(or_(PlateDetection.plate_number.ilike(term), Camera.name.ilike(term), Vehicle.vehicle_type.ilike(term)))
    return envelope(_result_page(query.order_by(desc(PlateDetection.detected_at)), _detection_payload))


@api_bp.get("/cameras/top")
@cache.cached(timeout=5, query_string=True)
def top_cameras():
    limit = _int_arg("limit", 10, 100)
    cutoff = datetime.utcnow() - timedelta(minutes=1)
    rows = db.session.query(Camera, func.count(PlateDetection.detection_id).label("count")).outerjoin(
        PlateDetection, and_(PlateDetection.camera_id == Camera.camera_id, PlateDetection.detected_at >= cutoff)
    ).group_by(Camera.camera_id).order_by(desc("count")).limit(limit).all()
    return envelope([dict(_camera_payload(camera), detection_count=count) for camera, count in rows])


@api_bp.get("/cameras")
@cache.cached(timeout=45, query_string=True)
def cameras():
    return envelope(_result_page(Camera.query.order_by(Camera.camera_id), _camera_payload))


@api_bp.get("/cameras/<identifier>")
def camera_detail(identifier):
    return envelope(_camera_payload(_camera_or_404(identifier)))


@api_bp.get("/cameras/<identifier>/stream")
def camera_stream(identifier):
    camera = _camera_or_404(identifier)
    return envelope({"camera_id": camera.camera_id, "id": camera.name, "stream_url": None, "stream_path": None})


@api_bp.post("/cameras/<identifier>/process")
def process_camera(identifier):
    camera = _camera_or_404(identifier)
    job = ProcessingJob(camera_id=camera.camera_id, status="queued")
    db.session.add(job)
    db.session.commit()
    return envelope(_job_payload(job), status=201)


@api_bp.get("/jobs/<int:job_id>")
def job_detail(job_id):
    job = ProcessingJob.query.get(job_id)
    if not job:
        raise NotFound("Processing job not found")
    return envelope(_job_payload(job))


@api_bp.get("/cameras/<identifier>/detections")
@cache.cached(timeout=5, query_string=True)
def camera_detections(identifier):
    camera = _camera_or_404(identifier)
    query = _detection_query().filter(PlateDetection.camera_id == camera.camera_id).order_by(desc(PlateDetection.detected_at))
    return envelope(_result_page(query, _detection_payload))


@api_bp.get("/vehicles/search")
@cache.cached(timeout=30, query_string=True)
def vehicle_search():
    query_text = request.args.get("q", "").strip()
    query = Vehicle.query
    if query_text:
        query = query.filter(Vehicle.plate_number.ilike(f"%{query_text}%"))
    return envelope(_result_page(query.order_by(desc(Vehicle.last_seen_at)), lambda vehicle: {
        "plate": vehicle.plate_number, "plate_number": vehicle.plate_number, "type": vehicle.vehicle_type,
        "first_seen_at": _iso(vehicle.first_seen_at), "last_seen_at": _iso(vehicle.last_seen_at),
    }))


@api_bp.get("/vehicles/<string:plate>/trajectory")
@cache.cached(timeout=30, query_string=True)
def vehicle_trajectory(plate):
    vehicle = Vehicle.query.filter_by(plate_number=plate.upper()).first()
    if not vehicle:
        raise NotFound("Vehicle not found")
    rows = _detection_query().filter(PlateDetection.plate_number == vehicle.plate_number).order_by(PlateDetection.detected_at).all()
    hops = TrajectoryHop.query.filter_by(plate_number=vehicle.plate_number).order_by(TrajectoryHop.from_detection_id).all()
    return envelope({
        "plate": vehicle.plate_number,
        "type": vehicle.vehicle_type,
        "first_seen_at": _iso(vehicle.first_seen_at),
        "last_seen_at": _iso(vehicle.last_seen_at),
        "detections": [_detection_payload(row) for row in rows],
        "hops": [{"hop_id": hop.hop_id, "from_detection_id": hop.from_detection_id, "to_detection_id": hop.to_detection_id,
                  "distance_km": _value(hop.distance_km), "time_diff_seconds": hop.time_diff_seconds,
                  "speed_kmh": _value(hop.speed_kmh), "is_suspicious": hop.is_suspicious} for hop in hops],
    })


@api_bp.get("/analytics/volume")
@cache.cached(timeout=45, query_string=True)
def analytics_volume():
    value = request.args.get("range", "24h").lower()
    windows = {"1h": timedelta(hours=1), "24h": timedelta(hours=24), "7d": timedelta(days=7), "30d": timedelta(days=30)}
    if value not in windows:
        raise BadRequest("range must be one of: 1h, 24h, 7d, 30d")
    cutoff = datetime.utcnow() - windows[value]
    bucket = func.date_trunc("hour" if value in {"1h", "24h"} else "day", PlateDetection.detected_at).label("bucket")
    rows = db.session.query(bucket, func.count(PlateDetection.detection_id)).filter(PlateDetection.detected_at >= cutoff).group_by(bucket).order_by(bucket).all()
    return envelope({"range": value, "items": [{"bucket": _iso(bucket_value), "count": count} for bucket_value, count in rows]})


def _zone_payload(zone):
    cameras_count = Camera.query.filter_by(zone_id=zone.zone_id).count()
    detections_count = db.session.query(func.count(PlateDetection.detection_id)).join(
        Camera, Camera.camera_id == PlateDetection.camera_id
    ).filter(Camera.zone_id == zone.zone_id).scalar()
    return {"id": str(zone.zone_id), "zone_id": zone.zone_id, "name": zone.name, "description": zone.description,
            "cameras": cameras_count, "detections": detections_count, "density": None, "radius": None}


@api_bp.get("/analytics/zones")
@cache.cached(timeout=45, query_string=True)
def analytics_zones():
    return envelope(_result_page(Zone.query.order_by(Zone.zone_id), _zone_payload))


@api_bp.get("/analytics/zones/<int:zone_id>")
@cache.cached(timeout=45, query_string=True)
def analytics_zone_detail(zone_id):
    zone = Zone.query.get(zone_id)
    if not zone:
        raise NotFound("Zone not found")
    payload = _zone_payload(zone)
    payload["camera_items"] = [_camera_payload(camera) for camera in Camera.query.filter_by(zone_id=zone_id).all()]
    return envelope(payload)


@api_bp.get("/analytics/od-matrix")
@cache.cached(timeout=45, query_string=True)
def analytics_od_matrix():
    from_camera = db.aliased(Camera)
    to_camera = db.aliased(Camera)
    from_detection = db.aliased(PlateDetection)
    to_detection = db.aliased(PlateDetection)
    rows = db.session.query(from_camera.zone_id, to_camera.zone_id, func.count(TrajectoryHop.hop_id)).join(
        from_detection, from_detection.detection_id == TrajectoryHop.from_detection_id
    ).join(from_camera, from_camera.camera_id == from_detection.camera_id).join(
        to_detection, to_detection.detection_id == TrajectoryHop.to_detection_id
    ).join(to_camera, to_camera.camera_id == to_detection.camera_id).filter(
        from_camera.zone_id.isnot(None), to_camera.zone_id.isnot(None)
    ).group_by(from_camera.zone_id, to_camera.zone_id).all()
    return envelope([{"a": str(source), "b": str(target), "count": count} for source, target, count in rows])


@api_bp.get("/alerts")
def alerts():
    query = Alert.query.order_by(desc(Alert.created_at))
    priority = request.args.get("priority")
    if priority:
        query = query.filter(Alert.severity == priority.upper())
    return envelope(_result_page(query, lambda alert: {
        "id": f"ALT-{alert.alert_id:03d}", "alert_id": alert.alert_id, "type": alert.alert_type.lower(),
        "plate": alert.plate_number, "priority": alert.severity, "prio": alert.severity,
        "msg": alert.message, "note": None, "time": _iso(alert.created_at),
        "status": "resolved" if alert.is_resolved else "open", "system": None,
    }))


@api_bp.get("/alerts/<int:alert_id>")
def alert_detail(alert_id):
    alert = Alert.query.get(alert_id)
    if not alert:
        raise NotFound("Alert not found")
    return envelope({"id": f"ALT-{alert.alert_id:03d}", "alert_id": alert.alert_id, "type": alert.alert_type.lower(),
                     "plate": alert.plate_number, "priority": alert.severity, "prio": alert.severity,
                     "msg": alert.message, "note": None, "time": _iso(alert.created_at),
                     "status": "resolved" if alert.is_resolved else "open", "system": None,
                     "detection_id": alert.detection_id, "hop_id": alert.hop_id})


@api_bp.post("/alerts/<int:alert_id>/resolve")
def resolve_alert(alert_id):
    alert = Alert.query.get(alert_id)
    if not alert:
        raise NotFound("Alert not found")
    alert.is_resolved = True
    db.session.commit()
    return envelope({"alert_id": alert.alert_id, "status": "resolved"})


@api_bp.get("/network/cameras")
@cache.cached(timeout=45, query_string=True)
def network_cameras():
    query = Camera.query.order_by(Camera.camera_id)
    search = request.args.get("search", "").strip()
    if search:
        query = query.filter(or_(Camera.name.ilike(f"%{search}%"), Camera.description.ilike(f"%{search}%")))
    return envelope(_result_page(query, _camera_payload))


@api_bp.get("/network/cameras/<identifier>")
@cache.cached(timeout=45, query_string=True)
def network_camera_detail(identifier):
    return envelope(_camera_payload(_camera_or_404(identifier)))


@api_bp.get("/settings")
def settings():
    rows = SystemSetting.query.order_by(SystemSetting.setting_key).all()
    return envelope({row.setting_key: {"value": row.setting_value, "description": row.description} for row in rows})


@api_bp.post("/settings")
def update_settings():
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise BadRequest("JSON object expected")
    values = body.get("settings", body)
    if not isinstance(values, dict) or not values:
        raise BadRequest("settings must be a non-empty object")
    for key, value in values.items():
        if not isinstance(key, str) or not key.strip() or isinstance(value, (dict, list)):
            raise BadRequest("settings keys must map to scalar values")
        setting = SystemSetting.query.get(key) or SystemSetting(setting_key=key)
        setting.setting_value = str(value)
        setting.updated_at = datetime.utcnow()
        db.session.add(setting)
    db.session.commit()
    return envelope({key: str(value) for key, value in values.items()})


@api_bp.errorhandler(HTTPException)
def api_http_error(error):
    return envelope(error=error.description, status=error.code or 500)


@api_bp.errorhandler(SQLAlchemyError)
def api_db_error(error):
    db.session.rollback()
    return envelope(error="Database error", status=500)


@api_bp.errorhandler(Exception)
def api_unexpected_error(error):
    db.session.rollback()
    return envelope(error="Internal server error", status=500)
