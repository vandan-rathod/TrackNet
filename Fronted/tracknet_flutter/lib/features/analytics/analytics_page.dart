import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../shared_widgets/widgets.dart';
import '../../shared_widgets/camera_detail.dart';
import '../../map/city_map.dart';
import '../../charts/traffic_charts.dart';

class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = ref.watch(analyticsProvider),
        zones = ref.watch(zonesProvider),
        hour = ref.watch(hourProvider),
        selected = ref.watch(selectedZoneProvider),
        cam = ref.watch(selectedCameraProvider);
    if (a == null) return const EmptyState('No analytics available');
    void lens(int? h) => context.go(
      Uri(
        path: '/analytics',
        queryParameters: {
          ...ref.read(routeUriProvider).queryParameters,
          'hour': h?.toString() ?? 'now',
        },
      ).toString(),
    );
    final factor = hour == null
        ? 1.0
        : (a.volume[hour.clamp(0, 23)] / 1350 * 1.25).clamp(.3, 1.8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final h in [6, 9, null, 12, 18, 21])
              ChoiceChip(
                label: Text(
                  h == null ? 'Now' : '${h.toString().padLeft(2, '0')}:00',
                ),
                selected: hour == h,
                onSelected: (_) => lens(h),
              ),
          ],
        ),
        const SizedBox(height: 20),
        TwoColumns(
          ratio: 1,
          breakpoint: 760,
          main: TrafficChart(
            title: 'Traffic volume',
            values: a.volume,
            labels: List.generate(
              a.volume.length,
              (i) => i.toString().padLeft(2, '0'),
            ),
            selected: hour ?? DateTime.now().hour,
            onSelect: lens,
            unit: 'vehicles / hour',
          ),
          side: TrafficChart(
            title: 'Average vehicle speed',
            values: a.speed,
            labels: List.generate(
              a.speed.length,
              (i) => i.toString().padLeft(2, '0'),
            ),
            line: true,
            onSelect: lens,
            unit: 'km/h',
          ),
        ),
        const SizedBox(height: 20),
        TwoColumns(
          ratio: 1,
          breakpoint: 760,
          main: TrafficChart(
            title: 'Camera density',
            values: zones
                .map((z) => (a.cameraDensity[z.id] ?? 0).toDouble())
                .toList(),
            labels: zones
                .map(
                  (z) => z.name.replaceAll(' Road', '').replaceAll(' Area', ''),
                )
                .toList(),
            unit: 'cameras near zone',
            onSelect: (i) => context.go('/analytics?zone=${zones[i].id}'),
          ),
          side: TypeChart(counts: a.typeCounts),
        ),
        const SizedBox(height: 20),
        TwoColumns(
          main: const CityMap(height: 400),
          side: Panel(
            title: 'Zone traffic heat',
            child: Column(
              children: [
                for (final z in zones)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    selected: selected?.id == z.id,
                    title: Text(
                      z.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${a.cameraDensity[z.id] ?? 0} cams · ${(52 - (z.density * factor).clamp(.05, .98) * 34).round()} km/h',
                      style: const TextStyle(fontSize: 10),
                    ),
                    trailing: Text(
                      '${((z.density * factor).clamp(.05, .98) * 100).round()}%',
                    ),
                    onTap: () => context.go(
                      Uri(
                        path: '/analytics',
                        queryParameters: {
                          'zone': z.id,
                          'hour': hour?.toString() ?? 'now',
                        },
                      ).toString(),
                    ),
                  ),
                if (selected != null) ...[
                  const Divider(height: 20),
                  Facts({
                    'Zone': selected.name,
                    'Density':
                        '${((selected.density * factor).clamp(.05, .98) * 100).round()}%',
                    'Vehicles / min':
                        '${((selected.density * factor).clamp(.05, .98) * 120).round()}',
                    'Average speed':
                        '${(52 - (selected.density * factor).clamp(.05, .98) * 34).round()} km/h',
                  }),
                ],
              ],
            ),
          ),
        ),
        if (cam != null) ...[
          const SizedBox(height: 20),
          CameraDetail(camera: cam),
        ],
        const SizedBox(height: 20),
        FlowDiagram(
          flows: a.flows,
          zones: zones,
          selected: ref.watch(flowProvider),
          onSelect: (flow) {
            ref.read(flowProvider.notifier).state = flow;
            final layers = ref.read(mapLayersProvider('analytics'));
            if (!layers.flows) {
              ref.read(mapLayersProvider('analytics').notifier).state = layers
                  .toggle('OD routes');
            }
          },
        ),
      ],
    );
  }
}
