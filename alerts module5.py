"""
SIH26127 - CodeHunters
Module 5: Alert System & Blacklist Logic
Lead: Krishiv | Support: Anwita

STANDALONE PROTOTYPE for Phase 1 (Learn + Prototype).
Works entirely on fake data — no dependency on Module 2 (ANPR/OCR) or
Module 3 (Trajectory Reconstruction). Once those modules are live, swap
the fake data generators for real feeds; everything downstream is unchanged.

Detects two kinds of alerts in real time:
  1. BLACKLIST_MATCH      - a flagged vehicle is spotted by any camera
  2. SPEED_ANOMALY        - a vehicle appears to move faster than physically
                             possible between two cameras (cloned plate / OCR error)
  3. RESTRICTED_ZONE_ENTRY - a vehicle enters a zone it shouldn't be in
                             (optional / nice-to-have, included for completeness)

Run:
    python alerts_module5.py
"""

import math
import random
from datetime import datetime, timedelta


# =========================================================
# 1. CONFIG / TUNABLE KNOBS
# =========================================================

MAX_URBAN_SPEED_KMPH = 80     # ceiling for "plausible" travel speed in city traffic
BUFFER_FACTOR = 1.3           # accounts for non-straight roads, signals, traffic
BLACKLIST_REFRESH_NOTE = "In production, reload this from DB every few minutes " \
                          "- don't query per-detection."


# =========================================================
# 2. FAKE CAMERA NETWORK + DISTANCE MATRIX
# (stand-in for Module 1's camera registry / PostGIS distance query)
# =========================================================

CAMERAS = {
    "CAM_01": (28.6139, 77.2090),
    "CAM_02": (28.6200, 77.2150),
    "CAM_03": (28.6300, 77.2300),
    "CAM_04": (28.6450, 77.2500),
    "CAM_05": (28.6600, 77.2700),
}


def haversine_distance_km(coord1, coord2):
    """Straight-line distance between two lat/long points, in km."""
    lat1, lon1 = coord1
    lat2, lon2 = coord2
    R = 6371
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def build_distance_matrix(cameras):
    matrix = {}
    for cam_a, coord_a in cameras.items():
        for cam_b, coord_b in cameras.items():
            if cam_a != cam_b:
                matrix[(cam_a, cam_b)] = haversine_distance_km(coord_a, coord_b)
    return matrix


DISTANCE_MATRIX = build_distance_matrix(CAMERAS)


# =========================================================
# 3. FAKE RESTRICTED ZONES (optional feature)
# In production: PostGIS POLYGON geometry, checked via ST_Contains.
# Here we just say "CAM_04 sits inside a restricted zone" for the demo.
# =========================================================

RESTRICTED_ZONE_CAMERAS = {
    "CAM_04": "Cantonment Restricted Zone",
}


# =========================================================
# 4. FAKE DATA (stand-in for Module 2's ANPR/OCR output)
# =========================================================

FAKE_BLACKLIST = {
    "DL5CAB9999": {"reason": "Reported stolen", "severity": "HIGH"},
    "UP16XY4321": {"reason": "Pending court notice", "severity": "MEDIUM"},
}


def generate_fake_detection_stream():
    """
    Simulates a live stream of detections arriving from Module 2.
    Includes:
      - normal, unremarkable detections
      - a blacklisted plate appearing
      - a plate teleporting between distant cameras too fast (speed anomaly)
      - a plate entering the restricted zone camera
    """
    base_time = datetime(2026, 9, 9, 10, 0, 0)

    stream = [
        # normal traffic
        {"plate_number": "MH12AB1001", "camera_id": "CAM_01", "timestamp": base_time},
        {"plate_number": "MH12AB1002", "camera_id": "CAM_02", "timestamp": base_time + timedelta(minutes=2)},

        # blacklisted vehicle spotted
        {"plate_number": "DL5CAB9999", "camera_id": "CAM_02", "timestamp": base_time + timedelta(minutes=5)},

        # same vehicle, impossible jump 1 min later to a far camera -> speed anomaly
        {"plate_number": "MH12AB1001", "camera_id": "CAM_05", "timestamp": base_time + timedelta(minutes=6)},

        # second blacklisted vehicle
        {"plate_number": "UP16XY4321", "camera_id": "CAM_03", "timestamp": base_time + timedelta(minutes=8)},

        # vehicle entering restricted zone
        {"plate_number": "MH12AB1003", "camera_id": "CAM_04", "timestamp": base_time + timedelta(minutes=10)},

        # more normal traffic (no alerts expected)
        {"plate_number": "MH12AB1004", "camera_id": "CAM_01", "timestamp": base_time + timedelta(minutes=12)},
        {"plate_number": "MH12AB1004", "camera_id": "CAM_02", "timestamp": base_time + timedelta(minutes=17)},
    ]
    return stream


# =========================================================
# 5. CORE ALERT LOGIC
# =========================================================

def normalize_plate(plate):
    return plate.upper().replace(" ", "").replace("-", "")


def check_blacklist(detection, blacklist):
    """Alert if the detected plate matches a known blacklisted vehicle."""
    plate = normalize_plate(detection["plate_number"])
    if plate in blacklist:
        info = blacklist[plate]
        return {
            "alert_type": "BLACKLIST_MATCH",
            "plate_number": plate,
            "camera_id": detection["camera_id"],
            "timestamp": detection["timestamp"],
            "severity": info["severity"],
            "details": {"reason": info["reason"]},
        }
    return None


def check_restricted_zone(detection, restricted_zone_cameras):
    """Alert if the camera that saw this vehicle sits inside a restricted zone."""
    zone_name = restricted_zone_cameras.get(detection["camera_id"])
    if zone_name:
        return {
            "alert_type": "RESTRICTED_ZONE_ENTRY",
            "plate_number": normalize_plate(detection["plate_number"]),
            "camera_id": detection["camera_id"],
            "timestamp": detection["timestamp"],
            "severity": "HIGH",
            "details": {"zone": zone_name},
        }
    return None


class SpeedAnomalyTracker:
    """
    Keeps the most recent sighting of each plate in memory, and checks every
    NEW sighting against it for a physically-implausible speed. This is the
    "live" version — Module 3's trajectory reconstruction does the same
    check in batch, but Module 5 needs to catch it in real time as
    detections stream in, before a full trajectory even exists.
    """

    def __init__(self, distance_matrix, max_speed=MAX_URBAN_SPEED_KMPH, buffer=BUFFER_FACTOR):
        self.last_seen = {}  # plate -> {camera_id, timestamp}
        self.distance_matrix = distance_matrix
        self.max_speed = max_speed
        self.buffer = buffer

    def check(self, detection):
        plate = normalize_plate(detection["plate_number"])
        prev = self.last_seen.get(plate)
        self.last_seen[plate] = {
            "camera_id": detection["camera_id"],
            "timestamp": detection["timestamp"],
        }

        if prev is None or prev["camera_id"] == detection["camera_id"]:
            return None

        distance_km = self.distance_matrix.get((prev["camera_id"], detection["camera_id"]))
        if distance_km is None:
            return None

        time_hr = (detection["timestamp"] - prev["timestamp"]).total_seconds() / 3600
        if time_hr <= 0:
            return None

        speed = distance_km / time_hr
        max_possible_speed = self.max_speed * self.buffer

        if speed > max_possible_speed:
            return {
                "alert_type": "SPEED_ANOMALY",
                "plate_number": plate,
                "from_camera": prev["camera_id"],
                "to_camera": detection["camera_id"],
                "estimated_speed_kmph": round(speed, 1),
                "timestamp": detection["timestamp"],
                "severity": "MEDIUM",
                "details": {
                    "note": "Speed exceeds plausible urban travel - possible cloned "
                            "plate, OCR misread, or vehicle swap."
                },
            }
        return None


def process_detection_stream(stream, blacklist, restricted_zone_cameras, distance_matrix):
    """
    Runs every check against each detection as it 'arrives'.
    This function is what you'd call once per incoming detection in production
    (e.g. inside a Flask-SocketIO event handler or a queue consumer).
    """
    alerts = []
    speed_tracker = SpeedAnomalyTracker(distance_matrix)

    for detection in stream:
        for check_fn, needs_tracker in (
            (check_blacklist, False),
            (check_restricted_zone, False),
        ):
            if needs_tracker:
                continue
            alert = check_fn(detection, blacklist) if check_fn is check_blacklist \
                else check_fn(detection, restricted_zone_cameras)
            if alert:
                alerts.append(alert)

        speed_alert = speed_tracker.check(detection)
        if speed_alert:
            alerts.append(speed_alert)

    return alerts


# =========================================================
# 6. DELIVERY LAYER (placeholder for Flask-SocketIO / polling)
# =========================================================

def raise_alert(alert):
    """
    In production:
      1. save_alert_to_db(alert)              -- persist for history/audit
      2. socketio.emit('new_alert', alert)    -- push live to Module 4 dashboard
    Here we just print it, since this file runs standalone.
    """
    pretty_print_alert(alert)


# =========================================================
# 7. OUTPUT FORMATTING
# =========================================================

def pretty_print_alert(alert):
    print(f"\n  [{alert['severity']}] {alert['alert_type']}  |  Plate: {alert['plate_number']}")
    for k, v in alert.items():
        if k not in ("alert_type", "plate_number", "severity"):
            print(f"      {k}: {v}")


# =========================================================
# 8. RUN IT — end-to-end demo
# =========================================================

def main():
    print("=" * 70)
    print("SIH26127 — Module 5: Alert System & Blacklist Logic (standalone)")
    print("=" * 70)
    print(f"\nNote: {BLACKLIST_REFRESH_NOTE}")

    stream = generate_fake_detection_stream()
    print(f"\nProcessing {len(stream)} incoming detections...")

    alerts = process_detection_stream(stream, FAKE_BLACKLIST, RESTRICTED_ZONE_CAMERAS, DISTANCE_MATRIX)

    print(f"\n\nRaised {len(alerts)} alert(s):")
    if not alerts:
        print("  (none)")
    for alert in alerts:
        raise_alert(alert)

    print("\n" + "=" * 70)
    print("Done. Swap generate_fake_detection_stream() for a real feed")
    print("(from Module 2, or Module 3's trajectories) when ready.")
    print("=" * 70)


if __name__ == "__main__":
    main()
