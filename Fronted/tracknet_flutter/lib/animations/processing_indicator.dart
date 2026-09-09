import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// No animation file is assumed. An integration may supply a validated Lottie
/// composition or a loaded Rive widget. The built-in fallback has no I/O.
class ProcessingIndicator extends StatelessWidget {
  const ProcessingIndicator({
    super.key,
    required this.label,
    this.composition,
    this.riveWidget,
    this.progress,
  });
  final String label;
  final LottieComposition? composition;
  final Widget? riveWidget;
  final double? progress;
  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: label,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 64,
            width: 64,
            child: !reduced && riveWidget != null
                ? riveWidget
                : !reduced && composition != null
                ? Lottie(composition: composition)
                : Center(
                    child: reduced
                        ? const Icon(Icons.hub_outlined, size: 36)
                        : CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 3,
                          ),
                  ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: Duration(milliseconds: reduced ? 0 : 180),
            child: Text(
              label,
              key: ValueKey(label),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
