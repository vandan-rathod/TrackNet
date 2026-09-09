import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../models/domain.dart';
import '../data_sources/backend_transport.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/backend_dashboard_repository.dart';
import '../demo/mock_repositories/mock_dashboard_repository.dart';
import '../demo/demo_data/demo_data_source.dart';

final bootStepsProvider = Provider<List<(int, int, String)>>(
  (ref) => ref.watch(dataModeProvider) == DataMode.demo
      ? DemoDataSource.bootSteps
      : const [],
);

final dataModeProvider = Provider<DataMode>((ref) {
  const value = String.fromEnvironment('DATA_MODE', defaultValue: 'demo');
  return switch (value) {
    'demo' => DataMode.demo,
    'backend' => DataMode.backend,
    _ => throw StateError('DATA_MODE must be demo or backend'),
  };
});

/// Override with your transport and register ref.onDispose(transport.dispose).
/// The provider owns its transport across repository retries.
final backendTransportProvider = Provider<BackendTransport?>((ref) => null);
final repositoryProvider = Provider<DashboardRepository>((ref) {
  final repo = ref.watch(dataModeProvider) == DataMode.demo
      ? MockDashboardRepository()
      : BackendDashboardRepository(
          transport: ref.watch(backendTransportProvider),
        );
  ref.onDispose(repo.dispose);
  unawaited(Future(repo.start));
  return repo;
});
final repositoryStateProvider = StreamProvider<RepositoryState>((ref) async* {
  final repo = ref.watch(repositoryProvider);
  yield repo.current;
  yield* repo.changes;
});
final stateProvider = Provider<RepositoryState>(
  (ref) =>
      ref.watch(repositoryStateProvider).value ??
      ref.watch(repositoryProvider).current,
);
final dataProvider = Provider<DashboardData?>(
  (ref) => ref.watch(stateProvider).data,
);
final camerasProvider = Provider<List<Camera>>(
  (ref) => ref.watch(dataProvider.select((d) => d?.cameras)) ?? const [],
);
final detectionsProvider = Provider<List<Detection>>(
  (ref) => ref.watch(dataProvider.select((d) => d?.detections)) ?? const [],
);
final alertsProvider = Provider<List<Alert>>(
  (ref) => ref.watch(dataProvider.select((d) => d?.alerts)) ?? const [],
);
final notificationsProvider = Provider<List<Alert>>(
  (ref) => ref.watch(alertsProvider).where((a) => !a.resolved).toList(),
);
final zonesProvider = Provider<List<Zone>>(
  (ref) => ref.watch(dataProvider.select((d) => d?.zones)) ?? const [],
);
final metricsProvider = Provider<DashboardMetrics?>(
  (ref) => ref.watch(dataProvider.select((d) => d?.metrics)),
);
final analyticsProvider = Provider<AnalyticsSnapshot?>(
  (ref) => ref.watch(dataProvider.select((d) => d?.analytics)),
);
final settingsProvider = Provider<SettingsState>(
  (ref) =>
      ref.watch(dataProvider.select((d) => d?.settings)) ??
      const SettingsState(),
);
final simulationProvider = Provider<bool>(
  (ref) => ref.watch(settingsProvider.select((s) => s.simulation)),
);
final reduceMotionProvider = StateProvider<bool>((ref) => false);
final collapsedProvider = StateProvider<bool>((ref) => false);
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
});
final reconnectionProvider = StreamProvider<ReconnectionState>(
  (ref) => ref.watch(repositoryProvider).reconnections,
);
final routeUriProvider = StateProvider<Uri>((ref) => Uri(path: '/dashboard'));
final selectedViewProvider = Provider<String>(
  (ref) => ref.watch(routeUriProvider).path.split('/').last,
);
final selectedCameraProvider = Provider<Camera?>((ref) {
  final id = ref.watch(routeUriProvider).queryParameters['camera'];
  return ref.watch(camerasProvider).where((c) => c.id == id).firstOrNull;
});
final selectedPlateProvider = Provider<String?>(
  (ref) => ref.watch(routeUriProvider).queryParameters['plate'],
);
final selectedAlertProvider = Provider<Alert?>((ref) {
  final id = ref.watch(routeUriProvider).queryParameters['alert'];
  return ref.watch(alertsProvider).where((a) => a.id == id).firstOrNull;
});
final selectedZoneProvider = Provider<Zone?>((ref) {
  final id = ref.watch(routeUriProvider).queryParameters['zone'];
  return ref.watch(zonesProvider).where((z) => z.id == id).firstOrNull;
});
final hourProvider = Provider<int?>(
  (ref) =>
      int.tryParse(ref.watch(routeUriProvider).queryParameters['hour'] ?? ''),
);
final flowProvider = StateProvider<OdFlow?>((ref) => null);
final mapLayersProvider = StateProvider.family<MapLayerState, String>(
  (ref, view) => MapLayerState(
    vehicles: view == 'dashboard',
    zones: view == 'analytics',
    heat: view == 'analytics',
  ),
);
final journeyProvider = FutureProvider.autoDispose.family<Journey?, String>(
  (ref, plate) => ref
      .watch(repositoryProvider)
      .findJourney(plate, reducedMotion: ref.watch(reduceMotionProvider)),
);
final cameraFeedProvider = FutureProvider.autoDispose
    .family<CameraFeed, String>(
      (ref, id) => ref.watch(repositoryProvider).cameraFeed(id),
    );
final selectedEventProvider = StateProvider.autoDispose<String?>((ref) => null);
final searchProvider = StateProvider<String>((ref) => '');
final suggestionsProvider = Provider<List<Vehicle>>((ref) {
  final q = ref.watch(searchProvider).toUpperCase();
  final plates = ref.watch(detectionsProvider).map((d) => d.plate).toSet();
  return (ref.watch(dataProvider)?.vehicles ?? <Vehicle>[])
      .where((v) => plates.contains(v.plate) && v.plate.contains(q))
      .take(q.isEmpty ? 5 : 7)
      .toList();
});
final alertFilterProvider = StateProvider<Priority?>((ref) => null);
final filteredAlertsProvider = Provider<List<Alert>>((ref) {
  final p = ref.watch(alertFilterProvider);
  return ref
      .watch(notificationsProvider)
      .where((a) => p == null || a.priority == p)
      .toList();
});

class TableQuery {
  const TableQuery({
    this.query = '',
    this.filter = 'All',
    this.sort = 0,
    this.ascending = true,
    this.page = 0,
    this.pageSize = 10,
  });
  final String query, filter;
  final int sort, page, pageSize;
  final bool ascending;
  TableQuery copyWith({
    String? query,
    String? filter,
    int? sort,
    bool? ascending,
    int? page,
    int? pageSize,
  }) => TableQuery(
    query: query ?? this.query,
    filter: filter ?? this.filter,
    sort: sort ?? this.sort,
    ascending: ascending ?? this.ascending,
    page: page ?? this.page,
    pageSize: pageSize ?? this.pageSize,
  );
}

final networkQueryProvider = StateProvider<TableQuery>(
  (ref) => const TableQuery(),
);
final detectionQueryProvider = StateProvider<TableQuery>(
  (ref) => const TableQuery(ascending: false, pageSize: 20),
);
final networkRowsProvider = Provider<List<Camera>>((ref) {
  final q = ref.watch(networkQueryProvider);
  final rows = ref
      .watch(camerasProvider)
      .where(
        (c) =>
            (q.filter == 'All' ||
                c.status.name.toLowerCase() == q.filter.toLowerCase()) &&
            ('${c.id} ${c.name}').toLowerCase().contains(q.query.toLowerCase()),
      )
      .toList();
  Comparable<dynamic> value(Camera c) => switch (q.sort) {
    0 => c.id,
    1 => c.name,
    2 => c.status.name,
    3 => c.vehiclesPerMinute ?? -1,
    4 => c.speed ?? -1,
    5 => c.accuracy ?? -1,
    _ => c.lastSeen?.millisecondsSinceEpoch ?? 0,
  };
  rows.sort((a, b) => value(a).compareTo(value(b)) * (q.ascending ? 1 : -1));
  return rows;
});
final detectionRowsProvider = Provider<List<Detection>>((ref) {
  final q = ref.watch(detectionQueryProvider);
  final cams = {for (final c in ref.watch(camerasProvider)) c.id: c};
  final rows = ref
      .watch(detectionsProvider)
      .where(
        (d) =>
            (q.filter == 'All' || q.filter == d.status.label) &&
            ('${d.displayPlate} ${d.cameraId} ${cams[d.cameraId]?.name ?? ''} ${d.vehicleType ?? ''}')
                .toLowerCase()
                .contains(q.query.toLowerCase()),
      )
      .toList();
  Comparable<dynamic> value(Detection d) => switch (q.sort) {
    0 => d.timestamp.millisecondsSinceEpoch,
    1 => d.displayPlate,
    2 => d.vehicleType ?? '',
    3 => d.cameraId,
    4 => cams[d.cameraId]?.name ?? '',
    5 => d.speed ?? -1,
    6 => d.confidence ?? -1,
    _ => d.status.code,
  };
  rows.sort((a, b) => value(a).compareTo(value(b)) * (q.ascending ? 1 : -1));
  return rows;
});
