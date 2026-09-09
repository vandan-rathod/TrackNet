import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../routing/router.dart';
import '../theme/app_theme.dart';
import '../animations/boot_gate.dart';

class TrackNetApp extends ConsumerStatefulWidget {
  const TrackNetApp({super.key, this.showBoot = true});
  final bool showBoot;
  @override
  ConsumerState<TrackNetApp> createState() => _TrackNetAppState();
}

class _TrackNetAppState extends ConsumerState<TrackNetApp> {
  @override
  Widget build(BuildContext context) {
    final reduce = ref.watch(reduceMotionProvider);
    return MaterialApp.router(
      title: 'TrackNet · CITYVISION',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final content = MediaQuery(
          data: media.copyWith(
            disableAnimations: reduce || media.disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
        return widget.showBoot ? BootGate(child: content) : content;
      },
    );
  }
}
