import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/domain.dart';
import '../../providers/providers.dart';
import '../../shared_widgets/widgets.dart';
import '../../animations/processing_indicator.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider),
        demo = ref.watch(dataModeProvider) == DataMode.demo,
        platform = ref.watch(dataProvider.select((d) => d?.platform)),
        reconnect = ref.watch(reconnectionProvider).value;
    void update(SettingsState s) => action(
      context,
      () => ref.read(repositoryProvider).updateSettings(s),
      'Settings updated',
    );
    return TwoColumns(
      ratio: 1,
      breakpoint: 800,
      main: Panel(
        title: 'Simulation behaviour',
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Live traffic simulation'),
              subtitle: const Text('Detections, counters and corridor drift'),
              value: settings.simulation,
              onChanged: demo
                  ? (v) => update(settings.copyWith(simulation: v))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ambient traffic particles'),
              value: settings.particles,
              onChanged: demo
                  ? (v) => update(settings.copyWith(particles: v))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Automatic alerts'),
              value: settings.automaticAlerts,
              onChanged: demo
                  ? (v) => update(settings.copyWith(automaticAlerts: v))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Camera feed engine'),
              value: settings.feeds,
              onChanged: demo
                  ? (v) => update(settings.copyWith(feeds: v))
                  : null,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Map ambient grid'),
              value: settings.grid,
              onChanged: (v) => update(settings.copyWith(grid: v)),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Reduce motion'),
              subtitle: const Text(
                'Also respects your device accessibility preference',
              ),
              value: ref.watch(reduceMotionProvider),
              onChanged: (v) =>
                  ref.read(reduceMotionProvider.notifier).state = v,
            ),
            const SizedBox(height: 14),
            Text(
              demo
                  ? 'All camera feeds, detections, trajectories and analytics are simulated client-side.'
                  : 'Backend Mode · simulation is disabled.',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      side: Panel(
        title: 'Platform status',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (platform == null)
              const EmptyState('No platform telemetry')
            else ...[
              Facts({
                'Engine': platform.engine,
                'Build': platform.build,
                'Cameras tracked': '${platform.camerasTracked}',
                'Simulation tick': '${platform.tick}',
                'Map tiles': platform.mapStatus,
                'Routes indexed': '${platform.routesIndexed}',
                'Alerts raised': '${platform.alertsRaised}',
              }),
              const SizedBox(height: 18),
              Consumer(
                builder: (context, ref, _) {
                  final now = ref.watch(clockProvider).value ?? DateTime.now();
                  final d = now.difference(platform.startedAt);
                  return Text(
                    'Uptime  ${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}',
                  );
                },
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: reconnect?.running == true
                  ? null
                  : () => action(
                      context,
                      () => ref.read(repositoryProvider).reconnectAll(),
                      'Reconnection workflow finished',
                    ),
              icon: const Icon(Icons.sync),
              label: const Text('Reconnect offline cameras'),
            ),
            if (reconnect != null && reconnect.message.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (reconnect.running)
                const ProcessingIndicator(label: 'Reconnecting cameras'),
              Text(reconnect.message),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: reconnect.total == 0
                    ? 1
                    : reconnect.completed.length / reconnect.total,
              ),
              for (final id in reconnect.completed)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(id),
                  subtitle: const Text('Connected successfully'),
                ),
            ],
            if (demo) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => action(
                  context,
                  () => ref.read(repositoryProvider).resetDemo(),
                  'Demo data reset',
                ),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset demo data'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
