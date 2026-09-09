import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tracknet/data_sources/backend_transport.dart';
import 'package:tracknet/models/domain.dart';
import 'package:tracknet/repositories/backend_dashboard_repository.dart';

class TestTransport implements BackendTransport {
  final events = StreamController<RepositoryState>.broadcast(sync: true);
  DashboardData data = const DashboardData();
  Object? failure;
  bool disposed = false;
  @override
  Future<DashboardData> fetch() async {
    if (failure != null) throw failure!;
    return data;
  }

  @override
  Stream<RepositoryState> watch() => events.stream;
  @override
  Future<Journey?> findJourney(String plate) async => null;
  @override
  Future<CameraFeed> cameraFeed(String cameraId) => throw UnimplementedError();
  @override
  Future<void> reconnectCamera(String cameraId) async {}
  @override
  Future<void> resolveAlert(String alertId) async {}
  @override
  Future<void> updateSettings(SettingsState settings) async {}
  @override
  void dispose() {
    disposed = true;
    events.close();
  }
}

void main() {
  test(
    'Backend preserves empty, live, offline and error states without fallback',
    () async {
      final transport = TestTransport();
      final repository = BackendDashboardRepository(transport: transport);
      addTearDown(transport.dispose);
      addTearDown(repository.dispose);
      await repository.start();
      expect(repository.current.availability, Availability.empty);
      transport.events.add(
        const RepositoryState(
          Availability.ready,
          data: DashboardData(metrics: DashboardMetrics(1, 3, 4, 2, 0, 17)),
        ),
      );
      expect(repository.current.data!.metrics!.total, 3);
      transport.events.add(const RepositoryState(Availability.offline));
      expect(repository.current.availability, Availability.offline);
      expect(repository.current.data, isNull);
      transport.failure = StateError('Transport unavailable');
      await repository.poll();
      expect(repository.current.availability, Availability.error);
      expect(repository.current.data, isNull);
      repository.dispose();
      expect(transport.disposed, isFalse);
      transport.failure = null;
      final retry = BackendDashboardRepository(transport: transport);
      addTearDown(retry.dispose);
      await retry.start();
      expect(retry.current.availability, Availability.empty);
    },
  );
}
