import 'package:flutter/material.dart';

import '../models/domain.dart';
import '../theme/app_theme.dart';
import 'top_notice.dart';

String number(num value) {
  final s = value.round().toString();
  if (s.length <= 3) return s;
  final end = s.substring(s.length - 3);
  var head = s.substring(0, s.length - 3);
  final groups = <String>[];
  while (head.length > 2) {
    groups.insert(0, head.substring(head.length - 2));
    head = head.substring(0, head.length - 2);
  }
  groups.insert(0, head);
  return '${groups.join(',')},$end';
}

String clockText(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
String ago(DateTime? d) {
  if (d == null) return 'No reads';
  final s = DateTime.now().difference(d).inSeconds.clamp(0, 99999999);
  return s < 60
      ? '${s}s ago'
      : s < 3600
      ? '${(s / 60).round()} min ago'
      : '${(s / 3600).round()} h ago';
}

String metric(num? n, {String suffix = '', int decimals = 0}) =>
    n == null ? '—' : '${n.toStringAsFixed(decimals)}$suffix';
void toast(BuildContext context, String message) {
  showTopNotice(context, message);
}

Future<void> action(
  BuildContext context,
  Future<void> Function() task,
  String message,
) async {
  try {
    await task();
    if (context.mounted) toast(context, message);
  } catch (e) {
    if (context.mounted) toast(context, e.toString());
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding = const EdgeInsets.all(20),
  });
  final String title;
  final Widget child;
  final Widget? action;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ],
    ),
    child: Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
    this.title, {
    super.key,
    this.message = '',
    this.icon = Icons.search,
    this.action,
  });
  final String title, message;
  final IconData icon;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(28),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 36, color: mutedInk),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    final l = label.toLowerCase();
    final color =
        l.contains('offline') || l == 'high' || l.contains('blacklist')
        ? critical
        : l.contains('warn') || l == 'medium' || l.contains('flag')
        ? warningAccent
        : l == 'online' || l == 'normal'
        ? successAccent
        : mutedInk;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class Facts extends StatelessWidget {
  const Facts(this.values, {super.key});
  final Map<String, String> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Wrap(
      spacing: 14,
      runSpacing: 18,
      children: values.entries
          .map(
            (e) => SizedBox(
              width: (c.maxWidth - 14) / 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.key,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    e.value,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    ),
  );
}

class TwoColumns extends StatelessWidget {
  const TwoColumns({
    super.key,
    required this.main,
    required this.side,
    this.breakpoint = 900,
    this.ratio = 2,
  });
  final Widget main, side;
  final double breakpoint;
  final int ratio;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => c.maxWidth < breakpoint
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, const SizedBox(height: 20), side],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: ratio, child: main),
              const SizedBox(width: 20),
              Expanded(child: side),
            ],
          ),
  );
}

class FilterBar extends StatelessWidget {
  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
    this.counts = const {},
  });
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;
  final Map<String, int> counts;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: options
        .map(
          (o) => ChoiceChip(
            label: Text(counts.containsKey(o) ? '$o  ${counts[o]}' : o),
            selected: selected == o,
            onSelected: (_) => onSelect(o),
          ),
        )
        .toList(),
  );
}

class AsyncStatePanel extends StatelessWidget {
  const AsyncStatePanel(this.state, {super.key, required this.retry});
  final RepositoryState state;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Panel(
    title: 'Data connection',
    child: state.availability == Availability.loading
        ? const Padding(
            padding: EdgeInsets.all(50),
            child: Center(child: CircularProgressIndicator()),
          )
        : EmptyState(
            switch (state.availability) {
              Availability.disconnected => 'Backend disconnected',
              Availability.offline => 'Backend offline',
              Availability.error => 'Unable to load data',
              Availability.empty => 'No records available',
              _ => 'Loading',
            },
            message:
                state.message ??
                'The connected source has not provided data yet.',
            icon: Icons.cloud_off_outlined,
            action: OutlinedButton.icon(
              onPressed: retry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
  );
}
