import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../models/domain.dart';
import 'processing_indicator.dart';

class BootGate extends ConsumerStatefulWidget {
  const BootGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<BootGate> createState() => _BootGateState();
}

class _BootGateState extends ConsumerState<BootGate> {
  final timers = <Timer>[];
  bool ready = false, started = false;
  String label = 'Initializing TrackNet';
  double progress = 0;
  @override
  void dispose() {
    for (final t in timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final demo = ref.read(dataModeProvider) == DataMode.demo;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final steps = ref.read(bootStepsProvider);
    if (demo && !reduced) {
      for (final step in steps) {
        timers.add(
          Timer(Duration(milliseconds: step.$1), () {
            if (mounted) {
              setState(() {
                progress = step.$2 / 100;
                label = step.$3;
              });
            }
          }),
        );
      }
    } else {
      label = demo ? 'TrackNet ready' : 'Connecting data source';
      progress = 1;
    }
    timers.add(
      Timer(
        Duration(
          milliseconds: reduced
              ? 800
              : demo
              ? 3100
              : 0,
        ),
        () {
          if (mounted) setState(() => ready = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 400,
    ),
    child: ready
        ? widget.child
        : Scaffold(
            key: const ValueKey('boot'),
            body: SafeArea(
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(42),
                    child: SizedBox(
                      width: 330,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hub_outlined, size: 44),
                          const SizedBox(height: 16),
                          const Text(
                            'TrackNet',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Text(
                            'CITYVISION · Urban Intelligence System',
                            style: TextStyle(fontSize: 11),
                          ),
                          const SizedBox(height: 28),
                          ProcessingIndicator(label: label, progress: progress),
                          const SizedBox(height: 24),
                          LinearProgressIndicator(value: progress),
                          const SizedBox(height: 8),
                          Text('${(progress * 100).round()}%'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
  );
}
