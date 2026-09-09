import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/domain.dart';
import '../../providers/providers.dart';
import '../../shared_widgets/widgets.dart';
import '../../map/city_map.dart';

class AlertsPage extends ConsumerWidget {
  const AlertsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(filteredAlertsProvider),
        all = ref.watch(notificationsProvider),
        filter = ref.watch(alertFilterProvider),
        selected = ref.watch(selectedAlertProvider);
    final cam = ref
        .watch(camerasProvider)
        .where((c) => c.id == selected?.cameraId)
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          runSpacing: 12,
          children: [
            FilterBar(
              options: const ['All', 'High', 'Medium', 'Low'],
              selected: filter == null
                  ? 'All'
                  : filter.name[0].toUpperCase() + filter.name.substring(1),
              counts: {
                'All': all.length,
                for (final p in Priority.values)
                  p.name[0].toUpperCase() + p.name.substring(1): all
                      .where((a) => a.priority == p)
                      .length,
              },
              onSelect: (s) => ref.read(alertFilterProvider.notifier).state =
                  s == 'All' ? null : Priority.values.byName(s.toLowerCase()),
            ),
            OutlinedButton.icon(
              onPressed: () => action(
                context,
                () => ref.read(repositoryProvider).resolveAll(),
                'Alert queue cleared',
              ),
              icon: const Icon(Icons.done_all),
              label: const Text('Resolve all'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TwoColumns(
          ratio: 1,
          main: Panel(
            title: 'Response queue',
            child: list.isEmpty
                ? const EmptyState(
                    'Queue clear',
                    message: 'No open alerts match this filter.',
                    icon: Icons.check_circle_outline,
                  )
                : Column(
                    children: [
                      for (final a in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: selected?.id == a.id,
                            leading: Icon(
                              a.kind == 'offline'
                                  ? Icons.wifi_off
                                  : Icons.flag_outlined,
                            ),
                            title: Text(
                              a.plate ?? a.cameraId ?? a.id,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              '${a.message}\n${clockText(a.timestamp)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: StatusBadge(a.priority.name),
                            onTap: () => context.go('/alerts?alert=${a.id}'),
                          ),
                        ),
                    ],
                  ),
          ),
          side: Column(
            children: [
              CityMap(height: 270, focus: cam?.point),
              const SizedBox(height: 20),
              Panel(
                title: 'Alert detail',
                child: selected == null
                    ? const EmptyState(
                        'No alert selected',
                        message: 'Choose an alert to inspect its record.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          StatusBadge(selected.priority.name),
                          const SizedBox(height: 12),
                          Text(
                            selected.message,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            selected.note,
                            style: const TextStyle(fontSize: 12, height: 1.6),
                          ),
                          const SizedBox(height: 18),
                          Facts({
                            'Record': selected.id,
                            'Status': selected.resolved ? 'Resolved' : 'Open',
                            'Plate': selected.plate ?? 'Not applicable',
                            'Camera': selected.cameraId ?? 'Unavailable',
                            'Location': cam?.name ?? 'Unavailable',
                            'Sighting time': clockText(selected.timestamp),
                          }),
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (selected.plate != null)
                                FilledButton(
                                  onPressed: () => context.go(
                                    '/vehicle?plate=${selected.plate}',
                                  ),
                                  child: const Text('Track vehicle'),
                                ),
                              if (selected.cameraId != null) ...[
                                OutlinedButton(
                                  onPressed: () => context.go(
                                    '/cameras?camera=${selected.cameraId}',
                                  ),
                                  child: const Text('Open live feed'),
                                ),
                                OutlinedButton(
                                  onPressed: () => context.go(
                                    '/network?camera=${selected.cameraId}',
                                  ),
                                  child: const Text('Show on map'),
                                ),
                              ],
                              if (cam?.status == CameraStatus.offline)
                                OutlinedButton(
                                  onPressed: () => action(
                                    context,
                                    () => ref
                                        .read(repositoryProvider)
                                        .reconnectCamera(cam!.id),
                                    'Camera reconnected',
                                  ),
                                  child: const Text('Reconnect camera'),
                                ),
                              if (!selected.resolved) ...[
                                OutlinedButton(
                                  onPressed: () => action(
                                    context,
                                    () => ref
                                        .read(repositoryProvider)
                                        .resolveAlert(selected.id),
                                    'Alert resolved',
                                  ),
                                  child: const Text('Mark resolved'),
                                ),
                                TextButton(
                                  onPressed: () => action(
                                    context,
                                    () => ref
                                        .read(repositoryProvider)
                                        .resolveAlert(selected.id),
                                    'Alert dismissed',
                                  ),
                                  child: const Text('Dismiss'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
