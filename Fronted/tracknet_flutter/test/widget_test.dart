import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tracknet/app/tracknet_app.dart';
import 'package:tracknet/theme/app_theme.dart';
import 'package:tracknet/providers/providers.dart';
import 'package:tracknet/routing/router.dart';
import 'package:tracknet/models/domain.dart';
import 'package:tracknet/demo/mock_repositories/mock_dashboard_repository.dart';
import 'package:tracknet/repositories/backend_dashboard_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    appTheme();
    await GoogleFonts.pendingFonts();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    GoogleFonts.config.allowRuntimeFetching = false;
  });
  for (final width in [1440.0, 834.0, 390.0]) {
    testWidgets(
      'Seven routes render at width $width without layout exceptions',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final oldError = FlutterError.onError;
        FlutterError.onError = (details) {
          FlutterError.dumpErrorToConsole(details, forceReport: true);
          oldError?.call(details);
        };
        addTearDown(() => FlutterError.onError = oldError);
        final repo = MockDashboardRepository(enableTimers: false);
        final container = ProviderContainer(
          overrides: [
            repositoryProvider.overrideWithValue(repo),
            reduceMotionProvider.overrideWith((ref) => true),
          ],
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TrackNetApp(showBoot: false),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final router = container.read(routerProvider);
        if (width == 1440) {
          final map = find.byType(InteractiveViewer).first;
          final controller = tester
              .widget<InteractiveViewer>(map)
              .transformationController!;
          final before = controller.value.clone();
          final page = Scrollable.of(tester.element(map)).position;
          final beforeScroll = page.pixels;
          GestureBinding.instance.handlePointerEvent(
            PointerScrollEvent(
              position: tester.getCenter(map),
              scrollDelta: const Offset(0, 100),
              kind: PointerDeviceKind.mouse,
            ),
          );
          await tester.pump();
          expect(
            controller.value,
            before,
            reason: 'Page wheel scroll must not change the map transform',
          );
          expect(page.pixels, greaterThan(beforeScroll));
          await tester.tap(find.byTooltip('Zoom in'));
          await tester.pump();
          expect(
            controller.value.getMaxScaleOnAxis(),
            greaterThan(before.getMaxScaleOnAxis()),
          );
          expect(find.byTooltip('Collapse sidebar'), findsNothing);
          expect(find.byTooltip('Expand sidebar'), findsNothing);
          expect(find.text('Command Overview'), findsNothing);
          expect(find.text('COMMAND OVERVIEW'), findsNothing);
          expect(find.text('Demo'), findsNothing);
          await tester.tap(find.byTooltip('Operator profile'));
          await tester.pumpAndSettle();
          expect(find.text('Operator profile'), findsOneWidget);
          expect(find.text('A. Sharma'), findsOneWidget);
          await tester.tap(find.byTooltip('Close panel'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Notifications'));
          await tester.pumpAndSettle();
          expect(find.text('Notifications'), findsOneWidget);
          expect(find.text('7 open alerts'), findsOneWidget);
          await tester.tap(find.text('View all alerts'));
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/alerts');
        }
        for (final route in [
          'dashboard',
          'cameras',
          'vehicle',
          'analytics',
          'alerts',
          'network',
          'settings',
        ]) {
          router.go('/$route');
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: route);
          final scroll = find.byType(SingleChildScrollView).first;
          await tester.drag(scroll, const Offset(0, -650));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: 'scrolled $route');
        }
        router.go('/network?camera=CAM-109');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(container.read(selectedCameraProvider)?.id, 'CAM-109');
        router.go('/analytics?hour=18&zone=city');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(container.read(hourProvider), 18);
        expect(container.read(selectedZoneProvider)?.id, 'city');
        router.go('/alerts?alert=ALT-001');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(container.read(selectedAlertProvider)?.id, 'ALT-001');
        expect(tester.takeException(), isNull);
        router.go('/vehicle?plate=GJ01AB1234');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pump();
        expect(find.text('Captured trajectory'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        repo.dispose();
      },
    );
  }
  testWidgets('Backend unavailable route shows no demo records', (
    tester,
  ) async {
    final repo = BackendDashboardRepository();
    await repo.start();
    final container = ProviderContainer(
      overrides: [
        dataModeProvider.overrideWithValue(DataMode.backend),
        repositoryProvider.overrideWithValue(repo),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TrackNetApp(showBoot: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Backend disconnected'), findsOneWidget);
    expect(find.text('18,429'), findsNothing);
    expect(find.text('A. Sharma'), findsNothing);
    expect(find.textContaining('CAM-109'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
    repo.dispose();
  });
}
