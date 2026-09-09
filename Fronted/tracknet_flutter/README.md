# TrackNet / CITYVISION — Flutter Web

Urban Intelligence System migrated from `../demo/index_backup_before_dark_retheme.html`. All application UI, maps, charts and behavior are Dart. Generated `web/index.html` is only Flutter's required bootstrap host; it contains no dashboard UI. No WebView, Leaflet or JavaScript application is used.

## Run

Flutter 3.47.2 stable / Dart 3.13.2. Dependencies are pinned in `pubspec.lock`.

```sh
flutter pub get
flutter run -d chrome --dart-define=DATA_MODE=demo
flutter run -d chrome --dart-define=DATA_MODE=backend
dart format lib test
flutter analyze
flutter test
flutter build web --dart-define=DATA_MODE=demo
flutter build web --dart-define=DATA_MODE=backend --output=build/backend
```

Serve `build/web` for demo or `build/backend` for backend mode using an HTTP server. Default mode is demo. Changing the define requires a restart/rebuild. Hash routing works on static hosts without rewrite rules.

## Architecture and demo data

- `lib/models/`: typed domain objects, availability states, plate validation and OCR review suggestions.
- `lib/repositories/dashboard_repository.dart`: `DashboardRepository` aggregates `CameraRepository`, `VehicleRepository`, `DetectionRepository`, `AlertRepository`, `AnalyticsRepository`, `NetworkRepository`, `MapRepository` and `SettingsRepository`.
- `lib/demo/demo_data/`: deterministic capture of original random initialization, seeded records, charts, roads, map geometry and curated journeys. Timestamps rebase on startup. These are fixtures, never UI constants.
- `lib/demo/mock_repositories/mock_dashboard_repository.dart`: random reads, timers, particles, procedural feed data, alerts, reconnect and reset. Initial capture has 256 cameras (248 online, six warning, two offline), seven zones, seven seeded alerts and 535 detections. Twelve preview feeds are supplied.
- `lib/providers/providers.dart`: mode and repository injection; focused Riverpod selectors for selections, searches, filters, pagination, chart lens, layers, settings, notifications and availability.
- `lib/features/`: seven views consuming typed models and providers.
- `lib/map/`, `lib/charts/`: pure Flutter synthetic map, routes, heat and particles; fl_chart charts and a Dart OD painter.
- `lib/app/`, `lib/routing/`, `lib/theme/`, `lib/animations/`: responsive shell, go_router, neutral light appearance and lifecycle-managed animations.

Demo retains the 2.6-second detection tick, 5.2-second KPI/analytics refresh, eight-second heat/zone refresh and one-second clock. Boot milestones include final fade and reduced-motion shortcut. Journey lookup uses 820 ms (80 ms reduced); replay uses the source's bounded 6–16-second duration. Timers/controllers are disposed. Offscreen/reduced-motion feeds and particles pause.

## Backend integration

Backend mode starts disconnected with no demo repository or fallback. Loading, empty, error, offline and disconnected are explicit availability states. Missing metrics remain unavailable. Demo reset cannot run in backend mode.

Implement `BackendTransport` in `lib/data_sources/backend_transport.dart` using the eventual agreed REST/WebSocket/streaming contract. No endpoint, authentication or wire JSON fields have been invented. `fetch()` returns typed `DashboardData`; `watch()` emits `RepositoryState`. Commands cover journey lookup, feeds, reconnect, alert resolution and settings. A non-streaming adapter should keep its connection-state stream open rather than immediately reporting disconnection.

Override `backendTransportProvider` in `ProviderScope` with your transport. Register `ref.onDispose(transport.dispose)` in that override: the provider owns the transport across repository retries. Alternatively override `repositoryProvider` with your `DashboardRepository`.

Define wire DTOs after the API contract exists and implement `DtoMapper<YourDto, DomainType>`. `DetectionInput` / `DetectionMapper` are a semantic boundary, not a proposed JSON schema. Preserve camera, time, raw OCR, confidence and context. Confidence is a percentage (0–100); convert other scales in your mapper.

Validation uses `^[A-Z]{2}[0-9]{1,2}[A-Z]{1,2}[0-9]{4}$`. O/0, I/1, B/8, S/5 and Z/2 alternatives are review suggestions only, never automatic acceptance. Unreadable/no-plate records remain present without accepted plate text. Statuses include no plate, unreadable, normal, flagged, blacklisted, tamper review and clone review. No enforcement actions or legal conclusions are generated.

## Routes

| Route | Query parameters |
| --- | --- |
| `/dashboard` | `camera` |
| `/cameras` | `camera` |
| `/vehicle` | `plate`, `camera` |
| `/analytics` | `hour`, `zone`, `camera` |
| `/alerts` | `alert`, `camera` |
| `/network` | `camera` |
| `/settings` | — |

Example: `http://localhost:52127/#/vehicle?plate=GJ01AB1234`. Hours: `6`, `9`, `now`, `12`, `18`, `21`. go_router selections participate in browser history. Desktop sidebar collapses; compact layouts provide a drawer and scrollable bottom navigation with all seven destinations. Tables retain columns through horizontal scrolling.

## Packages and assets

flutter_riverpod 3.4.3, go_router 18.0.1, fl_chart 1.2.0, google_fonts 8.2.1, rive 0.14.11, lottie 3.5.1, visibility_detector 0.4.0+2, shared_preferences 2.5.5. Inter font files and OFL license are bundled; runtime font downloads are disabled.

No validated Rive/Lottie asset was supplied. `ProcessingIndicator` uses the permitted built-in reduced-motion-safe fallback for boot/reconnect/loading and accepts validated animation content later. No nonexistent asset paths are referenced. The packages are installed; current animations are Flutter fallbacks.

## Validation and technical limitations

Repository tests cover fixture totals, curated journeys, simulation pause, resolve/reconnect, filters, sorting, backend isolation and ANPR mapping. Widget tests exercise all seven routes at 1440, 834 and 390 px, deep links, replay availability and disconnected backend presentation.

The source has bugs: its twelve-feed picker returns ten, warning/offline filters compare different spellings, route setup clears its own replay, and last-detection timestamps reference a missing field. These behaviors are corrected. Random initialization is reproducible rather than identical to every old-page reload. Legacy raw demo plates are retained even where the source produced a three-digit suffix; manual searches enforce the requested four-digit format.

The source density calculation compares kilometers to stored zone-radius values; its calculation is retained rather than silently redefining the chart. Analytics reflects refreshed series and settings counters report actual repository activity. Map geometry is retained with Flutter rendering, not pixel-identical Leaflet styling. CCTV previews are procedural scenes, not actual video. Real video requires a backend media transport/decoder. Real data requires an implemented backend transport.

## Current visual theme

Shadcn-style neutral light theme implemented with native Flutter widgets: white surfaces, zinc text and borders, restrained shadows, eight-pixel control corners and twelve-pixel cards. Dark mode and its saved-preference loading were removed. Status colors remain semantic (green online, amber warning, red critical). No Shadcn MCP tools were available; no React/Tailwind runtime was introduced.

Reference: [Shadcn theme tokens](https://ui.shadcn.com/docs/theming). Central Flutter tokens are in `lib/theme/app_theme.dart`. Map wheel scrolling leaves the map transform unchanged; explicit zoom controls remain available. The sidebar arrow is removed.
