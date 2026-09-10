import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/domain.dart';
import '../providers/providers.dart';
import '../shared_widgets/widgets.dart';
import '../theme/app_theme.dart';
import '../shared_widgets/header_panels.dart';

const destinations = [
  ('dashboard', 'Dashboard', Icons.grid_view_outlined),
  ('cameras', 'Live Cameras', Icons.videocam_outlined),
  ('vehicle', 'Vehicle Intelligence', Icons.route_outlined),
  ('analytics', 'Traffic Analytics', Icons.bar_chart_outlined),
  ('alerts', 'Alert Center', Icons.notifications_outlined),
  ('network', 'Camera Network', Icons.hub_outlined),
  ('settings', 'Settings', Icons.settings_outlined),
];
const headings = {
  'dashboard': ('', 'Urban Traffic Intelligence', ''),
  'cameras': (
    'Camera Mesh',
    'Live Cameras',
    'Live ANPR camera feeds across the city network',
  ),
  'vehicle': (
    'Journey Forensics',
    'Vehicle Intelligence',
    'Correlate captured plates and reconstruct city-wide journeys',
  ),
  'analytics': (
    'City Analytics',
    'Traffic Analytics',
    'Traffic patterns, camera coverage and movement between zones',
  ),
  'alerts': (
    'Response Queue',
    'Alert Center',
    'Vehicle flags, movement patterns and camera health events',
  ),
  'network': (
    'Fleet Registry',
    'Camera Network',
    'Camera health, load and ANPR accuracy',
  ),
  'settings': (
    'System',
    'Settings',
    'Simulation behaviour, display and platform information',
  ),
};

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.uri, required this.child});
  final Uri uri;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = uri.path.split('/').last,
        heading = headings[view] ?? headings['dashboard']!;
    final selected = destinations.indexWhere((d) => d.$1 == view).clamp(0, 6),
        collapsed = ref.watch(collapsedProvider);
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= 1000, mobile = c.maxWidth < 650;
        return Scaffold(
          drawer: desktop
              ? null
              : Drawer(child: SideNavigation(selected: selected)),
          body: SafeArea(
            child: Row(
              children: [
                if (desktop)
                  AnimatedContainer(
                    duration: Duration(
                      milliseconds: MediaQuery.disableAnimationsOf(context)
                          ? 0
                          : 250,
                    ),
                    width: collapsed ? 80 : 224,
                    child: SideNavigation(
                      selected: selected,
                      collapsed: collapsed,
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TopBar(heading: heading.$1, desktop: desktop),
                      if (mobile)
                        const Align(
                          alignment: Alignment.centerRight,
                          child: LiveClock(),
                        ),
                      Expanded(child: child),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: mobile
              ? SafeArea(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: c.maxWidth < 560 ? 620 : c.maxWidth,
                      child: NavigationBar(
                        selectedIndex: selected,
                        onDestinationSelected: (i) =>
                            context.go('/${destinations[i].$1}'),
                        destinations: destinations
                            .map(
                              (d) => NavigationDestination(
                                icon: Icon(d.$3, size: 20),
                                label: switch (d.$1) {
                                  'dashboard' => 'Home',
                                  'cameras' => 'Live',
                                  'vehicle' => 'Vehicles',
                                  'analytics' => 'Stats',
                                  'settings' => 'Setup',
                                  _ =>
                                    d.$2
                                        .replaceAll('Camera ', '')
                                        .replaceAll(' Center', ''),
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class DataGate extends ConsumerWidget {
  const DataGate({super.key, required this.view, required this.child});
  final String view;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(stateProvider);
    if (view == 'settings') return child;
    if (state.availability != Availability.ready) {
      return AsyncStatePanel(
        state,
        retry: () {
          ref.invalidate(repositoryProvider);
        },
      );
    }
    return child;
  }
}

class SideNavigation extends ConsumerWidget {
  const SideNavigation({
    super.key,
    required this.selected,
    this.collapsed = false,
  });
  final int selected;
  final bool collapsed;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
            child: InkWell(
              onTap: () => ref.read(collapsedProvider.notifier).state = !ref
                  .read(collapsedProvider),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: primaryInk,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.hub_outlined,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  if (!collapsed) ...[
                    const SizedBox(width: 10),
                    const Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TrackNet',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.8,
                              ),
                            ),
                            Text(
                              'CITYVISION',
                              style: TextStyle(
                                fontSize: 9,
                                color: mutedInk,
                                letterSpacing: 1.9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (!collapsed)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'WORKSPACE',
                  style: TextStyle(
                    fontSize: 9,
                    color: mutedInk,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: destinations.length,
              itemBuilder: (context, i) {
                final d = destinations[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Tooltip(
                    message: d.$2,
                    child: ListTile(
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: collapsed ? 14 : 12,
                      ),
                      selected: selected == i,
                      selectedTileColor: primaryInk.withValues(alpha: .12),
                      selectedColor: primaryInk,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      leading: Icon(d.$3, size: 20),
                      title: collapsed
                          ? null
                          : Text(
                              d.$2,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                      onTap: () {
                        if (Scaffold.of(context).isDrawerOpen) {
                          Navigator.pop(context);
                        }
                        context.go('/${d.$1}');
                      },
                    ),
                  ),
                );
              },
            ),
          ),
          if (!collapsed)
            Padding(
              padding: const EdgeInsets.all(22),
              child: Text(
                'Urban Intelligence\nSystem',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              IconButton(
                tooltip: 'Quick guide',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('TrackNet quick guide'),
                    content: SizedBox(
                      width: 450,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: headings.values
                              .map(
                                (h) => ListTile(
                                  title: Text(h.$2),
                                  subtitle: Text(h.$3),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.help_outline),
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],
      ),
    ),
  );
}

class TopBar extends ConsumerWidget {
  const TopBar({super.key, required this.heading, required this.desktop});
  final String heading;
  final bool desktop;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(metricsProvider),
        cams = ref.watch(camerasProvider),
        alerts = ref.watch(notificationsProvider),
        platform = ref.watch(dataProvider.select((d) => d?.platform));
    final off = cams.where((c) => c.status == CameraStatus.offline).toList();
    ref.listen<List<Alert>>(notificationsProvider, (previous, next) {
      if (previous != null && next.length > previous.length) {
        final fresh = next
            .where((a) => !previous.any((b) => b.id == a.id))
            .firstOrNull;
        if (fresh != null) {
          toast(
            context,
            '${fresh.priority.name.toUpperCase()} · ${fresh.plate ?? fresh.cameraId ?? fresh.id} · ${fresh.message}',
          );
        }
      }
    });
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!desktop)
                  Builder(
                    builder: (context) => IconButton(
                      tooltip: 'Open navigation',
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (c.maxWidth > 730)
                  Text(
                    m == null
                        ? 'Monitoring unavailable'
                        : 'Monitoring ${m.active}/${m.total}',
                    style: const TextStyle(fontSize: 11, color: mutedInk),
                  ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Locate offline camera',
                  child: TextButton(
                    onPressed: off.isEmpty
                        ? null
                        : () => context.go('/network?camera=${off.first.id}'),
                    child: Text(
                      m == null
                          ? 'Disconnected'
                          : off.isNotEmpty
                          ? '${off.length} cameras offline'
                          : cams.any((c) => c.status == CameraStatus.warning)
                          ? 'Camera warnings'
                          : 'Systems operational',
                      style: TextStyle(
                        fontSize: 11,
                        color: off.isNotEmpty ? critical : mutedInk,
                      ),
                    ),
                  ),
                ),
                if (c.maxWidth > 650) const LiveClock(),
                IconButton(
                  tooltip: 'Notifications',
                  icon: Badge(
                    label: Text('${alerts.length}'),
                    isLabelVisible: alerts.isNotEmpty,
                    child: const Icon(Icons.notifications_none_outlined),
                  ),
                  onPressed: () =>
                      showHeaderPanel(context, const NotificationPanel()),
                ),
                IconButton(
                  tooltip: 'Operator profile',
                  onPressed: () =>
                      showHeaderPanel(context, const OperatorPanel()),
                  icon: CircleAvatar(
                    radius: 16,
                    backgroundColor: neutralFill,
                    child: Text(
                      platform == null
                          ? '?'
                          : platform.operatorName
                                .split(' ')
                                .map((p) => p[0])
                                .take(2)
                                .join(),
                      style: const TextStyle(fontSize: 11, color: mutedInk),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class LiveClock extends ConsumerWidget {
  const LiveClock({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            clockText(now),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          Text(
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}',
            style: const TextStyle(fontSize: 9, color: mutedInk),
          ),
        ],
      ),
    );
  }
}

class SimulationButton extends ConsumerWidget {
  const SimulationButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demo = ref.watch(dataModeProvider) == DataMode.demo,
        sim = ref.watch(simulationProvider);
    return OutlinedButton.icon(
      onPressed: demo
          ? () => action(
              context,
              () => ref
                  .read(repositoryProvider)
                  .updateSettings(
                    ref.read(settingsProvider).copyWith(simulation: !sim),
                  ),
              sim ? 'Simulation paused' : 'Simulation resumed',
            )
          : null,
      icon: Icon(sim ? Icons.pause : Icons.play_arrow),
      label: Text(
        demo
            ? (sim ? 'Pause simulation' : 'Resume simulation')
            : 'Backend data',
      ),
    );
  }
}

class FeatureBody extends ConsumerWidget {
  const FeatureBody({super.key, required this.view, required this.child});
  final String view;
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final heading = headings[view]!;
    final reduceMotion =
        ref.watch(reduceMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final mobile = c.maxWidth < 650;
        return SingleChildScrollView(
          key: PageStorageKey(view),
          padding: EdgeInsets.all(mobile ? 16 : 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (heading.$1.isNotEmpty)
                Text(
                  heading.$1.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: mutedInk,
                    letterSpacing: 1.4,
                  ),
                ),
              if (heading.$1.isNotEmpty) const SizedBox(height: 8),
              Text(
                heading.$2,
                style: TextStyle(
                  fontSize: mobile ? 25 : 30,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1,
                ),
              ),
              if (heading.$3.isNotEmpty) const SizedBox(height: 8),
              if (heading.$3.isNotEmpty)
                Text(
                  heading.$3,
                  style: const TextStyle(fontSize: 12, color: mutedInk),
                ),
              if (view == 'dashboard')
                const Align(
                  alignment: Alignment.centerRight,
                  child: SimulationButton(),
                ),
              const SizedBox(height: 22),
              AnimatedPageEntrance(
                reduceMotion: reduceMotion,
                child: DataGate(view: view, child: child),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}
