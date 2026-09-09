# TrackNet API

The REST API is registered under `/api/v1/` and uses the existing PostgreSQL
schema as its source of truth. SQLAlchemy models preserve names such as
`plate_detections` and `cameras.camera_id`; the frontend-shaped aliases are
created only in response serializers.

## Run

Install `backend/requirements.txt`, configure `backend/.env` with `DB_HOST`,
`DB_PORT`, `DB_NAME`, `DB_USER`, and `DB_PASSWORD`, then run:

```bash
cd backend
python run.py
```

The optional `DATABASE_URL` environment variable takes precedence over the
individual database settings. Flask-Caching uses `SimpleCache` by default;
set `CACHE_TYPE` to a Redis-compatible Flask-Caching backend when the Redis
adapter is added.

## Seed data

After PostgreSQL/PostGIS is available, run:

```bash
python -m scripts.seed_demo
```

The seed script populates existing zones, cameras, vehicles, detections,
trajectory hops, alerts, health records, blacklist data, and settings. It
also creates the API-owned `processing_jobs` table if it is missing. It does
not modify `schema.sql`, `schema_extra.sql`, or any video-processing code.

## Response and caching rules

Every API response has `{ "data": ..., "error": null }`, or the same shape
with `data: null` for errors. Paginated responses put `items`, `page`,
`limit`, and `total` inside `data`. `page` and `limit` are positive integers;
`limit` is capped at 100.

Dashboard KPIs, live detections, detection lists, and top cameras use a short
5-second cache. Cameras, vehicle search/trajectory, analytics, and network
queries use a 30-45 second cache. Job status is deliberately not cached so a
pipeline worker's state is visible immediately. Camera detail, stream lookup,
alert detail, alert resolution, and settings are also uncached because they
are operational or mutation-adjacent reads.

Fields absent from the fixed schema are explicit: camera `vpm`, accuracy,
last-read fields, and camera speed are derived where possible; detection
speed is null unless a matching trajectory hop exists; zone `density` and
`radius`, camera stream URL/path, alert `note`/`system`, and camera-only alert
context are returned as null rather than fabricated.

## Outstanding team decisions

1. Camera stream source: the current `cameras` schema has no stored URL/path
   column, so `/cameras/<id>/stream` returns null fields.
2. Camera-only alerts: the current `alerts` schema requires `plate_number`
   and has no `camera_id`, so offline/warning alerts without a plate need a
   schema decision before they can be persisted faithfully.
