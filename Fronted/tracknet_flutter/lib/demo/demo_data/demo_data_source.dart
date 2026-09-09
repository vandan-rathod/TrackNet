import 'dart:convert';

import '../../models/domain.dart';
import 'source_fixture.dart';

/// The source fixture is a reproducible execution of the supplied HTML's seed
/// routines, not a backend DTO. Relative timestamps are rebased on every reset.
class DemoDataSource {
  static GeoPoint point(dynamic p) =>
      GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble());
  static List<GeoPoint> points(dynamic p) =>
      (p as List).map(point).toList(growable: false);
  static DashboardData load(DateTime now) {
    final raw = jsonDecode(sourceFixture) as Map<String, dynamic>;
    final epoch = (raw['epoch'] as num).toInt();
    DateTime time(dynamic t) =>
        now.add(Duration(milliseconds: (t as num).round() - epoch));
    final detections = (raw['detections'] as List).indexed.map((entry) {
      final (i, d) = entry;
      return Detection(
        id: 'DET-$i',
        cameraId: d['cam'],
        timestamp: time(d['t']),
        plate: d['plate'],
        vehicleType: d['type'],
        confidence: (d['conf'] as num).toDouble(),
        speed: (d['speed'] as num).toDouble(),
        status: DetectionStatus.values.firstWhere(
          (s) => s.label == d['status'],
        ),
        context: d['src'],
      );
    }).toList();
    final cameras = (raw['cameras'] as List).map((c) {
      final reads = detections.where((d) => d.cameraId == c['id']).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return Camera(
        id: c['id'],
        name: c['name'],
        zoneId: c['zone'],
        point: point(c['pt']),
        roadId: c['road'],
        status: switch (c['status']) {
          'warn' => CameraStatus.warning,
          'off' => CameraStatus.offline,
          _ => CameraStatus.online,
        },
        vehiclesPerMinute: c['vpm'],
        speed: (c['speed'] as num).toDouble(),
        accuracy: (c['acc'] as num).toDouble(),
        lastPlate: c['lastPlate'] == '—' ? null : c['lastPlate'],
        lastSeen: reads.firstOrNull?.timestamp,
        offSince: c['status'] == 'off'
            ? now.subtract(const Duration(minutes: 4))
            : null,
      );
    }).toList();
    final zones = (raw['zones'] as List)
        .map(
          (z) => Zone(
            id: z['id'],
            name: z['name'],
            center: point(z['c']),
            radius: (z['r'] as num).toDouble(),
            density: (z['dens'] as num).toDouble(),
            base: (z['base'] as num).toDouble(),
          ),
        )
        .toList();
    return DashboardData(
      cameras: cameras,
      detections: detections,
      vehicles: (raw['vehicles'] as List)
          .map(
            (v) => Vehicle(
              plate: v['plate'],
              type: v['type'],
              blacklisted: v['black'],
            ),
          )
          .toList(),
      alerts: (raw['alerts'] as List)
          .map(
            (a) => Alert(
              id: a['id'],
              kind: a['type'],
              priority: Priority.values.byName(
                (a['prio'] as String).toLowerCase(),
              ),
              timestamp: time(a['time']),
              message: a['msg'],
              note: a['note'],
              cameraId: a['cam'],
              plate: a['plate'],
              system: a['system'],
            ),
          )
          .toList(),
      zones: zones,
      roads: (raw['roads'] as List)
          .map(
            (r) => Road(
              r['id'],
              r['name'],
              points(r['pts']),
              r['lms'][(r['lms'] as List).length ~/ 2]['zone'],
            ),
          )
          .toList(),
      shapes: (raw['shapes'] as List)
          .map(
            (s) => MapShape(
              s['kind'],
              points(s['pts']),
              name: s['name'],
              width: (s['weight'] as num? ?? 1).toDouble(),
            ),
          )
          .toList(),
      settings: const SettingsState(
        simulation: true,
        particles: true,
        automaticAlerts: true,
        feeds: true,
      ),
    );
  }

  static const volume = <double>[
    260,
    190,
    140,
    110,
    120,
    320,
    980,
    1650,
    1860,
    1520,
    1280,
    1380,
    1470,
    1310,
    1180,
    1290,
    1510,
    1720,
    1890,
    1560,
    1180,
    760,
    470,
    310,
  ];
  static const speed = <double>[
    44,
    46,
    46,
    47,
    45,
    38,
    30,
    27,
    27,
    29,
    31,
    32,
    32,
    33,
    34,
    33,
    30,
    28,
    26,
    28,
    32,
    36,
    40,
    43,
  ];
  static const flows = [
    OdFlow('city', 'air', 4821),
    OdFlow('city', 'ring', 3912),
    OdFlow('air', 'hw', 2743),
    OdFlow('ring', 'ind', 2194),
    OdFlow('city', 'uni', 1672),
    OdFlow('rly', 'ind', 1288),
    OdFlow('uni', 'city', 1046),
  ];
  static const curatedPlates = {
    'GJ01AB1234',
    'MH12AB4521',
    'GJ05XY8821',
    'RJ14EF1234',
    'DL03CD7821',
  };
  static const bootSteps = [
    (100, 18, 'Connecting camera mesh'),
    (450, 36, 'Synchronizing camera feeds'),
    (850, 56, 'Warming ANPR models'),
    (1300, 74, 'Detecting vehicle identities'),
    (1750, 88, 'Indexing vehicle trajectories'),
    (2150, 95, 'Building tracking graph'),
    (2450, 100, 'Initializing urban intelligence'),
    (2750, 100, 'TrackNet ready'),
  ];
}
