import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../models/domain.dart';
import '../../providers/providers.dart';
import '../../shared_widgets/widgets.dart';
import '../../theme/app_theme.dart';

class FeedView extends ConsumerStatefulWidget {
  const FeedView({
    super.key,
    required this.camera,
    required this.feed,
    this.height = 165,
  });
  final Camera camera;
  final CameraFeed feed;
  final double height;
  @override
  ConsumerState<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends ConsumerState<FeedView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 100),
  );
  bool _visible = true;
  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(settingsProvider.select((s) => s.feeds)),
        reduced =
            ref.watch(reduceMotionProvider) ||
            MediaQuery.disableAnimationsOf(context);
    final offline = widget.camera.status == CameraStatus.offline;
    final animate =
        _visible && enabled && !reduced && !offline && widget.feed.available;
    if (animate && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!animate && _motion.isAnimating) {
      _motion.stop();
    }
    return VisibilityDetector(
      key: ValueKey('feed-${widget.camera.id}-${widget.height}'),
      onVisibilityChanged: (v) {
        if (mounted && _visible != (v.visibleFraction > 0)) {
          setState(() => _visible = v.visibleFraction > 0);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          height: widget.height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (widget.feed.available && !offline)
                AnimatedBuilder(
                  animation: _motion,
                  builder: (context, _) => CustomPaint(
                    painter: FeedPainter(widget.feed, _motion.value * 100),
                  ),
                )
              else
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off_outlined),
                        const SizedBox(height: 6),
                        Text(offline ? 'Signal lost' : widget.feed.message),
                      ],
                    ),
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    Text(
                      widget.camera.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    StatusBadge(widget.camera.status.name),
                  ],
                ),
              ),
              if (!offline)
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Row(
                    children: [
                      Text(
                        enabled ? 'REC · ANPR' : 'Feed engine paused',
                        style: const TextStyle(fontSize: 10, color: mutedInk),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          widget.camera.lastPlate ?? 'No reads',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedPainter extends CustomPainter {
  FeedPainter(this.feed, this.elapsed);
  final CameraFeed feed;
  final double elapsed;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfff4f4f5),
    );
    final edge = Paint()
      ..color = mutedInk.withValues(alpha: .22)
      ..strokeWidth = 1;
    for (final x in [.06, .5, .94]) {
      canvas.drawLine(Offset(w * x, 0), Offset(w * (.3 + x * .4), h), edge);
    }
    for (var i = 0; i < 6; i++) {
      final y = (i / 6 * h + h * elapsed * .09) % (h + 40) - 20;
      canvas.drawRect(
        Rect.fromLTWH(w * .5 - 2, y, 4, 14),
        Paint()..color = neutralFill,
      );
    }
    for (final car in feed.cars) {
      final x =
              ((car.position + car.direction * car.speed * elapsed * .16) % 1) *
              w,
          y = car.lane == 0 ? h * .42 : h * .58;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, y + 3, car.width, car.height),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.black12,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, car.width, car.height),
          const Radius.circular(3),
        ),
        Paint()..color = Color(car.color),
      );
      canvas.drawRect(
        Rect.fromLTWH(
          x + car.width * .4,
          y + 2,
          car.width * .3,
          car.height - 4,
        ),
        Paint()..color = mutedInk.withValues(alpha: .65),
      );
      canvas.drawRect(
        Rect.fromLTWH(x + (car.direction > 0 ? car.width - 2 : 0), y + 2, 2, 3),
        Paint()..color = Colors.amber.shade100,
      );
    }
  }

  @override
  bool shouldRepaint(FeedPainter old) =>
      old.elapsed != elapsed || old.feed != feed;
}
