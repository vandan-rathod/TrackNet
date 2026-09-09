import '../models/domain.dart';

/// Supply your REST/stream client and explicit DTO mapper here. No assumed URLs.
abstract interface class BackendTransport {
  Future<DashboardData> fetch();
  Stream<RepositoryState> watch();
  Future<Journey?> findJourney(String plate);
  Future<CameraFeed> cameraFeed(String cameraId);
  Future<void> reconnectCamera(String cameraId);
  Future<void> resolveAlert(String alertId);
  Future<void> updateSettings(SettingsState settings);
  void dispose();
}

/// The backend contract owns T; no guessed JSON keys.
abstract interface class DtoMapper<T, D> {
  D toDomain(T dto);
}

class DetectionInput {
  const DetectionInput({
    required this.id,
    required this.cameraId,
    required this.timestamp,
    required this.status,
    required this.context,
    this.rawOcr,
    this.acceptedPlate,
    this.confidence,
    this.speed,
    this.vehicleType,
  });
  final String id, cameraId, context;
  final DateTime timestamp;
  final DetectionStatus status;
  final String? rawOcr, acceptedPlate, vehicleType;
  final double? confidence, speed;
}
