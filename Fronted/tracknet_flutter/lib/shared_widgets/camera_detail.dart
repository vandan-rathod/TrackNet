import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/domain.dart';
import '../providers/providers.dart';
import '../features/cameras/camera_feed.dart';
import 'widgets.dart';

class CameraDetail extends ConsumerWidget {
  const CameraDetail({super.key, required this.camera, this.showFeed = false});
  final Camera camera;
  final bool showFeed;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c =
        ref
            .watch(camerasProvider)
            .where((c) => c.id == camera.id)
            .firstOrNull ??
        camera;
    final reads = ref
        .watch(detectionsProvider)
        .where((d) => d.cameraId == c.id)
        .take(10)
        .toList();
    return Panel(
      title: c.id,
      action: StatusBadge(c.status.name),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(c.name),
          const SizedBox(height: 16),
          if (showFeed) ...[
            ref
                .watch(cameraFeedProvider(c.id))
                .when(
                  data: (feed) => FeedView(camera: c, feed: feed, height: 230),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) =>
                      EmptyState('Feed unavailable', message: e.toString()),
                ),
            const SizedBox(height: 16),
          ],
          Facts({
            'Vehicles / min': metric(c.vehiclesPerMinute),
            'Average speed': metric(c.speed, suffix: ' km/h'),
            'ANPR accuracy': metric(c.accuracy, suffix: '%', decimals: 1),
            'Last plate': c.lastPlate ?? 'No reads',
            'Last detection': ago(c.lastSeen),
            'Zone':
                ref
                    .watch(zonesProvider)
                    .where((z) => z.id == c.zoneId)
                    .firstOrNull
                    ?.name ??
                c.zoneId,
          }),
          if (c.status == CameraStatus.offline) ...[
            const SizedBox(height: 16),
            const Text('Connection timeout · no camera signal'),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (c.status == CameraStatus.offline)
                FilledButton.icon(
                  onPressed: () => action(
                    context,
                    () => ref.read(repositoryProvider).reconnectCamera(c.id),
                    '${c.id} reconnected',
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reconnect'),
                ),
              OutlinedButton.icon(
                onPressed: () => context.go('/network?camera=${c.id}'),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Show on map'),
              ),
              if (!showFeed)
                OutlinedButton.icon(
                  onPressed: () => context.go('/cameras?camera=${c.id}'),
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('Open feed'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Recent reads',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          if (reads.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No reads in this retention window.'),
            ),
          for (final d in reads)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(d.displayPlate),
              subtitle: Text(
                '${clockText(d.timestamp)} · ${d.vehicleType ?? 'Unclassified'}',
              ),
              trailing: Text(metric(d.confidence, suffix: '%', decimals: 1)),
              onTap: d.plate == null
                  ? () => showDetection(context, d)
                  : () => context.go(
                      Uri(
                        path: '/vehicle',
                        queryParameters: {'plate': d.plate!},
                      ).toString(),
                    ),
            ),
        ],
      ),
    );
  }
}

void showDetection(BuildContext context, Detection d) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text(d.status.label),
    content: SingleChildScrollView(
      child: Facts({
        'Camera': d.cameraId,
        'Timestamp': d.timestamp.toIso8601String(),
        'Confidence': metric(d.confidence, suffix: '%', decimals: 1),
        'Raw OCR': d.rawOcr ?? 'Unavailable',
        'Context': d.context,
        'Accepted plate': d.plate ?? 'Unreadable / absent',
      }),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
    ],
  ),
);
