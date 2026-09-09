import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracknet/models/domain.dart';
import 'package:tracknet/models/plate.dart';
import 'package:tracknet/data_sources/backend_transport.dart';
import 'package:tracknet/data_sources/detection_mapper.dart';
import 'package:tracknet/demo/mock_repositories/mock_dashboard_repository.dart';
import 'package:tracknet/repositories/backend_dashboard_repository.dart';
import 'package:tracknet/providers/providers.dart';

void main() {
  test(
    'Source fixtures retain network, charts, alerts and source statuses',
    () {
      final repo = MockDashboardRepository(
        random: Random(1),
        enableTimers: false,
      );
      addTearDown(repo.dispose);
      final d = repo.current.data!;
      expect(d.cameras.length, 256);
      expect(
        d.cameras.where((c) => c.status == CameraStatus.online).length,
        248,
      );
      expect(
        d.cameras.where((c) => c.status == CameraStatus.warning).length,
        6,
      );
      expect(
        d.cameras
            .where((c) => c.status == CameraStatus.offline)
            .map((c) => c.id),
        ['CAM-109', 'CAM-151'],
      );
      expect(d.detections.length, 535);
      expect(d.alerts.length, 7);
      expect(d.zones.length, 7);
      expect(d.feeds.length, 12);
      expect(d.metrics!.detected, 18429);
      expect(d.metrics!.recognized, 17862);
      expect(d.analytics!.volume[18], 1890);
      expect(d.analytics!.flows.first.count, 4821);
      expect(d.analytics!.speed[0], 44);
      expect(d.platform!.operatorName, 'A. Sharma');
      expect(d.roads.length, 7);
      expect(d.shapes.length, 53);
    },
  );
  test(
    'Canonical journey remains intact across random ticks, search and reset',
    () async {
      final repo = MockDashboardRepository(
        random: Random(21),
        enableTimers: false,
      );
      addTearDown(repo.dispose);
      for (var i = 0; i < 100; i++) {
        repo.tickSimulation();
      }
      final journey = await repo.findJourney('GJ01AB1234', reducedMotion: true);
      expect(journey!.events.map((e) => e.cameraId), [
        'CAM-012',
        'CAM-027',
        'CAM-041',
        'CAM-063',
      ]);
      expect(journey.duration.inMinutes, 52);
      expect(journey.events.map((d) => d.speed), [24, 31, 44, 58]);
      expect(journey.cameraCount, 4);
      expect(journey.distance, greaterThan(10));
      expect(await repo.findJourney('GJ01ZZ9999', reducedMotion: true), isNull);
      await repo.resetDemo();
      expect(repo.current.data!.detections.length, 535);
      expect(repo.current.data!.metrics!.detected, 18429);
    },
  );
  test(
    'Pause stops generation; resolution and reconnect update shared source',
    () async {
      final repo = MockDashboardRepository(
        random: Random(1),
        enableTimers: false,
      );
      addTearDown(repo.dispose);
      await repo.updateSettings(
        repo.current.data!.settings.copyWith(simulation: false),
      );
      for (var i = 0; i < 5; i++) {
        repo.tickSimulation();
      }
      expect(repo.current.data!.platform!.tick, 0);
      await repo.reconnectCamera('CAM-109');
      expect(
        repo.current.data!.cameras.firstWhere((c) => c.id == 'CAM-109').status,
        CameraStatus.online,
      );
      expect(
        repo.current.data!.alerts.firstWhere((a) => a.id == 'ALT-003').resolved,
        true,
      );
      await repo.resolveAll();
      expect(repo.current.data!.metrics!.alerts, 0);
      await repo.cycleFeeds();
      expect(repo.current.data!.feeds.length, 12);
    },
  );
  test(
    'Backend mode has no demo state and cannot perform a demo reset',
    () async {
      final repo = BackendDashboardRepository();
      addTearDown(repo.dispose);
      expect(repo.current.availability, Availability.loading);
      await repo.start();
      expect(repo.current.availability, Availability.disconnected);
      expect(repo.current.data, isNull);
      expect(repo.detections, isEmpty);
      expect(repo.roads, isEmpty);
      expect(repo.resetDemo(), throwsUnsupportedError);
      final container = ProviderContainer(
        overrides: [dataModeProvider.overrideWithValue(DataMode.backend)],
      );
      addTearDown(container.dispose);
      expect(
        container.read(repositoryProvider),
        isA<BackendDashboardRepository>(),
      );
      expect(container.read(camerasProvider), isEmpty);
      expect(container.read(bootStepsProvider), isEmpty);
      await Future<void>.delayed(Duration.zero);
    },
  );
  test(
    'Filters use actual status values; searches and numeric sorting work',
    () async {
      final repo = MockDashboardRepository(enableTimers: false);
      final container = ProviderContainer(
        overrides: [repositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      addTearDown(repo.dispose);
      container.read(networkQueryProvider.notifier).state = const TableQuery(
        filter: 'Warning',
      );
      expect(container.read(networkRowsProvider).length, 6);
      container.read(networkQueryProvider.notifier).state = const TableQuery(
        filter: 'Offline',
      );
      expect(container.read(networkRowsProvider).length, 2);
      container.read(networkQueryProvider.notifier).state = const TableQuery(
        query: 'Airport',
      );
      expect(
        container
            .read(networkRowsProvider)
            .every((c) => c.name.contains('Airport')),
        true,
      );
      container.read(networkQueryProvider.notifier).state = const TableQuery(
        sort: 3,
        ascending: false,
      );
      final rows = container.read(networkRowsProvider);
      expect(
        rows.first.vehiclesPerMinute,
        greaterThanOrEqualTo(rows.last.vehiclesPerMinute!),
      );
      container.read(detectionQueryProvider.notifier).state = const TableQuery(
        query: 'GJ01AB1234',
      );
      expect(container.read(detectionRowsProvider).length, 4);
      container.read(detectionQueryProvider.notifier).state = const TableQuery(
        filter: 'Blacklisted',
      );
      expect(
        container
            .read(detectionRowsProvider)
            .every((d) => d.status == DetectionStatus.blacklisted),
        true,
      );
    },
  );
  test(
    'OCR ambiguities never promote unreadable detections into plate identities',
    () {
      expect(PlateRecognition.valid('GJ01AB1234'), true);
      expect(PlateRecognition.valid('GJ01AB123'), false);
      expect(
        PlateRecognition.reviewCandidates('GJOIABIZS8'),
        contains('GJ01AB1258'),
      );
      for (final status in [
        DetectionStatus.noPlateDetected,
        DetectionStatus.lowConfidenceUnreadable,
      ]) {
        final read = const DetectionMapper().toDomain(
          DetectionInput(
            id: 'read',
            cameraId: 'real-camera',
            timestamp: DateTime.utc(2026),
            status: status,
            context: 'night / occlusion',
            rawOcr: 'GJOIABIZS8',
            acceptedPlate: 'GJ01AB1258',
            confidence: 12,
          ),
        );
        expect(read.plate, isNull);
        expect(read.rawOcr, 'GJOIABIZS8');
        expect(read.context, 'night / occlusion');
        expect(read.confidence, 12);
        expect(read.cameraId, 'real-camera');
      }
      expect(
        () => const DetectionMapper().toDomain(
          DetectionInput(
            id: 'bad',
            cameraId: 'c',
            timestamp: DateTime.utc(2026),
            status: DetectionStatus.normal,
            context: '',
            acceptedPlate: 'bad',
          ),
        ),
        throwsFormatException,
      );
    },
  );
}
