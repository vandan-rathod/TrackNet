import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../models/domain.dart';
import '../../shared_widgets/widgets.dart';
import '../../shared_widgets/paged_table.dart';
import '../../shared_widgets/camera_detail.dart';
import '../../map/city_map.dart';

class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(networkQueryProvider),
        rows = ref.watch(networkRowsProvider),
        all = ref.watch(camerasProvider),
        selected = ref.watch(selectedCameraProvider);
    void update(TableQuery v) =>
        ref.read(networkQueryProvider.notifier).state = v;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: 'Camera registry',
          action: IconButton(
            tooltip: 'Poll registry',
            onPressed: () => action(
              context,
              () => ref.read(repositoryProvider).poll(),
              'Registry polled',
            ),
            icon: const Icon(Icons.refresh),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilterBar(
                options: const ['All', 'Online', 'Warning', 'Offline'],
                selected: q.filter,
                counts: {
                  'All': all.length,
                  'Online': all
                      .where((c) => c.status == CameraStatus.online)
                      .length,
                  'Warning': all
                      .where((c) => c.status == CameraStatus.warning)
                      .length,
                  'Offline': all
                      .where((c) => c.status == CameraStatus.offline)
                      .length,
                },
                onSelect: (f) => update(q.copyWith(filter: f, page: 0)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                initialValue: q.query,
                decoration: const InputDecoration(
                  labelText: 'Search camera / location',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (s) => update(q.copyWith(query: s, page: 0)),
              ),
              const SizedBox(height: 16),
              PagedTable(
                columns: const [
                  'Camera',
                  'Location',
                  'Status',
                  'Vehicles/min',
                  'Avg speed',
                  'ANPR accuracy',
                  'Last detection',
                ],
                rows: pageItems(rows, q)
                    .map(
                      (c) => DataRow(
                        selected: selected?.id == c.id,
                        onSelectChanged: (_) =>
                            context.go('/network?camera=${c.id}'),
                        cells: [
                          DataCell(Text(c.id)),
                          DataCell(Text(c.name)),
                          DataCell(StatusBadge(c.status.name)),
                          DataCell(
                            Text(
                              c.status == CameraStatus.offline
                                  ? '—'
                                  : metric(c.vehiclesPerMinute),
                            ),
                          ),
                          DataCell(
                            Text(
                              c.status == CameraStatus.offline
                                  ? '—'
                                  : metric(c.speed, suffix: ' km/h'),
                            ),
                          ),
                          DataCell(
                            Text(metric(c.accuracy, decimals: 1, suffix: '%')),
                          ),
                          DataCell(Text(ago(c.lastSeen))),
                        ],
                      ),
                    )
                    .toList(),
                query: q,
                onQuery: update,
                total: rows.length,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TwoColumns(
          main: const CityMap(height: 380),
          side: selected == null
              ? const Panel(
                  title: 'Camera detail',
                  child: EmptyState(
                    'Select a camera',
                    message: 'Choose a registry row or map marker.',
                  ),
                )
              : CameraDetail(camera: selected),
        ),
      ],
    );
  }
}
