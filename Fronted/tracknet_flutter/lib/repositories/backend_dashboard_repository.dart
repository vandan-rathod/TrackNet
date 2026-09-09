import 'dart:async';

import '../data_sources/backend_transport.dart';
import '../models/domain.dart';
import 'dashboard_repository.dart';

class BackendDashboardRepository extends DashboardRepository {
  BackendDashboardRepository({this.transport});
  final BackendTransport? transport;
  final _changes = StreamController<RepositoryState>.broadcast();
  final _reconnections = StreamController<ReconnectionState>.broadcast();
  StreamSubscription<RepositoryState>? _subscription;
  bool _disposed = false;
  int _request = 0;
  RepositoryState _state = const RepositoryState(Availability.loading);
  @override
  RepositoryState get current => _state;
  @override
  Stream<RepositoryState> get changes => _changes.stream;
  @override
  Stream<ReconnectionState> get reconnections => _reconnections.stream;
  void _emit(RepositoryState state) {
    if (_disposed) return;
    _state = state;
    _changes.add(state);
  }

  BackendTransport get _connected =>
      transport ?? (throw StateError('Backend adapter is not connected'));
  @override
  Future<void> start() async {
    await _subscription?.cancel();
    if (_disposed) return;
    await poll();
    if (_disposed || transport == null) return;
    _subscription = transport!.watch().listen(
      _emit,
      onError: (Object e) =>
          _emit(RepositoryState(Availability.error, message: e.toString())),
      onDone: () => _emit(
        const RepositoryState(
          Availability.disconnected,
          message: 'Backend stream disconnected. Retry to reconnect.',
        ),
      ),
    );
  }

  @override
  Future<void> poll() async {
    final request = ++_request;
    _emit(const RepositoryState(Availability.loading));
    if (transport == null) {
      _emit(
        const RepositoryState(
          Availability.disconnected,
          message:
              'The data service is not connected. Live data is unavailable.',
        ),
      );
      return;
    }
    try {
      final data = await transport!.fetch();
      if (_disposed || request != _request) return;
      _emit(
        RepositoryState(
          data.cameras.isEmpty &&
                  data.detections.isEmpty &&
                  data.vehicles.isEmpty &&
                  data.alerts.isEmpty &&
                  data.zones.isEmpty &&
                  data.roads.isEmpty &&
                  data.shapes.isEmpty &&
                  data.feeds.isEmpty &&
                  data.analytics == null &&
                  data.platform == null &&
                  data.metrics == null
              ? Availability.empty
              : Availability.ready,
          data: data,
        ),
      );
    } catch (e) {
      if (_disposed || request != _request) return;
      _emit(RepositoryState(Availability.error, message: e.toString()));
    }
  }

  @override
  Future<Journey?> findJourney(String plate, {bool reducedMotion = false}) =>
      _connected.findJourney(plate);
  @override
  Future<CameraFeed> cameraFeed(String id) => _connected.cameraFeed(id);
  @override
  Future<void> reconnectCamera(String id) async {
    await _connected.reconnectCamera(id);
    await poll();
  }

  @override
  Future<void> resolveAlert(String id) async {
    await _connected.resolveAlert(id);
    await poll();
  }

  @override
  Future<void> resolveAll() async {
    for (final a in current.data?.alerts ?? <Alert>[]) {
      if (!a.resolved) await _connected.resolveAlert(a.id);
    }
    await poll();
  }

  @override
  Future<void> reconnectAll() async {
    for (final c in current.data?.cameras ?? <Camera>[]) {
      if (c.status == CameraStatus.offline) {
        await _connected.reconnectCamera(c.id);
      }
    }
    await poll();
  }

  @override
  Future<void> updateSettings(SettingsState settings) async {
    await _connected.updateSettings(settings);
    await poll();
  }

  @override
  Future<void> cycleFeeds() => poll();
  @override
  Future<void> resetDemo() => Future.error(
    UnsupportedError('Demo reset is unavailable in Backend Mode'),
  );
  @override
  List<Detection> get detections => current.data?.detections ?? const [];
  @override
  List<Road> get roads => current.data?.roads ?? const [];
  @override
  void setVisibleView(String view) {}
  @override
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    // The injecting provider owns the transport across repository retries.
    _changes.close();
    _reconnections.close();
  }
}
