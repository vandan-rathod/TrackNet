import 'dart:async';
import 'dart:math';

import '../../models/domain.dart';
import '../../models/plate.dart';
import '../../repositories/dashboard_repository.dart';
import '../demo_data/demo_data_source.dart';

class MockDashboardRepository extends DashboardRepository {
  MockDashboardRepository({
    Random? random,
    DateTime Function()? clock,
    this.enableTimers = true,
  }) : _random = random ?? Random(),
       _clock = clock ?? DateTime.now {
    _reset();
  }
  final Random _random;
  final DateTime Function() _clock;
  final bool enableTimers;
  final _changes = StreamController<RepositoryState>.broadcast();
  final _reconnections = StreamController<ReconnectionState>.broadcast();
  final List<Timer> _timers = [];
  bool _disposed = false, _reconnecting = false;
  int _generation = 0,
      _tick = 0,
      _detected = 18429,
      _recognized = 17862,
      _sequence = 1000,
      _raised = 7;
  String _view = 'dashboard';
  late DateTime _started;
  late DashboardData _base;
  late List<Camera> _cameras;
  late List<Detection> _detections;
  late List<Alert> _alerts;
  late List<Zone> _zones;
  late List<double> _volume, _speed;
  late SettingsState _settings;
  late DashboardMetrics _metrics;
  late AnalyticsSnapshot _analytics;
  late List<CameraFeed> _feeds;
  late List<TrafficParticle> _particles;
  late RepositoryState _state;
  double _rand(double a, double b) => a + _random.nextDouble() * (b - a);
  int _int(int a, int b) => a + _random.nextInt(b - a + 1);
  T _pick<T>(List<T> values) => values[_random.nextInt(values.length)];
  bool _chance(double p) => _random.nextDouble() < p;
  @override
  RepositoryState get current => _state;
  @override
  Stream<RepositoryState> get changes => _changes.stream;
  @override
  Stream<ReconnectionState> get reconnections => _reconnections.stream;
  @override
  List<Detection> get detections => List.unmodifiable(_detections);
  @override
  List<Road> get roads => _base.roads;
  void _reset() {
    _generation++;
    _reconnecting = false;
    _started = _clock();
    _base = DemoDataSource.load(_started);
    _cameras = List.of(_base.cameras);
    _detections = List.of(_base.detections);
    _alerts = List.of(_base.alerts);
    _zones = List.of(_base.zones);
    _settings = _base.settings;
    _volume = List.of(DemoDataSource.volume);
    _speed = List.of(DemoDataSource.speed);
    _tick = 0;
    _detected = 18429;
    _recognized = 17862;
    _sequence = 1000;
    _raised = 7;
    _metrics = const DashboardMetrics(248, 256, 18429, 17862, 7, 34);
    _refreshAnalytics();
    _chooseFeeds();
    final eligible = roads.where((r) => pathLength(r.points) > 1.2).toList();
    _particles = List.generate(52, (_) {
      final r = _pick(eligible);
      final density = _zones.firstWhere((z) => z.id == r.zoneId).density;
      return TrafficParticle(
        r.id,
        _random.nextDouble(),
        _chance(.5) ? 1 : -1,
        (1 - density) * 40 + 9,
      );
    });
    _publish();
  }

  void _publish() {
    if (_disposed) return;
    _state = RepositoryState(
      Availability.ready,
      data: DashboardData(
        cameras: List.unmodifiable(_cameras),
        detections: List.unmodifiable(_detections),
        vehicles: _base.vehicles,
        alerts: List.unmodifiable(_alerts),
        zones: List.unmodifiable(_zones),
        roads: roads,
        shapes: _base.shapes,
        particles: _particles,
        feeds: _feeds,
        metrics: _metrics,
        analytics: _analytics,
        settings: _settings,
        platform: PlatformStatus(
          engine: 'TrackNet v1.0',
          build: 'SIH26127 · demo',
          startedAt: _started,
          tick: _tick,
          camerasTracked: _cameras.length,
          mapStatus: 'simulated vector map',
          routesIndexed: DemoDataSource.curatedPlates.length,
          alertsRaised: _raised,
          operatorName: 'A. Sharma',
          operatorDetail: 'Command Center CC-01 · shift 07:00 – 15:00',
        ),
      ),
    );
    _changes.add(_state);
  }

  @override
  Future<void> start() async {
    if (_timers.isNotEmpty || !enableTimers) return;
    _timers.add(
      Timer.periodic(
        const Duration(milliseconds: 2600),
        (_) => tickSimulation(),
      ),
    );
    _timers.add(
      Timer.periodic(
        const Duration(milliseconds: 5200),
        (_) => refreshMetrics(),
      ),
    );
    _timers.add(Timer.periodic(const Duration(seconds: 8), (_) => _publish()));
  }

  /// Source tick: 92% chance of 2–6 reads, drift, then 4.5% alert gate.
  void tickSimulation() {
    if (_disposed || !_settings.simulation) return;
    _tick++;
    final now = _clock();
    final n = _chance(.92) ? _int(2, 6) : 0;
    final vehicles = _base.vehicles
        .where((v) => !DemoDataSource.curatedPlates.contains(v.plate))
        .toList();
    for (var i = 0; i < n; i++) {
      final online = _cameras
          .where((c) => c.status == CameraStatus.online)
          .toList();
      if (online.isEmpty) break;
      final c = _pick(online), v = _pick(vehicles);
      final d = Detection(
        id: 'DET-${_sequence++}',
        cameraId: c.id,
        timestamp: now.subtract(Duration(milliseconds: _rand(0, 9000).round())),
        plate: v.plate,
        vehicleType: v.type,
        confidence: _rand(87, 99.4),
        speed: _int(12, 66).toDouble(),
        status: v.blacklisted
            ? (_chance(.6)
                  ? DetectionStatus.blacklisted
                  : DetectionStatus.flagged)
            : (_chance(.06) ? DetectionStatus.flagged : DetectionStatus.normal),
        context: 'live',
      );
      _detections.insert(0, d);
      if (_detections.length > 760) _detections.removeLast();
      _cameras[_cameras.indexOf(c)] = c.copyWith(
        lastPlate: d.plate,
        lastSeen: d.timestamp,
      );
    }
    _detected += n;
    _recognized += (n * .94).round();
    _zones = _zones
        .map(
          (z) =>
              z.withDensity((z.density + _rand(-.014, .014)).clamp(.12, .96)),
        )
        .toList();
    if (_chance(.05)) {
      final warning = _cameras
          .where((c) => c.status == CameraStatus.warning)
          .toList();
      if (warning.isNotEmpty && _chance(.5)) {
        final c = _pick(warning);
        _cameras[_cameras.indexOf(c)] = c.copyWith(status: CameraStatus.online);
      }
    }
    if (_settings.automaticAlerts &&
        _chance(.045) &&
        now.difference(_alerts.first.timestamp).inMilliseconds > 45000) {
      _newAlert(now);
    }
    _publish();
  }

  void _newAlert(DateTime now) {
    final kind = _pick(['blacklist', 'suspicious', 'offline']);
    final online = _cameras
        .where((c) => c.status == CameraStatus.online)
        .toList();
    if (online.isEmpty) return;
    final c = _pick(online);
    Vehicle? v;
    if (kind == 'offline') {
      _cameras[_cameras.indexOf(c)] = c.copyWith(
        status: CameraStatus.offline,
        offSince: now,
      );
    } else {
      v = _pick(
        _base.vehicles
            .where((v) => kind == 'blacklist' ? v.blacklisted : !v.blacklisted)
            .toList(),
      );
    }
    _raised++;
    _alerts.insert(
      0,
      Alert(
        id: 'ALT-${_raised.toString().padLeft(3, '0')}',
        kind: kind,
        priority: kind == 'blacklist' ? Priority.high : Priority.medium,
        timestamp: now,
        message: switch (kind) {
          'offline' => 'Connection lost',
          'blacklist' => 'Flagged by national vehicle registry',
          _ => 'Unexpected movement pattern',
        },
        note: switch (kind) {
          'offline' => 'Heartbeat timeout — camera unreachable for 60 seconds.',
          'blacklist' => 'Match at ${c.name} — command desk notified.',
          _ => 'Direction reversal detected between sectors.',
        },
        cameraId: c.id,
        plate: v?.plate,
        system: kind != 'suspicious',
      ),
    );
  }

  void refreshMetrics() {
    if (_disposed) return;
    _metrics = DashboardMetrics(
      _cameras.where((c) => c.status == CameraStatus.online).length,
      _cameras.length,
      _settings.simulation ? _detected : _metrics.detected,
      _settings.simulation ? _recognized : _metrics.recognized,
      _alerts.where((a) => !a.resolved).length,
      (52 -
              _zones.fold<double>(0, (n, z) => n + z.density) /
                  _zones.length *
                  30)
          .roundToDouble(),
    );
    if (_settings.simulation && _view == 'analytics') {
      final hour = _clock().hour;
      _volume[hour] += _int(0, 9);
      _speed[hour] = (_speed[hour] + _rand(-.4, .4)).clamp(22, 48);
      _refreshAnalytics();
    }
    _publish();
  }

  void _refreshAnalytics() {
    final counts = <String, int>{};
    for (final t in ['Car', 'SUV', 'Truck', 'Bus', 'Auto', 'Bike']) {
      counts[t] = _detections.where((d) => d.vehicleType == t).length;
    }
    _analytics = AnalyticsSnapshot(
      volume: List.unmodifiable(_volume),
      speed: List.unmodifiable(_speed),
      typeCounts: Map.unmodifiable(counts),
      cameraDensity: Map.unmodifiable({
        for (final z in _zones)
          z.id: _cameras
              .where((c) => c.point.distanceTo(z.center) < z.radius * 1.35)
              .length,
      }),
      flows: DemoDataSource.flows,
    );
  }

  CameraFeed _feed(Camera c) => CameraFeed(
    c.id,
    List.generate(3, (_) {
      final truck = _chance(.16), bus = _chance(.1);
      return FeedCar(
        _random.nextDouble(),
        _chance(.5) ? 0 : 1,
        _chance(.5) ? 1 : -1,
        _rand(16, 42) * (c.status == CameraStatus.warning ? 0.6 : 1),
        truck
            ? 46
            : bus
            ? 40
            : 26,
        truck ? 13 : 11,
        _pick([
          0xff8fb7d9,
          0xffd9a37c,
          0xffb9d98f,
          0xffd98fb4,
          0xffd9d98f,
          0xff8fd9c4,
        ]),
        truck,
      );
    }),
    available: true,
    message: 'Simulated CCTV',
  );
  void _chooseFeeds() {
    final online =
        _cameras
            .where((c) => c.status == CameraStatus.online && c.id != 'CAM-027')
            .toList()
          ..shuffle(_random);
    final warning = _cameras
        .where((c) => c.status == CameraStatus.warning)
        .toList();
    final picked = [
      _cameras.firstWhere((c) => c.id == 'CAM-027'),
      ...online.take(9),
      if (warning.isNotEmpty) _pick(warning),
      _cameras.firstWhere((c) => c.id == 'CAM-109'),
    ];
    if (picked.length < 12) picked.insert(picked.length - 1, online[9]);
    _feeds = picked.map(_feed).toList();
  }

  @override
  Future<void> cycleFeeds() async {
    _chooseFeeds();
    _publish();
  }

  @override
  Future<CameraFeed> cameraFeed(String id) async =>
      _feeds.where((f) => f.cameraId == id).firstOrNull ??
      _feed(_cameras.firstWhere((c) => c.id == id));
  @override
  Future<void> reconnectCamera(String id) async {
    final c = _cameras.firstWhere((c) => c.id == id);
    if (c.status != CameraStatus.offline) return;
    _cameras[_cameras.indexOf(c)] = c.copyWith(
      status: CameraStatus.online,
      vehiclesPerMinute: _int(20, 80),
      speed: _int(18, 56).toDouble(),
      accuracy: _rand(94, 98.4),
    );
    _alerts = _alerts
        .map(
          (a) => !a.resolved && a.kind == 'offline' && a.cameraId == id
              ? a.resolve()
              : a,
        )
        .toList();
    refreshMetrics();
  }

  @override
  Future<void> reconnectAll() async {
    if (_reconnecting) return;
    final offline = _cameras
        .where((c) => c.status == CameraStatus.offline)
        .toList();
    final done = <String>[];
    final generation = _generation;
    _reconnecting = true;
    void emit(String m) {
      if (!_disposed) {
        _reconnections.add(
          ReconnectionState(
            running: _reconnecting,
            total: offline.length,
            completed: List.of(done),
            message: m,
          ),
        );
      }
    }

    emit('Reconnecting cameras');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in offline) {
      if (_disposed || generation != _generation) return;
      await reconnectCamera(c.id);
      done.add(c.id);
      emit('Connected ${c.id}');
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
    if (_disposed || generation != _generation) return;
    _reconnecting = false;
    emit(offline.isEmpty ? 'No offline cameras' : 'All cameras reconnected');
  }

  @override
  Future<void> resolveAlert(String id) async {
    _alerts = _alerts.map((a) => a.id == id ? a.resolve() : a).toList();
    refreshMetrics();
  }

  @override
  Future<void> resolveAll() async {
    _alerts = _alerts.map((a) => a.resolve()).toList();
    refreshMetrics();
  }

  @override
  Future<void> updateSettings(SettingsState settings) async {
    _settings = settings;
    _publish();
  }

  @override
  Future<void> resetDemo() async {
    _reset();
    _reconnections.add(const ReconnectionState());
  }

  @override
  Future<void> poll() async => _publish();
  @override
  void setVisibleView(String view) {
    _view = view;
    if (view == 'analytics') {
      _refreshAnalytics();
    }
  }

  @override
  Future<Journey?> findJourney(
    String plate, {
    bool reducedMotion = false,
  }) async {
    final p = PlateRecognition.normalize(plate);
    await Future<void>.delayed(
      Duration(milliseconds: reducedMotion ? 80 : 820),
    );
    final v = _base.vehicles.where((v) => v.plate == p).firstOrNull;
    if (v == null) return null;
    final events = _detections.where((d) => d.plate == p).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (events.isEmpty) return null;
    final seen = <String>{};
    final unique = events.where((d) => seen.add(d.cameraId)).toList();
    final path = <GeoPoint>[];
    for (var i = 0; i < unique.length; i++) {
      final a = _cameras.firstWhere((c) => c.id == unique[i].cameraId);
      path.add(a.point);
      if (i + 1 < unique.length) {
        final b = _cameras.firstWhere((c) => c.id == unique[i + 1].cameraId);
        if (a.roadId != null && a.roadId == b.roadId) {
          final road = roads.firstWhere((r) => r.id == a.roadId);
          double nearest(GeoPoint p) {
            var best = double.infinity, index = 0;
            for (var j = 0; j < road.points.length; j++) {
              final d = road.points[j].distanceTo(p);
              if (d < best) {
                best = d;
                index = j;
              }
            }
            return pathLength(road.points.take(index + 1).toList()) /
                pathLength(road.points);
          }

          final t1 = nearest(a.point), t2 = nearest(b.point);
          for (var j = 1; j < 7; j++) {
            path.add(pointAlong(road.points, t1 + (t2 - t1) * j / 7));
          }
        } else {
          path.add(GeoPoint.interpolate(a.point, b.point, .5));
        }
      }
    }
    return Journey(
      vehicle: v,
      events: List.unmodifiable(events),
      path: List.unmodifiable(path),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    for (final t in _timers) {
      t.cancel();
    }
    _changes.close();
    _reconnections.close();
  }
}
