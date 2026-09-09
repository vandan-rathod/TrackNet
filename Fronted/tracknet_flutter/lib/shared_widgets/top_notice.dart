import 'dart:async';

import 'package:flutter/material.dart';

void showTopNotice(BuildContext context, String message) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  Timer? timer;
  void close() {
    timer?.cancel();
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.paddingOf(context).top + 76,
      right: 16,
      width: (MediaQuery.sizeOf(context).width - 32).clamp(0, 380),
      child: Material(
        elevation: 5,
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(Icons.notifications_none, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      message,
                      style: const TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Dismiss notification',
                  onPressed: close,
                  icon: const Icon(Icons.close, size: 16),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  timer = Timer(const Duration(milliseconds: 8200), close);
}
