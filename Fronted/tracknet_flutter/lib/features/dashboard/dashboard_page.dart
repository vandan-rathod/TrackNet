import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../models/domain.dart';
import '../../shared_widgets/widgets.dart';
import '../../shared_widgets/camera_detail.dart';
import '../../map/city_map.dart';
import '../../theme/app_theme.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCameraProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KpiRow(),
        const SizedBox(height: 22),
        TwoColumns(
          main: Column(
            children: [
              const CityMap(height: 430),
              if (selected != null) ...[
                const SizedBox(height: 20),
                CameraDetail(camera: selected),
              ],
            ],
          ),
          side: const LiveDetections(),
        ),
        const SizedBox(height: 20),
        const TopCameras(),
      ],
    );
  }
}

class KpiRow extends ConsumerWidget {
  const KpiRow({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = ref.watch(metricsProvider);
    if (m == null) return const EmptyState('No metrics available');
    final cards = [
      (
        'Active cameras',
        m.active.toDouble(),
        'of ${number(m.total)} cameras',
        'network',
        Icons.videocam_outlined,
      ),
      (
        'Vehicles detected',
        m.detected.toDouble(),
        'Network detections',
        'vehicle',
        Icons.directions_car_outlined,
      ),
      (
        'Plates recognized',
        m.recognized.toDouble(),
        'ANPR reads',
        'vehicle',
        Icons.document_scanner_outlined,
      ),
      (
        'Active alerts',
        m.alerts.toDouble(),
        'Response queue',
        'alerts',
        Icons.notifications_outlined,
      ),
      (
        'Average city speed',
        m.averageSpeed,
        'km/h · city network',
        'analytics',
        Icons.speed_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 900
            ? 5
            : c.maxWidth > 600
            ? 3
            : c.maxWidth > 400
            ? 2
            : 1;
        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: cards.indexed.map((entry) {
            final (index, item) = entry;
            return SizedBox(
              width: (c.maxWidth - 14 * (columns - 1)) / columns,
              child: KpiCard(
                label: item.$1,
                value: item.$2,
                note: item.$3,
                icon: item.$5,
                accent: index == 0,
                onTap: () => context.go('/${item.$4}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class KpiCard extends StatefulWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
    required this.onTap,
    this.accent = false,
  });
  final String label, note;
  final double value;
  final IconData icon;
  final VoidCallback onTap;
  final bool accent;
  @override
  State<KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<KpiCard> {
  double? previous;
  @override
  void didUpdateWidget(KpiCard old) {
    super.didUpdateWidget(old);
    previous = old.value;
  }

  @override
  Widget build(BuildContext context) => Card(
    color: Colors.white,
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(widget.icon, size: 19, color: mutedInk),
              ],
            ),
            const SizedBox(height: 22),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: previous ?? widget.value, end: widget.value),
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 700,
              ),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text(
                number(v),
                style: const TextStyle(
                  fontSize: 31,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.note,
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class LiveDetections extends ConsumerWidget {
  const LiveDetections({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dets = ref.watch(detectionsProvider),
        cams = {for (final c in ref.watch(camerasProvider)) c.id: c};
    return Panel(
      title: 'Live detections',
      action: Text(
        '${dets.length} reads',
        style: const TextStyle(fontSize: 10, color: mutedInk),
      ),
      child: SizedBox(
        height: 500,
        child: dets.isEmpty
            ? const EmptyState('No detections yet')
            : ListView.separated(
                itemCount: dets.take(16).length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (context, i) {
                  final d = dets[i];
                  return InkWell(
                    onTap: d.plate == null
                        ? () => showDetection(context, d)
                        : () => context.go('/vehicle?plate=${d.plate}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d.displayPlate,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              clockText(d.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: mutedInk,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          cams[d.cameraId]?.name ?? d.cameraId,
                          style: const TextStyle(fontSize: 10, color: mutedInk),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 7,
                          children: [
                            Text(
                              '${metric(d.speed)} km/h · ${metric(d.confidence, decimals: 1)}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                            if (d.status != DetectionStatus.normal)
                              StatusBadge(d.status.label),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class TopCameras extends ConsumerWidget {
  const TopCameras({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cams =
        ref
            .watch(camerasProvider)
            .where((c) => c.status != CameraStatus.offline)
            .toList()
          ..sort(
            (a, b) =>
                (b.vehiclesPerMinute ?? 0).compareTo(a.vehiclesPerMinute ?? 0),
          );
    return Panel(
      title: 'Top traffic cameras',
      action: IconButton(
        tooltip: 'Refresh top cameras',
        onPressed: () => action(
          context,
          () => ref.read(repositoryProvider).poll(),
          'Camera telemetry refreshed',
        ),
        icon: const Icon(Icons.refresh, size: 18),
      ),
      child: LayoutBuilder(
        builder: (context, c) => Wrap(
          spacing: 12,
          runSpacing: 8,
          children: cams
              .take(10)
              .map(
                (cam) => SizedBox(
                  width: c.maxWidth > 850
                      ? (c.maxWidth - 24) / 3
                      : c.maxWidth > 520
                      ? (c.maxWidth - 12) / 2
                      : c.maxWidth,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(
                      Icons.videocam_outlined,
                      color: mutedInk,
                    ),
                    title: Text(
                      cam.id,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      cam.name,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      '${cam.vehiclesPerMinute}\nvpm',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: () => context.go('/dashboard?camera=${cam.id}'),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
