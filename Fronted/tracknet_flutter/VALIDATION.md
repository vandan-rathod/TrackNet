# Validation — 2026-09-09

Environment: Windows, Flutter 3.47.2 stable, Dart 3.13.2.

## Automated checks

- `dart format lib test`: formatted successfully.
- `flutter analyze`: no issues.
- `flutter test`: 11 tests passed. Includes all seven routes at 1440, 834 and 390 logical pixels, selected deep links and reduced-motion rendering.
- Web compilation succeeded for both `DATA_MODE=demo` and `DATA_MODE=backend`, including Flutter's Wasm compatibility dry run. The delivered output uses the default web build, not a separately browser-tested Wasm build.
- Fixtures verify 256 cameras, initial 248 online, six warning, two offline, seven zones/alerts, chart values and curated journeys.
- Repository tests verify pause, ticks, reset, camera reconnect, alert resolution, camera/detection filters, search/sorting, backend isolation, unavailable transport states and OCR mapping.

## Browser smoke check

The release app was served locally. All seven routes opened. Dashboard and camera feeds rendered; analytics charts and the hour deep link rendered; the curated GJ01AB1234 journey displayed four events and replay reached its final timeline selection. Back returned from cameras to dashboard; forward returned to cameras. The network Offline filter changed the registry to only offline records. Settings exposed the five source toggles and reconnection monitor. Backend build showed a disconnected state with no demo metrics/operator. Captured demo console error/warning log was empty.

The browser viewport capability did not change the observed 1280×720 viewport. Mobile/tablet coverage is therefore automated Flutter layout testing, not a claim of physical-device testing. These are smoke and regression checks, not exhaustive proof that every pointer gesture, timing edge case or button permutation is identical to the source. Source rendering/behavior corrections and future media/transport limitations are documented in README.
