import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/domain.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../shared_widgets/widgets.dart';

class CityMap extends ConsumerStatefulWidget {
  const CityMap({
    super.key,
    this.height = 440,
    this.journey,
    this.progress = 1,
    this.focus,
  });
  final double height, progress;
  final Journey? journey;
  final GeoPoint? focus;
  @override
  ConsumerState<CityMap> createState() => _CityMapState();
}

class _CityMapState extends ConsumerState<CityMap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  );
  final _transform = TransformationController();
  bool _visible = true;
  GeoPoint? _lastFocus;
  int _offlineIndex = 0;
  @override
  void dispose() {
    _motion.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _focus(GeoPoint p, Size size) {
    final at = MapProjection(size, ref.read(dataProvider)!).project(p);
    _transform.value = Matrix4.identity()
      ..translateByDouble(
        size.width / 2 - at.dx * 2.2,
        size.height / 2 - at.dy * 2.2,
        0,
        1,
      )
      ..scaleByDouble(2.2, 2.2, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataProvider);
    if (data == null || data.roads.isEmpty) {
      return const Panel(
        title: 'City map',
        child: EmptyState(
          'No map data',
          message: 'Waiting for source geometry.',
          icon: Icons.map_outlined,
        ),
      );
    }
    final view = ref.watch(selectedViewProvider),
        layers = ref.watch(mapLayersProvider(ref.watch(selectedViewProvider)));
    final selected = ref.watch(selectedCameraProvider),
        zone = ref.watch(selectedZoneProvider),
        flow = ref.watch(flowProvider);
    final reduced =
        ref.watch(reduceMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    final animate =
        _visible &&
        !reduced &&
        data.settings.particles &&
        data.settings.simulation &&
        layers.vehicles;
    if (animate && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!animate && _motion.isAnimating) {
      _motion.stop();
    }
    final hour = ref.watch(hourProvider);
    final factor = hour == null || data.analytics == null
        ? 1.0
        : (data.analytics!.volume[hour.clamp(0, 23)] / 1350 * 1.25).clamp(
            .3,
            1.8,
          );
    return Panel(
      title: 'City network',
      action: IconButton(
        tooltip: 'Reset map view',
        onPressed: () => _transform.value = Matrix4.identity(),
        icon: const Icon(Icons.center_focus_strong),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final e in {
                'Cameras': layers.cameras,
                'Vehicles': layers.vehicles,
                'Zones': layers.zones,
                'Heat': layers.heat,
                'OD routes': layers.flows,
              }.entries)
                FilterChip(
                  label: Text(e.key),
                  selected: e.value,
                  onSelected: (_) =>
                      ref.read(mapLayersProvider(view).notifier).state = layers
                          .toggle(e.key),
                ),
              ActionChip(
                avatar: const Icon(Icons.wifi_off, size: 15, color: critical),
                label: Text(
                  'Offline (${data.cameras.where((c) => c.status == CameraStatus.offline).length})',
                ),
                onPressed: () {
                  final off = data.cameras
                      .where((c) => c.status == CameraStatus.offline)
                      .toList();
                  if (off.isEmpty) {
                    toast(context, 'No offline cameras');
                    return;
                  }
                  final c = off[_offlineIndex++ % off.length];
                  context.go(
                    Uri(
                      path: '/$view',
                      queryParameters: {
                        ...ref.read(routeUriProvider).queryParameters,
                        'camera': c.id,
                      },
                    ).toString(),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: VisibilityDetector(
              key: ValueKey('map-$view'),
              onVisibilityChanged: (v) {
                if (mounted && _visible != (v.visibleFraction > 0)) {
                  setState(() => _visible = v.visibleFraction > 0);
                }
              },
              child: SizedBox(
                height: widget.height,
                child: LayoutBuilder(
                  builder: (context, c) {
                    final size = Size(c.maxWidth, c.maxHeight);
                    final focus =
                        widget.focus ?? selected?.point ?? zone?.center;
                    if (focus != null && focus != _lastFocus) {
                      _lastFocus = focus;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _focus(focus, size);
                      });
                    }
                    return Stack(
                      children: [
                        InteractiveViewer(
                          transformationController: _transform,
                          // Wheel/trackpad scrolling belongs to the page.
                          // Keep pinch gestures and the explicit zoom buttons.
                          scaleFactor: double.infinity,
                          trackpadScrollCausesScale: true,
                          minScale: .6,
                          maxScale: 12,
                          constrained: true,
                          boundaryMargin: const EdgeInsets.all(400),
                          child: GestureDetector(
                            onTapUp: (details) {
                              final p = details.localPosition;
                              final projection = MapProjection(size, data);
                              if (layers.cameras) {
                                Camera? nearest;
                                var distance = 18.0;
                                for (final cam in data.cameras) {
                                  final d = (projection.project(cam.point) - p)
                                      .distance;
                                  if (d < distance) {
                                    distance = d;
                                    nearest = cam;
                                  }
                                }
                                if (nearest != null) {
                                  context.go(
                                    Uri(
                                      path: '/$view',
                                      queryParameters: {
                                        ...ref
                                            .read(routeUriProvider)
                                            .queryParameters,
                                        'camera': nearest.id,
                                      },
                                    ).toString(),
                                  );
                                  return;
                                }
                              }
                              if (layers.zones) {
                                Zone? nearest;
                                var distance = 40.0;
                                for (final z in data.zones) {
                                  final d = (projection.project(z.center) - p)
                                      .distance;
                                  if (d < distance) {
                                    distance = d;
                                    nearest = z;
                                  }
                                }
                                if (nearest != null) {
                                  context.go(
                                    Uri(
                                      path: '/analytics',
                                      queryParameters: {'zone': nearest.id},
                                    ).toString(),
                                  );
                                }
                              }
                            },
                            child: AnimatedBuilder(
                              animation: _motion,
                              builder: (context, _) => CustomPaint(
                                size: size,
                                painter: CityPainter(
                                  data: data,
                                  layers: layers,
                                  selected: selected?.id,
                                  journey: widget.journey,
                                  progress: widget.progress,
                                  elapsed: _motion.value * 60,
                                  factor: factor,
                                  flow: flow,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 8,
                          top: 8,
                          child: Column(
                            children: [
                              IconButton.filledTonal(
                                tooltip: 'Zoom in',
                                onPressed: () =>
                                    _transform.value = _transform.value.clone()
                                      ..scaleByDouble(1.25, 1.25, 1, 1),
                                icon: const Icon(Icons.add),
                              ),
                              const SizedBox(height: 4),
                              IconButton.filledTonal(
                                tooltip: 'Zoom out',
                                onPressed: () =>
                                    _transform.value = _transform.value.clone()
                                      ..scaleByDouble(.8, .8, 1, 1),
                                icon: const Icon(Icons.remove),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 8,
                          child: Wrap(
                            spacing: 10,
                            children: const [
                              StatusBadge('Low'),
                              StatusBadge('Medium'),
                              StatusBadge('High'),
                              StatusBadge('Offline'),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text(
              'TrackNet GIS · vector map · drag to pan / use + or − to zoom',
              style: TextStyle(fontSize: 10, color: mutedInk),
            ),
          ),
        ],
      ),
    );
  }
}

class MapProjection {
  MapProjection(this.size, DashboardData data) {
    final points = [
      ...data.roads.expand((r) => r.points),
      ...data.shapes.expand((s) => s.points),
      ...data.cameras.map((c) => c.point),
    ];
    minLat = points.map((p) => p.lat).reduce(math.min);
    maxLat = points.map((p) => p.lat).reduce(math.max);
    minLng = points.map((p) => p.lng).reduce(math.min);
    maxLng = points.map((p) => p.lng).reduce(math.max);
    final latPad = math.max((maxLat - minLat) * .06, .00001),
        lngPad = math.max((maxLng - minLng) * .06, .00001);
    minLat -= latPad;
    maxLat += latPad;
    minLng -= lngPad;
    maxLng += lngPad;
  }
  final Size size;
  late double minLat, maxLat, minLng, maxLng;
  double get latSpan => maxLat - minLat;
  Offset project(GeoPoint p) => Offset(
    (p.lng - minLng) / (maxLng - minLng) * size.width,
    (maxLat - p.lat) / latSpan * size.height,
  );
}

class CityPainter extends CustomPainter {
  CityPainter({
    required this.data,
    required this.layers,
    required this.elapsed,
    required this.factor,
    this.selected,
    this.journey,
    this.progress = 1,
    this.flow,
  });
  final DashboardData data;
  final MapLayerState layers;
  final String? selected;
  final Journey? journey;
  final double progress, elapsed, factor;
  final OdFlow? flow;
  @override
  void paint(Canvas canvas, Size size) {
    final projection = MapProjection(size, data);
    Offset p(GeoPoint a) => projection.project(a);
    void line(
      List<GeoPoint> pts,
      Color color,
      double width, {
      bool close = false,
    }) {
      if (pts.isEmpty) return;
      final path = Path()..moveTo(p(pts.first).dx, p(pts.first).dy);
      for (final pt in pts.skip(1)) {
        path.lineTo(p(pt).dx, p(pt).dy);
      }
      if (close) path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = (close ? PaintingStyle.fill : PaintingStyle.stroke)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xfffafafa),
    );
    for (final s in data.shapes) {
      if (s.kind == 'landmark') continue;
      if (s.width == 2 && !data.settings.grid) continue;
      final color = s.kind == 'polygon'
          ? (s.width == 1.5 ? const Color(0xffe4e4e7) : neutralFill)
          : s.width >= 30
          ? const Color(0xffd4d4d8)
          : s.width >= 12
          ? mutedInk
          : s.width >= 6
          ? const Color(0xffe4e4e7)
          : s.width == 4
          ? Colors.white
          : const Color(0xffe4e4e7);
      line(
        s.points,
        color.withValues(alpha: .9),
        s.width * .5,
        close: s.kind == 'polygon',
      );
    }
    if (layers.zones) {
      for (final z in data.zones) {
        final d = (z.density * factor).clamp(.05, .98),
            r = z.radius / projection.latSpan * size.height;
        final color = d > .62
            ? critical
            : d > .4
            ? warningAccent
            : primaryInk;
        canvas.drawCircle(
          p(z.center),
          r,
          Paint()..color = color.withValues(alpha: .12),
        );
        canvas.drawCircle(
          p(z.center),
          r,
          Paint()
            ..color = color.withValues(alpha: .5)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    for (final r in data.roads) {
      line(r.points, Colors.white, 7);
      final zone = data.zones.where((z) => z.id == r.zoneId).firstOrNull;
      final d = (zone?.density ?? 0) * factor;
      line(
        r.points,
        layers.heat
            ? (d > .62
                  ? critical
                  : d > .4
                  ? warningAccent
                  : primaryInk)
            : const Color(0xffa1a1aa),
        2.5,
      );
    }
    if (layers.flows && flow != null) {
      final a = data.zones.where((z) => z.id == flow!.origin).firstOrNull,
          b = data.zones.where((z) => z.id == flow!.destination).firstOrNull;
      if (a != null && b != null) {
        line(
          [
            a.center,
            GeoPoint(
              (a.center.lat + b.center.lat) / 2 + .004,
              (a.center.lng + b.center.lng) / 2 + .004,
            ),
            b.center,
          ],
          warningAccent,
          4,
        );
      }
    }
    if (layers.vehicles) {
      for (final particle in data.particles) {
        final road = data.roads
            .where((r) => r.id == particle.roadId)
            .firstOrNull;
        if (road == null) continue;
        final t =
            (particle.position +
                particle.direction *
                    elapsed *
                    particle.speed /
                    (pathLength(road.points) * 111) /
                    3600 *
                    3.2) %
            1;
        canvas.drawCircle(
          p(pointAlong(road.points, t)),
          2.5,
          Paint()..color = mutedInk,
        );
      }
    }
    if (journey != null && journey!.path.isNotEmpty) {
      line(journey!.path, primaryInk.withValues(alpha: .2), 9);
      line(journey!.path, primaryInk, 3);
      canvas.drawCircle(
        p(pointAlong(journey!.path, progress)),
        7,
        Paint()..color = warningAccent,
      );
    }
    if (layers.cameras) {
      for (final c in data.cameras) {
        final col = switch (c.status) {
          CameraStatus.online => successAccent,
          CameraStatus.warning => warningAccent,
          CameraStatus.offline => critical,
        };
        final at = p(c.point);
        if (c.id == selected) {
          canvas.drawCircle(
            at,
            12,
            Paint()..color = col.withValues(alpha: .23),
          );
        }
        canvas.drawCircle(
          at,
          c.status == CameraStatus.offline ? 5 : 3,
          Paint()..color = col,
        );
        if (c.status == CameraStatus.offline) {
          final text = TextPainter(
            text: TextSpan(
              text: 'OFFLINE ${c.id}',
              style: const TextStyle(
                fontSize: 9,
                color: critical,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          text.paint(canvas, at + const Offset(7, -12));
        }
      }
    }
    for (final s in data.shapes.where((s) => s.kind == 'landmark')) {
      final text = TextPainter(
        text: TextSpan(
          text: (s.name ?? '')
              .replaceAll(
                RegExp(
                  r'[\u{1F000}-\u{1FAFF}\u2600-\u27BF\uFE0F]',
                  unicode: true,
                ),
                '',
              )
              .trim(),
          style: TextStyle(
            fontSize: 9,
            color: mutedInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 135);
      final at = p(s.points.first);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: at, width: 5, height: 5),
          const Radius.circular(1),
        ),
        Paint()..color = mutedInk,
      );
      text.paint(
        canvas,
        Offset(
          (at.dx + 7).clamp(0, math.max(0, size.width - text.width)),
          (at.dy + 7).clamp(0, math.max(0, size.height - text.height)),
        ),
      );
    }
  }

  @override
  bool shouldRepaint(CityPainter old) => true;
}
