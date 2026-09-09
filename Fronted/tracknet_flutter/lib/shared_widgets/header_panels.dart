import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../theme/app_theme.dart';
import 'widgets.dart';

Future<void> showHeaderPanel(BuildContext context, Widget child) =>
    showDialog<void>(
      context: context,
      barrierColor: Colors.black12,
      builder: (context) => Dialog(
        alignment: Alignment.topRight,
        insetPadding: const EdgeInsets.fromLTRB(16, 72, 16, 16),
        child: SizedBox(width: 380, child: child),
      ),
    );

class PanelHeading extends StatelessWidget {
  const PanelHeading(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: mutedInk),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close panel',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

class NotificationPanel extends ConsumerWidget {
  const NotificationPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(notificationsProvider).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PanelHeading('Notifications', subtitle: '${alerts.length} open alerts'),
        const Divider(),
        Flexible(
          child: alerts.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: EmptyState(
                    'You’re all caught up',
                    message: 'No open alerts.',
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) =>
                      const Divider(indent: 20, endIndent: 20),
                  itemBuilder: (context, i) {
                    final alert = alerts[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              alert.plate ?? alert.cameraId ?? alert.id,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          StatusBadge(alert.priority.name),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              alert.message,
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ago(alert.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: mutedInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                      onTap: () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.go(
                          Uri(
                            path: '/alerts',
                            queryParameters: {'alert': alert.id},
                          ).toString(),
                        );
                      },
                    );
                  },
                ),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                final router = GoRouter.of(context);
                Navigator.pop(context);
                router.go('/alerts');
              },
              child: const Text('View all alerts'),
            ),
          ),
        ),
      ],
    );
  }
}

class OperatorPanel extends ConsumerWidget {
  const OperatorPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(dataProvider.select((d) => d?.platform));
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PanelHeading('Operator profile'),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(20),
          child: profile == null
              ? const EmptyState(
                  'Profile unavailable',
                  message: 'No operator details have been supplied.',
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: neutralFill,
                      child: Icon(Icons.person_outline, color: primaryInk),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.operatorName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            profile.operatorDetail,
                            style: const TextStyle(
                              fontSize: 12,
                              color: mutedInk,
                              height: 1.5,
                            ),
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
