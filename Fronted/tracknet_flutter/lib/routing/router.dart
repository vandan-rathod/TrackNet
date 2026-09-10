import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../app/app_shell.dart';
import '../features/dashboard/dashboard_page.dart';
import '../features/cameras/cameras_page.dart';
import '../features/vehicle/vehicle_page.dart';
import '../features/analytics/analytics_page.dart';
import '../features/alerts/alerts_page.dart';
import '../features/network/network_page.dart';
import '../features/settings/settings_page.dart';
import '../shared_widgets/widgets.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/dashboard',
    overridePlatformDefaultLocation: false,
    redirect: (context, state) {
      if (state.uri.path == '/') return '/dashboard';
      final hour = state.uri.queryParameters['hour'];
      if (hour != null &&
          hour != 'now' &&
          (int.tryParse(hour) == null ||
              int.parse(hour) < 0 ||
              int.parse(hour) > 23)) {
        final q = Map<String, String>.from(state.uri.queryParameters)
          ..remove('hour');
        return state.uri.replace(queryParameters: q).toString();
      }
      return null;
    },
    errorBuilder: (context, state) => Scaffold(
      body: EmptyState(
        'Page not found',
        action: TextButton(
          onPressed: () => context.go('/dashboard'),
          child: const Text('Open dashboard'),
        ),
      ),
    ),
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(uri: state.uri, child: child),
        routes: [
          for (final route in <String, Widget>{
            'dashboard': const DashboardPage(),
            'cameras': const CamerasPage(),
            'vehicle': const VehiclePage(),
            'analytics': const AnalyticsPage(),
            'alerts': const AlertsPage(),
            'network': const NetworkPage(),
            'settings': const SettingsPage(),
          }.entries)
            GoRoute(
              path: '/${route.key}',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: FeatureBody(view: route.key, child: route.value),
                // FeatureBody owns the page entrance animation. Keeping a
                // second route transition here makes navigation feel doubled
                // and can cause uneven frame pacing on lower-power devices.
                transitionDuration: Duration.zero,
                transitionsBuilder: (context, animation, secondary, child) =>
                    child,
              ),
            ),
        ],
      ),
    ],
  );
  void sync() {
    final uri = router.routeInformationProvider.value.uri;
    ref.read(routeUriProvider.notifier).state = uri;
    ref.read(repositoryProvider).setVisibleView(uri.path.split('/').last);
  }

  router.routeInformationProvider.addListener(sync);
  Future.microtask(sync);
  ref.onDispose(() {
    router.routeInformationProvider.removeListener(sync);
    router.dispose();
  });
  return router;
});
