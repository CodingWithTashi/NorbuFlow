# NorbuFlow

Flutter app for Tibetan Buddhist temples: membership and ID cards, offerings and
receipts, volunteer scheduling, announcements. Used at a front desk by people of
all ages, in English and Tibetan, on phones and on tablets up to iPad landscape.

The UI implements the design project "NorbuFlow Prototype v2"
(claude.ai/design, project `9ef6cd89-8569-431e-995d-8f1e1acb4f91`). When a screen
and the prototype disagree, the prototype is the reference.

## Commands

```sh
flutter pub get          # also regenerates lib/l10n/generated (generate: true)
flutter gen-l10n         # after editing lib/l10n/*.arb
flutter analyze          # must report "No issues found"
flutter test             # unit + widget tests; must pass before finishing work
dart format lib test
flutter run              # backend is faked, no Firebase setup needed
```

## Architecture: feature-first MVVM with Riverpod

```
lib/
  main.dart                 # calls bootstrap()
  app/                      # composition root: bootstrap, MaterialApp, router, shell
  core/                     # shared, feature-agnostic code
    error/                  # AppFailure, FailureMapper, runCommand, failureText
    feedback/               # toasts (AppMessenger, ToastHost), sheets, confirm dialog
    theme/ layout/ widgets/ # design tokens, breakpoints, design-system widgets
    calendar/ utils/ services/ data/ config/ models/
  features/<feature>/
    domain/                 # entities + repository interfaces. Pure Dart.
    data/                   # repository implementations + <feature>_repositories.dart
    presentation/
      view_models/          # Riverpod Notifier / AsyncNotifier + immutable state
      views/                # screens (ConsumerWidget). No business logic.
      widgets/              # feature-specific widgets
      <feature>_labels.dart # enum → localized label / icon / colour
  l10n/                     # app_en.arb (template), app_bo.arb, generated/
```

Features: `auth`, `onboarding`, `temple` (temples, team, roles, settings), `home`,
`members`, `offerings`, `volunteers`, `announcements`, `reports`, `settings`
(app preferences), `outbox` (everything that leaves the app: send, print,
export), `assistant` ("Improve wording").

### Layer rules

- **View** → reads state with `ref.watch`, calls view-model methods, navigates,
  and shows toasts for *success*. It never calls a repository and never
  contains validation or business rules. Purely ephemeral UI state (a sheet's
  unsaved selection, a "sending" flag, a crop gesture) may live in a `State`;
  anything a rule depends on belongs in the view model.
- **ViewModel** → a `Notifier`/`AsyncNotifier` exposing one immutable state
  class with `copyWith`. Owns validation and business rules. Talks only to
  repository *interfaces* through their providers. Never imports `BuildContext`,
  widgets, or `AppLocalizations`; it returns codes (`ValidationIssue`, enums),
  not user-facing strings.
- **Domain** → entities and `abstract interface class XRepository`. No Flutter
  imports beyond `foundation`, no Riverpod, no localization, no colours
  (`AccentPreset` is a plain enum; its colours are a theme extension).
- **Data** → implementations. Only this layer knows a backend exists.
- Dependencies point inward: `views → view_models → domain ← data`. `core`
  never imports `features`. Features may import `app/router/app_routes.dart`
  (plain route strings) but nothing else from `app/`.
- Use plain Riverpod 3 (`Notifier`, `AsyncNotifier`, `.autoDispose`, `.family`
  with constructor arguments). No code generation, no `StateProvider`.
- Screen-scoped view models are `autoDispose`. App-scoped state (session,
  current temple, preferences, members list) is not.

### Single source of truth

One provider owns each piece of state; everything else derives from it.

- `authViewModelProvider` — who is signed in.
- `currentTempleIdProvider` / `currentTempleProvider` — the temple being worked
  in. Temple-scoped providers `ref.watch(activeTempleIdProvider)`, which is
  what makes them reload on a temple switch. Do not pass temple ids around.
- `templesProvider` — temple details (name, logo, accent). The theme follows it.
- `membersProvider` — the member list. The list, ID card, check-in and reports
  all read it, so a renewal on one screen shows on all of them.
- `preferencesProvider` — language, dark mode, Simple Mode.
- `todayProvider` / `clockProvider` — never call `DateTime.now()` in a view
  model or widget.
- Derived values are `Provider`s computed from these (e.g.
  `membershipDueProvider`, `memberListProvider`), not copies kept in sync.

## Fake repositories now, Firebase Functions later

Every repository is currently an in-memory fake extending `FakeRepository`
(`core/data/fake_repository.dart`), which simulates latency and guarantees that
only `AppFailure` is thrown. Fakes seed data relative to the clock so the demo
never goes stale.

To add the real backend for a feature:

1. Write `FirebaseXRepository implements XRepository` in that feature's `data/`.
2. Wrap each call in `guardFailures(() async { ... })`.
3. Change the binding in `data/<feature>_repositories.dart`. This is the only
   file that should change above the data layer.
4. Map the backend's error codes in `FailureMapper.map` (see below).

`AppConfig.demoMode` shows the "Demo only" shortcuts that stand in for things
the fakes cannot do (tapping the email link, scanning a QR code). Photos are
`PhotoSource` (`MemoryPhoto` now, `NetworkPhoto` once uploads exist). Firebase
packages are in `pubspec.yaml` but nothing initialises Firebase yet.

## Error handling

One path, used everywhere. Do not add `try/catch` in views or view models.

- **`AppFailure`** (`core/error/app_failure.dart`) is the only error type above
  the data layer: a sealed hierarchy (`NetworkFailure`, `PermissionFailure`,
  `ConflictFailure`, `NotFoundFailure`, …). New kinds of error are new
  subclasses or new `reason` enum values there.
- **`FailureMapper.map`** is the single place raw exceptions (and, later,
  Firebase error codes) become `AppFailure`. `guardFailures` applies it to every
  repository call.
- **Reads**: `AsyncNotifier`/`FutureProvider` + `AsyncValueView`, which renders
  loading, error (with retry) and data identically on every screen.
  `ProviderErrorObserver` reports failed providers; `appRetryPolicy` retries
  only transient failures.
- **Writes**: view models call `runCommand(ref, () => repository.x())`, which
  maps, reports and toasts the failure and returns `Result<T>`. Pass
  `notify: false` only when the failure is shown inline instead.
- **Wording**: `failureText(l10n, failure)` and `validationText(l10n, issue)`
  in `core/error/failure_text.dart` are the only places an error becomes
  words. Both are exhaustive switches, so a new failure will not compile until
  it has copy.
- **Validation**: rules live in `Validators`; view models keep
  `ValidationIssue` codes in state; views render them with `FieldError`.
- **Reporting**: `ErrorReporter` receives every failure (commands, providers,
  `FlutterError.onError`, `PlatformDispatcher.onError`). Swap its provider for
  Crashlytics later.
- All toasts go through `appMessengerProvider` (`ref.toast('…')`); `ToastHost`
  renders them. Do not use `ScaffoldMessenger`/`SnackBar`.

## Responsive layout

Window classes (`core/layout/breakpoints.dart`): compact `< 600`, medium
`600–839`, expanded `≥ 840`.

- `AppShell` shows a bottom tab bar on phones (hidden on focused tasks, see
  `AppRoutes.withTabBar`) and a side rail on tablets (always visible).
- Wrap screens in `AppPage` (back link, capped content width, pinned action
  bar). Flows use `WizardScaffold`; confirmations use `SuccessView`.
- Use `ResponsiveGrid` for tile grids, `AdaptiveColumns` to place two blocks
  side by side on wide panes, and `LayoutBuilder` (pane width, not window
  width) for two-pane screens such as Members and Calendar.
- `showAppSheet` is a bottom sheet on phones and a dialog on tablets. Use it
  and `showConfirmDialog` rather than raw `showModalBottomSheet`/`showDialog`.
- Never give text a fixed height. Use `minHeight` constraints so layouts
  survive Tibetan (×1.16) plus Simple Mode (×1.18) text scaling.
- Tap targets are at least 48 px; primary actions are 56–60 px tall.

## Design system

- Colours: `context.colors` (`AppColors`, changes with theme and temple accent)
  and `AppPalette` (constants). No colour literals in feature code.
- Text: `context.type.sans(size)` / `.serif(size)` / `.tibetan(size)`. Never
  build a `TextStyle` with a font family by hand. Line heights passed in are
  Latin heights; Tibetan is raised automatically.
- Fonts are bundled in `assets/fonts` (Atkinson Hyperlegible Next, Source
  Serif 4, Noto Serif Tibetan). They contain no ✓ ◷ ◆ ↑ symbols: use `AppIcon`
  / `IconLabel` / `StatusPill(icon:)` with `AppIcons`, never a typed symbol.
- Status is never colour alone: pair it with an icon and words.
- Documents (ID card, receipt, prayer lists, volunteer plan) stay light
  "paper" in dark mode.
- Keep sacred imagery away from navigation, deletes and errors.

## Localization

- All user-facing copy lives in `lib/l10n/app_en.arb`; Tibetan in
  `app_bo.arb` (untranslated keys fall back to English). Access with
  `context.l10n`. Enum labels live in `<feature>_labels.dart` extensions.
- **Any message with two or more placeholders must declare them in an
  `@key` `placeholders` block, in reading order.** gen-l10n sorts inferred
  placeholders alphabetically, which silently swaps arguments.
- No symbols or glyphs in ARB strings (see Design system).
- Dates and money go through `Formats` (`core/utils/formatters.dart`).
- Tibetan copy is a first pass and needs review by a native reader.

## Testing

- `test/support/test_app.dart` provides `createContainer()`,
  `createSignedInContainer()`, `pumpApp()`, a fixed clock (`testNow`) and zero
  fake latency. Use them rather than hand-rolling overrides.
- View-model tests drive the notifier through a `ProviderContainer`. Keep an
  `autoDispose` provider alive with `container.listen` for the test.
- `test/app_test.dart` visits every route on a phone, tablet portrait, tablet
  landscape, in dark mode, and in Tibetan with Simple Mode. Add new routes to
  `_locations` there; a layout overflow anywhere fails it.
- Add a test with each new view model rule and each bug fix.

## Adding a screen

1. Domain entity + repository method (interface, then fake).
2. View model with immutable state; rules and validation here.
3. View built from `core/widgets`; copy in the ARB; labels in the feature's
   labels file.
4. Route in `app_routes.dart` and `app_router.dart`; add it to `_locations`
   in `test/app_test.dart`.
5. `flutter analyze` and `flutter test` clean.
