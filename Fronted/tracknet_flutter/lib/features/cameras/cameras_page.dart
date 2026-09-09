import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../shared_widgets/widgets.dart';
import '../../shared_widgets/camera_detail.dart';
import 'camera_feed.dart';

class CamerasPage extends ConsumerWidget {
  const CamerasPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataProvider),
        selected = ref.watch(selectedCameraProvider);
    if (data == null) return const EmptyState('No camera data');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: () => action(
              context,
              () => ref.read(repositoryProvider).cycleFeeds(),
              'Camera feeds cycled',
            ),
            icon: const Icon(Icons.sync),
            label: const Text('Cycle feeds'),
          ),
        ),
        const SizedBox(height: 12),
        if (selected != null) ...[
          CameraDetail(camera: selected, showFeed: true),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.go('/cameras'),
              child: const Text('Close inspection'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (data.feeds.isEmpty)
          const EmptyState(
            'No streams available',
            message: 'The data source has not supplied camera previews.',
          ),
        LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth > 1150
                ? 4
                : c.maxWidth > 800
                ? 3
                : c.maxWidth > 540
                ? 2
                : 1;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: data.feeds.map((feed) {
                final cam = data.cameras
                    .where((c) => c.id == feed.cameraId)
                    .firstOrNull;
                if (cam == null) return const SizedBox.shrink();
                return SizedBox(
                  width: (c.maxWidth - (columns - 1) * 16) / columns,
                  child: Card(
                    child: InkWell(
                      onTap: () => context.go('/cameras?camera=${cam.id}'),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FeedView(camera: cam, feed: feed),
                            const SizedBox(height: 12),
                            Text(
                              '${cam.id} · ${cam.name}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${metric(cam.vehiclesPerMinute)} /min  ·  ${metric(cam.speed)} km/h  ·  ${metric(cam.accuracy, decimals: 1)}%',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
