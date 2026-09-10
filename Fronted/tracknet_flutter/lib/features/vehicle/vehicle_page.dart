import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/providers.dart';
import '../../models/domain.dart';
import '../../models/plate.dart';
import '../../shared_widgets/widgets.dart';
import '../../shared_widgets/paged_table.dart';
import '../../shared_widgets/camera_detail.dart';
import '../../map/city_map.dart';

class VehiclePage extends ConsumerWidget {
  const VehiclePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plate = ref.watch(selectedPlateProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PlateSearch(),
        const SizedBox(height: 20),
        if (plate == null)
          const Panel(
            title: 'Vehicle intelligence',
            child: EmptyState(
              'No vehicle selected',
              message:
                  'Search a registration plate or choose a detection below.',
            ),
          )
        else
          ref
              .watch(journeyProvider(plate))
              .when(
                loading: () => const Panel(
                  title: 'Correlating camera records',
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (e, _) => Panel(
                  title: 'Search failed',
                  child: EmptyState(
                    'Unable to correlate records',
                    message: e.toString(),
                    action: TextButton(
                      onPressed: () => ref.invalidate(journeyProvider(plate)),
                      child: const Text('Retry search'),
                    ),
                  ),
                ),
                data: (journey) => journey == null
                    ? Panel(
                        title: 'Vehicle intelligence',
                        child: EmptyState(
                          'No records for $plate',
                          message: 'No correlated trajectory is available in the current index.',
                        ),
                      )
                    : JourneyView(key: ValueKey(plate), journey: journey),
              ),
        const SizedBox(height: 24),
        const DetectionTable(),
      ],
    );
  }
}

class PlateSearch extends ConsumerStatefulWidget {
  const PlateSearch({super.key});
  @override
  ConsumerState<PlateSearch> createState() => _PlateSearchState();
}

class _PlateSearchState extends ConsumerState<PlateSearch> {
  String? error;
  void search(String raw) {
    final p = PlateRecognition.normalize(raw);
    if (!PlateRecognition.valid(p)) {
      setState(
        () => error = 'Plate format not recognised. Expected an Indian registration plate with four trailing digits.',
      );
      return;
    }
    setState(() => error = null);
    ref.read(searchProvider.notifier).state = p;
    context.go(Uri(path: '/vehicle', queryParameters: {'plate': p}).toString());
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = ref.watch(suggestionsProvider);
    return Panel(
      title: 'Track a vehicle',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Autocomplete<Vehicle>(
            displayStringForOption: (v) => v.plate,
            optionsBuilder: (value) => suggestions.where(
              (v) => v.plate.contains(value.text.toUpperCase()),
            ),
            onSelected: (v) => search(v.plate),
            fieldViewBuilder: (context, controller, focus, submit) => TextField(
              controller: controller,
              focusNode: focus,
              onChanged: (s) => ref.read(searchProvider.notifier).state = s,
              onSubmitted: search,
              decoration: InputDecoration(
                labelText: 'Registration plate',
                hintText: 'Enter registration plate',
                prefixIcon: const Icon(Icons.search),
                errorText: error,
                suffixIcon: IconButton(
                  tooltip: 'Track vehicle',
                  onPressed: () => search(controller.text),
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: suggestions
                .map(
                  (v) => TextButton(
                    onPressed: () => search(v.plate),
                    child: Text(v.plate),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class JourneyView extends ConsumerStatefulWidget {
  const JourneyView({super.key, required this.journey});
  final Journey journey;
  @override
  ConsumerState<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends ConsumerState<JourneyView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _replay = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds:
          (widget.journey.duration.inMinutes * .62).clamp(6, 16).round() * 1000,
    ),
  );
  bool started = false;
  GeoPoint? focus;
  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.journey,
        cams = {for (final c in ref.watch(camerasProvider)) c.id: c},
        selected = ref.watch(selectedEventProvider);
    final reduced =
        ref.watch(reduceMotionProvider) ||
        MediaQuery.disableAnimationsOf(context);
    if (!started) {
      started = true;
      if (!reduced) {
        _replay.forward();
      } else {
        _replay.value = 1;
      }
    }
    if (reduced && _replay.isAnimating) {
      _replay.stop();
      _replay.value = 1;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          title: j.vehicle.plate,
          action: StatusBadge(j.vehicle.blacklisted ? 'Flagged' : 'Normal'),
          child: Facts({
            'Vehicle': j.vehicle.type,
            'First seen': clockText(j.events.first.timestamp),
            'Last seen': clockText(j.events.last.timestamp),
            'Cameras visited': '${j.cameraCount}',
            'Distance': '${j.distance.toStringAsFixed(1)} km',
            'Duration': '${j.duration.inMinutes} min',
            'Average speed': metric(j.averageSpeed, suffix: ' km/h'),
            'Reads': '${j.events.length}',
          }),
        ),
        const SizedBox(height: 20),
        TwoColumns(
          main: AnimatedBuilder(
            animation: _replay,
            builder: (context, _) => CityMap(
              journey: j,
              progress: Curves.easeOutExpo.transform(_replay.value),
              focus: focus,
              height: 430,
            ),
          ),
          side: Panel(
            title: 'Captured trajectory',
            action: IconButton(
              tooltip: 'Replay journey',
              onPressed: () {
                setState(() => focus = null);
                ref.read(selectedEventProvider.notifier).state = null;
                if (reduced) {
                  _replay.value = 1;
                } else {
                  _replay.forward(from: 0);
                }
              },
              icon: const Icon(Icons.replay),
            ),
            child: SizedBox(
              height: 470,
              child: AnimatedBuilder(
                animation: _replay,
                builder: (context, _) => ListView.builder(
                  itemCount: j.events.length,
                  itemBuilder: (context, i) {
                    final d = j.events[i], c = cams[d.cameraId];
                    final p = Curves.easeOutExpo.transform(_replay.value);
                    final threshold = j.duration.inMilliseconds == 0
                        ? 1.0
                        : d.timestamp
                                  .difference(j.events.first.timestamp)
                                  .inMilliseconds /
                              j.duration.inMilliseconds;
                    final next = i + 1 >= j.events.length
                        ? 1.1
                        : j.events[i + 1].timestamp
                                  .difference(j.events.first.timestamp)
                                  .inMilliseconds /
                              j.duration.inMilliseconds;
                    final active =
                        selected == d.id ||
                        (selected == null && p >= threshold && p < next);
                    return AnimatedContainer(
                      duration: Duration(milliseconds: reduced ? 0 : 180),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: active
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          title: Text(
                            '${clockText(d.timestamp)} · ${d.cameraId}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${c?.name ?? d.cameraId}\n${metric(d.speed)} km/h · OCR ${metric(d.confidence, decimals: 1)}%\n${d.status.label}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            _replay.stop();
                            ref.read(selectedEventProvider.notifier).state =
                                d.id;
                            setState(() => focus = c?.point);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class DetectionTable extends ConsumerWidget {
  const DetectionTable({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final q = ref.watch(detectionQueryProvider),
        rows = ref.watch(detectionRowsProvider),
        cams = {for (final c in ref.watch(camerasProvider)) c.id: c};
    void update(TableQuery v) =>
        ref.read(detectionQueryProvider.notifier).state = v;
    return Panel(
      title: 'City detection log',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilterBar(
            options: const ['All', 'Normal', 'Flagged', 'Blacklisted'],
            selected: q.filter,
            onSelect: (f) => update(q.copyWith(filter: f, page: 0)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: q.query,
            decoration: const InputDecoration(
              labelText: 'Search detections',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (s) => update(q.copyWith(query: s, page: 0)),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: ref.watch(reduceMotionProvider)
                ? Duration.zero
                : const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, child: child),
            ),
            child: PagedTable(
              key: ValueKey(
                '${q.query}|${q.filter}|${q.sort}|${q.ascending}|${q.page}|${q.pageSize}',
              ),
              columns: const [
                'Time',
                'Plate',
                'Type',
                'Camera',
                'Location',
                'Speed',
                'Confidence',
                'Status',
              ],
              rows: pageItems(rows, q)
                  .map(
                    (d) => DataRow(
                      onSelectChanged: (_) {
                        if (d.plate == null) {
                          showDetection(context, d);
                        } else {
                          context.go('/vehicle?plate=${d.plate}');
                        }
                      },
                      cells: [
                        DataCell(Text(clockText(d.timestamp))),
                        DataCell(Text(d.displayPlate)),
                        DataCell(Text(d.vehicleType ?? 'Unclassified')),
                        DataCell(Text(d.cameraId)),
                        DataCell(Text(cams[d.cameraId]?.name ?? 'Unavailable')),
                        DataCell(Text(metric(d.speed, suffix: ' km/h'))),
                        DataCell(
                          Text(metric(d.confidence, suffix: '%', decimals: 1)),
                        ),
                        DataCell(StatusBadge(d.status.label)),
                      ],
                    ),
                  )
                  .toList(),
              query: q,
              onQuery: update,
              total: rows.length,
            ),
          ),
        ],
      ),
    );
  }
}
