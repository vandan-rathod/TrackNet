import 'dart:math' as math;

enum DataMode { demo, backend }

enum Availability { loading, ready, empty, offline, disconnected, error }

enum CameraStatus { online, warning, offline }

enum DetectionStatus {
  noPlateDetected('NO_PLATE_DETECTED'),
  lowConfidenceUnreadable('LOW_CONFIDENCE_UNREADABLE'),
  normal('NORMAL'),
  flagged('FLAGGED'),
  blacklisted('BLACKLISTED'),
  tamperReview('TAMPER_REVIEW'),
  cloneReview('CLONE_REVIEW');

  const DetectionStatus(this.code);
  final String code;
  String get label => switch (this) {
    normal => 'Normal',
    flagged => 'Flagged',
    blacklisted => 'Blacklisted',
    _ => code.replaceAll('_', ' '),
  };
}

enum Priority { high, medium, low }

class GeoPoint {
  const GeoPoint(this.lat, this.lng);
  final double lat, lng;
  double distanceTo(GeoPoint b) {
    final aLat = lat * math.pi / 180, bLat = b.lat * math.pi / 180;
    final x =
        math.pow(math.sin((bLat - aLat) / 2), 2) +
        math.cos(aLat) *
            math.cos(bLat) *
            math.pow(math.sin((b.lng - lng) * math.pi / 360), 2);
    return 12742 * math.asin(math.sqrt(x.clamp(0, 1)));
  }

  static GeoPoint interpolate(GeoPoint a, GeoPoint b, double t) =>
      GeoPoint(a.lat + (b.lat - a.lat) * t, a.lng + (b.lng - a.lng) * t);
}

double pathLength(List<GeoPoint> p) {
  var d = 0.0;
  for (var i = 1; i < p.length; i++) {
    d += p[i - 1].distanceTo(p[i]);
  }
  return d;
}

GeoPoint pointAlong(List<GeoPoint> p, double t) {
  if (p.isEmpty) throw StateError('No route geometry');
  var remaining = pathLength(p) * t.clamp(0, 1);
  for (var i = 1; i < p.length; i++) {
    final d = p[i - 1].distanceTo(p[i]);
    if (d > 0 && remaining <= d) {
      return GeoPoint.interpolate(p[i - 1], p[i], remaining / d);
    }
    remaining -= d;
  }
  return p.last;
}

class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.point,
    required this.status,
    this.roadId,
    this.vehiclesPerMinute,
    this.speed,
    this.accuracy,
    this.lastPlate,
    this.lastSeen,
    this.offSince,
  });
  final String id, name, zoneId;
  final String? roadId, lastPlate;
  final GeoPoint point;
  final CameraStatus status;
  final int? vehiclesPerMinute;
  final double? speed, accuracy;
  final DateTime? lastSeen, offSince;
  Camera copyWith({
    CameraStatus? status,
    int? vehiclesPerMinute,
    double? speed,
    double? accuracy,
    String? lastPlate,
    DateTime? lastSeen,
    DateTime? offSince,
  }) => Camera(
    id: id,
    name: name,
    zoneId: zoneId,
    point: point,
    roadId: roadId,
    status: status ?? this.status,
    vehiclesPerMinute: vehiclesPerMinute ?? this.vehiclesPerMinute,
    speed: speed ?? this.speed,
    accuracy: accuracy ?? this.accuracy,
    lastPlate: lastPlate ?? this.lastPlate,
    lastSeen: lastSeen ?? this.lastSeen,
    offSince: offSince ?? this.offSince,
  );
}

class Detection {
  const Detection({
    required this.id,
    required this.cameraId,
    required this.timestamp,
    required this.status,
    required this.context,
    this.plate,
    this.rawOcr,
    this.vehicleType,
    this.confidence,
    this.speed,
  });
  final String id, cameraId, context;
  final String? plate, rawOcr, vehicleType;
  final DateTime timestamp;
  final double? confidence, speed;
  final DetectionStatus status;
  String get displayPlate => plate ?? status.label;
}

class Vehicle {
  const Vehicle({
    required this.plate,
    required this.type,
    this.model,
    this.color,
    this.blacklisted = false,
  });
  final String plate, type;
  final String? model, color;
  final bool blacklisted;
}

class Journey {
  const Journey({
    required this.vehicle,
    required this.events,
    required this.path,
  });
  final Vehicle vehicle;
  final List<Detection> events;
  final List<GeoPoint> path;
  Duration get duration => events.length < 2
      ? Duration.zero
      : events.last.timestamp.difference(events.first.timestamp);
  double get distance => pathLength(path);
  double? get averageSpeed => duration.inMilliseconds <= 0
      ? null
      : distance / (duration.inMilliseconds / 3600000);
  int get cameraCount => events.map((d) => d.cameraId).toSet().length;
}

class Alert {
  const Alert({
    required this.id,
    required this.kind,
    required this.priority,
    required this.timestamp,
    required this.message,
    required this.note,
    this.cameraId,
    this.plate,
    this.resolved = false,
    this.system = false,
  });
  final String id, kind, message, note;
  final String? cameraId, plate;
  final Priority priority;
  final DateTime timestamp;
  final bool resolved, system;
  Alert resolve() => Alert(
    id: id,
    kind: kind,
    priority: priority,
    timestamp: timestamp,
    message: message,
    note: note,
    cameraId: cameraId,
    plate: plate,
    resolved: true,
    system: system,
  );
}

class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.center,
    required this.radius,
    required this.density,
    required this.base,
  });
  final String id, name;
  final GeoPoint center;
  final double radius, density, base;
  Zone withDensity(double d) => Zone(
    id: id,
    name: name,
    center: center,
    radius: radius,
    density: d,
    base: base,
  );
}

class Road {
  const Road(this.id, this.name, this.points, this.zoneId);
  final String id, name, zoneId;
  final List<GeoPoint> points;
}

class MapShape {
  const MapShape(this.kind, this.points, {this.name, this.width = 1});
  final String kind;
  final List<GeoPoint> points;
  final String? name;
  final double width;
}

class TrafficParticle {
  const TrafficParticle(this.roadId, this.position, this.direction, this.speed);
  final String roadId;
  final double position, speed;
  final int direction;
}

class FeedCar {
  const FeedCar(
    this.position,
    this.lane,
    this.direction,
    this.speed,
    this.width,
    this.height,
    this.color,
    this.truck,
  );
  final double position, speed, width, height;
  final int lane, direction, color;
  final bool truck;
}

class CameraFeed {
  const CameraFeed(
    this.cameraId,
    this.cars, {
    this.available = false,
    this.message = 'No stream connected',
  });
  final String cameraId, message;
  final List<FeedCar> cars;
  final bool available;
}

class OdFlow {
  const OdFlow(this.origin, this.destination, this.count);
  final String origin, destination;
  final int count;
  String get id => '$origin-$destination';
}

class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    required this.volume,
    required this.speed,
    required this.typeCounts,
    required this.cameraDensity,
    required this.flows,
  });
  final List<double> volume, speed;
  final Map<String, int> typeCounts, cameraDensity;
  final List<OdFlow> flows;
}

class DashboardMetrics {
  const DashboardMetrics(
    this.active,
    this.total,
    this.detected,
    this.recognized,
    this.alerts,
    this.averageSpeed,
  );
  final int active, total, detected, recognized, alerts;
  final double averageSpeed;
}

class PlatformStatus {
  const PlatformStatus({
    required this.engine,
    required this.build,
    required this.startedAt,
    required this.tick,
    required this.camerasTracked,
    required this.mapStatus,
    required this.routesIndexed,
    required this.alertsRaised,
    required this.operatorName,
    required this.operatorDetail,
  });
  final String engine, build, mapStatus, operatorName, operatorDetail;
  final DateTime startedAt;
  final int tick, camerasTracked, routesIndexed, alertsRaised;
}

class SettingsState {
  const SettingsState({
    this.simulation = false,
    this.particles = false,
    this.automaticAlerts = false,
    this.feeds = false,
    this.grid = true,
    this.reducedMotion = false,
  });
  final bool simulation, particles, automaticAlerts, feeds, grid, reducedMotion;
  SettingsState copyWith({
    bool? simulation,
    bool? particles,
    bool? automaticAlerts,
    bool? feeds,
    bool? grid,
    bool? reducedMotion,
  }) => SettingsState(
    simulation: simulation ?? this.simulation,
    particles: particles ?? this.particles,
    automaticAlerts: automaticAlerts ?? this.automaticAlerts,
    feeds: feeds ?? this.feeds,
    grid: grid ?? this.grid,
    reducedMotion: reducedMotion ?? this.reducedMotion,
  );
}

class MapLayerState {
  const MapLayerState({
    this.cameras = true,
    this.vehicles = false,
    this.zones = false,
    this.heat = false,
    this.flows = false,
  });
  final bool cameras, vehicles, zones, heat, flows;
  MapLayerState toggle(String key) => MapLayerState(
    cameras: key == 'Cameras' ? !cameras : cameras,
    vehicles: key == 'Vehicles' ? !vehicles : vehicles,
    zones: key == 'Zones' ? !zones : zones,
    heat: key == 'Heat' ? !heat : heat,
    flows: key == 'OD routes' ? !flows : flows,
  );
}

class DashboardData {
  const DashboardData({
    this.cameras = const [],
    this.detections = const [],
    this.vehicles = const [],
    this.alerts = const [],
    this.zones = const [],
    this.roads = const [],
    this.shapes = const [],
    this.particles = const [],
    this.feeds = const [],
    this.metrics,
    this.analytics,
    this.platform,
    this.settings = const SettingsState(),
  });
  final List<Camera> cameras;
  final List<Detection> detections;
  final List<Vehicle> vehicles;
  final List<Alert> alerts;
  final List<Zone> zones;
  final List<Road> roads;
  final List<MapShape> shapes;
  final List<TrafficParticle> particles;
  final List<CameraFeed> feeds;
  final DashboardMetrics? metrics;
  final AnalyticsSnapshot? analytics;
  final PlatformStatus? platform;
  final SettingsState settings;
}

class RepositoryState {
  const RepositoryState(this.availability, {this.data, this.message});
  final Availability availability;
  final DashboardData? data;
  final String? message;
}

class ReconnectionState {
  const ReconnectionState({
    this.running = false,
    this.total = 0,
    this.completed = const [],
    this.message = '',
  });
  final bool running;
  final int total;
  final List<String> completed;
  final String message;
}
