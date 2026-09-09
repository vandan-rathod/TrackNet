# ANPR Project — Full Database Schema

## Files
- `schema.sql` — **core trajectory tables**: cameras, vehicles, plate_detections, trajectory_hops, blacklist, alerts.
- `schema_extra.sql` — **rest-of-project tables**: zones, users, camera_health, audit_logs, notifications, system_settings.
- One `.yaml` per table (all 12) — columns, types, constraints, relations.

## How to apply (run in this order)
```bash
psql -U your_user -d anpr_system -f schema.sql
psql -U your_user -d anpr_system -f schema_extra.sql
```
(Requires `CREATE EXTENSION postgis;` privileges — schema.sql handles this automatically.)

## All 12 tables at a glance
| Table | Purpose |
|---|---|
| cameras | Camera master list + PostGIS location |
| vehicles | One row per unique plate ever seen |
| plate_detections | Raw OCR event log |
| trajectory_hops | Computed distance/time/speed between consecutive detections |
| blacklist | Flagged plates |
| alerts | Blacklist matches + suspicious-speed flags |
| zones | Groups cameras by area (e.g. "SG Highway") |
| users | Dashboard login accounts (admin/operator/viewer) |
| camera_health | Online/offline heartbeat per camera |
| audit_logs | Who did what, when (accountability trail) |
| notifications | Delivery status of an alert per channel (email/SMS/dashboard) |
| system_settings | Key-value config (thresholds, timeouts) instead of hardcoded values |

## Entity relationship overview

```
cameras (1) ────────< plate_detections (many)
                             │  ▲
                             │  │
vehicles (1) ────────────────┘  │
    │                            │
    └──< trajectory_hops (many) ─┘   (from_detection_id, to_detection_id
              │                       both point back into plate_detections)
              │
              ├──< alerts (via hop_id, optional)
              │
plate_detections ──< alerts (via detection_id, optional)

blacklist  ── (checked by value, not FK) ──> alerts
```

## Primary keys
| Table | Primary Key |
|---|---|
| cameras | camera_id |
| vehicles | plate_number |
| plate_detections | detection_id |
| trajectory_hops | hop_id |
| blacklist | blacklist_id |
| alerts | alert_id |

## Foreign keys
| Table.Column | References |
|---|---|
| plate_detections.plate_number | vehicles.plate_number |
| plate_detections.camera_id | cameras.camera_id |
| trajectory_hops.plate_number | vehicles.plate_number |
| trajectory_hops.from_detection_id | plate_detections.detection_id |
| trajectory_hops.to_detection_id | plate_detections.detection_id |
| alerts.detection_id | plate_detections.detection_id (nullable) |
| alerts.hop_id | trajectory_hops.hop_id (nullable) |

`blacklist.plate_number` is deliberately **not** a foreign key — a plate can be blacklisted before it's ever detected, so it's matched by value in application logic instead.

## Typical write order (for your OCR/detection pipeline)
1. `INSERT ... INTO vehicles ON CONFLICT (plate_number) DO NOTHING` — ensure the plate exists as a parent row.
2. `INSERT INTO plate_detections (...)` — log the new sighting.
3. Compute the hop against the vehicle's previous detection → `INSERT INTO trajectory_hops (...)`.
4. If `is_suspicious` or a blacklist match is found → `INSERT INTO alerts (...)`.

## Typical read queries
- Full trajectory for a plate: join `plate_detections` + `cameras`, `WHERE plate_number = ...`, `ORDER BY detected_at`.
- Suspicious hops: `SELECT * FROM trajectory_hops WHERE is_suspicious = TRUE`.
- Active alerts: `SELECT * FROM alerts WHERE is_resolved = FALSE ORDER BY created_at DESC`.
