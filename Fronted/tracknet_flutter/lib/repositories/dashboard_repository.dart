import '../models/domain.dart';

abstract interface class CameraRepository {
  Future<void> reconnectCamera(String id);
  Future<void> cycleFeeds();
  Future<CameraFeed> cameraFeed(String id);
}

abstract interface class VehicleRepository {
  Future<Journey?> findJourney(String plate, {bool reducedMotion = false});
}

abstract interface class DetectionRepository {
  List<Detection> get detections;
}

abstract interface class AlertRepository {
  Future<void> resolveAlert(String id);
  Future<void> resolveAll();
}

abstract interface class AnalyticsRepository {
  void setVisibleView(String view);
}

abstract interface class NetworkRepository {
  Future<void> poll();
  Future<void> reconnectAll();
}

abstract interface class MapRepository {
  List<Road> get roads;
}

abstract interface class SettingsRepository {
  Future<void> updateSettings(SettingsState settings);
  Future<void> resetDemo();
}

abstract class DashboardRepository
    implements
        CameraRepository,
        VehicleRepository,
        DetectionRepository,
        AlertRepository,
        AnalyticsRepository,
        NetworkRepository,
        MapRepository,
        SettingsRepository {
  RepositoryState get current;
  Stream<RepositoryState> get changes;
  Stream<ReconnectionState> get reconnections;
  Future<void> start();
  void dispose();
}
