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
flutter run              # Android/iOS: sign-in is real (Firebase), the rest is faked
flutter run --dart-define=USE_FIREBASE=false   # everything faked; web and desktop
```

Backend, from `functions/`:

```sh
npm run typecheck && npm run lint && npm test   # must all pass before finishing work
npm run test:e2e         # real flows (sign in, new ID card) through the emulators
npm run format
npm run serve            # functions emulator; point the app at it with
                         #   --dart-define=FUNCTIONS_EMULATOR_HOST=10.0.2.2
npm run deploy           # needs the Blaze plan. Ask before deploying.

# These act on the database named in functions/.env:
npm run db:migrate       # applies functions/migrations/*.sql that have not run
npm run db:staff -- <temple-id> <email> <role>   # puts someone on a temple's team
```

`functions/.env` holds the backend's secrets (Neon, R2). It is git-ignored,
deployed with the functions, and also read by `npm run serve`, which therefore
works on the real database and bucket. To serve on throwaway in-memory
stand-ins instead, put `STAND_INS=true` and `LOCAL_STAFF_EMAIL=<your address>`
in `functions/.env.local`. The emulator is plain HTTP, which only debug builds
allow (`android/app/src/debug/AndroidManifest.xml`).

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
functions/                  # Cloud Functions backend (TypeScript). See "Backend".
hosting/                    # the page a sign-in link lands on outside the app
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

## Fake repositories, moving to the backend one feature at a time

Two things are live, through Firebase and the `functions/` backend: `auth`
(sign-in) and New ID card (`CardRepository` in `members`: a photo and the
member's details in; a saved member, a membership number and a print-ready
card out). Every other repository,
including the member list and the Add a Member wizard, is still an in-memory
fake extending `FakeRepository`
(`core/data/fake_repository.dart`), which simulates latency and guarantees that
only `AppFailure` is thrown. Fakes seed data relative to the clock so the demo
never goes stale.

`AppConfig.useFirebase` (on in a normal build, off in tests and with
`--dart-define=USE_FIREBASE=false`) decides whether the features that have a
Firebase implementation use it. Off, everything is a fake and Firebase is never
initialised.

To move a feature to the backend:

1. Add its functions under `functions/src/features/<feature>/` (see "Backend").
2. Write `FirebaseXRepository implements XRepository` in that feature's `data/`.
   Call functions through `Backend` (`core/data/backend.dart`), never
   `FirebaseFunctions` directly.
3. Wrap each call in `guardFailures(() async { ... })`.
4. In `data/<feature>_repositories.dart`, return it when `useFirebase` is on.
   This is the only file that should change above the data layer.
5. Give any new error `reason` a value in `app_failure.dart` (see below).

`AppConfig.demoMode` shows the "Demo only" shortcuts that stand in for things
the fakes cannot do (scanning a QR code; tapping the email link while sign-in
is faked). Photos are `PhotoSource` (`MemoryPhoto` now, `NetworkPhoto` once
uploads exist).

A finished PDF is printed or shared through `DocumentPrinter`
(`core/services/document_printer.dart`): printed at the size of its own pages
whatever paper is chosen, shared unchanged. `outbox` still simulates its print
jobs; when its documents are real PDFs they go through the same service.

**An ID card on screen is the card itself, never a redrawing.** The backend's
PDF is the only rendering of a temple's card; the app shows its pages
(`cardPagesProvider`, `CardPages`) so what is seen is what prints. With the
backend on, Add a Member opens New ID card (`AppConfig.addMemberWizard`): the
wizard and the member list's own card screen are still the demo.

A write that must not happen twice carries an id the app chooses (`NewCard.id`,
from `newIdProvider`), kept in the form's state for every attempt, so that
trying again after a lost answer returns the first result instead of repeating
the write.

A form that takes a photo keeps a `PhotoDraft` in its state and mixes
`PhotoDraftCommands` into its view model; `PhotoField` shows it and loads the
crop editor itself.

### Sign-in

Passwordless email link, nothing else. `FirebaseAuthRepository` asks Firebase
to email the link, `app_links` delivers it when it is opened (Flutter's own
deep linking is switched off in the manifest and `Info.plist`), and
`AuthViewModel` completes it. The address waiting for its link and the
signed-in profile are kept on the device (`AuthLocalStore`), and `bootstrap`
restores them before the first frame. The app counts as signed in only while
it has both a Firebase session and that profile.

The platform hands the link that launched the app to the first listener only,
so the repository opens the stream of links when `AuthViewModel` subscribes,
not before. On Android `MainActivity` is `singleTask`: Gmail opens links as a
new document, which with `singleTop` starts a second, blank copy of the app.

Sign-in is invite-only, and the backend enforces it: `auth-startSession`
refuses an email that is on no temple's team (`temple_staff`), and the app
then signs back out and says so.

The link's host (`norbu-flow.firebaseapp.com`) appears in three places that
must agree: `AndroidManifest.xml`, `ios/Runner/Runner.entitlements`, and the
Firebase project id the repository builds the link from.

## Backend

`functions/` is a TypeScript Cloud Functions (2nd gen) codebase, laid out like
the app: `core/` is shared and feature-agnostic, `features/<feature>/` holds
one feature.

```
functions/src/
  index.ts                  # initialises the Admin SDK; one export per feature
  runtime.ts                # the database and file store the functions run on
  core/
    callable.ts             # defineCallable, and an error's one way to a response
    caller.ts               # who is calling (a proven email only)
    validation.ts           # zod input → field issues
    errors.ts               # AppError: no Firebase, no HTTP
    options.ts              # region, instance cap
    environment.ts          # settings from .env; whether stand-ins are in use
    database.ts             # the Database port: Neon, or in-memory
    migrations.ts           # applies functions/migrations
    file-store.ts           # the FileStore port: Cloudflare R2, or in-memory
    assets.ts               # reads functions/assets (fonts, card artwork)
    calendar-date.ts lazy.ts
  cli/db.ts                 # npm run db:migrate / db:staff
  features/<feature>/
    index.ts                # its callables, or what it offers other features
    <feature>.input.ts      # the zod schema of a callable's request
    <feature>.service.ts    # rules. No HTTP, no Firebase, no SQL.
    <entity>.ts             # entity + repository interface
    <store>-<entity>.repository.ts
functions/migrations/       # numbered SQL, applied in name order
functions/assets/           # fonts and each temple's card artwork (PDF)
```

Features: `auth`, `temples` (who works where, and in what role), `members`
(`members-create`), `cards` (the renderer; it has no functions of its own).

- A function exported as `auth.startSession` deploys as `auth-startSession`,
  which is the name the app passes to `Backend.call`.
- Declare every function with `defineCallable`. It rejects callers without an
  email-link session, validates input against a zod schema, and turns errors
  into responses. Handlers receive a `Caller` and typed input.
- Services depend on interfaces (repositories, `FileStore`), never on a
  store. A feature's `index.ts` builds its service once, lazily, from
  `runtime.ts` and real objects: repositories take a `Database` (or just
  `Sql`), not a promise of one.
- A feature with no functions of its own exports what others use from its
  `index.ts`, already wired: `temples` gives `templeAccess`, `cards` gives
  `cardRenderer`.
- **Who checks what.** The input schema (`<feature>.input.ts`) is the
  request's contract: every value present, trimmed, within its limits. The
  service takes that as given and owns the rules that need knowledge, such as
  whether a name fits the temple's card.
- A function that adds something takes an `id` chosen by the app and, asked
  again with the same id, returns what it made the first time
  (`members-create`). The app retries when an answer is lost.
- Libraries only some functions need (`pg`, the S3 client, `sharp`, `pdf-lib`)
  are loaded with `await import()` where they are used, so the rest start fast.
- Throw `AppError.*` for anything the app should see. Everything else is
  logged and returned as `internal`, with no detail. `AppError` knows nothing
  of HTTP; `callable.ts` gives each kind its status.
- **Error contract.** `details.reason` and the values of `details.fields` are
  the *names* of the app's enums (`PermissionReason`, `ConflictReason`,
  `ValidationIssue`), which is how `FailureMapper` reads them. A zod schema's
  error message is therefore a `ValidationIssue` name:
  `z.email('emailIncomplete')`. A field the app fills in itself (`id`) has no
  issue name: a bad one is a bug in the app.
- Lint fails on a promise nobody awaits: inside `Database.transaction` such a
  query would run outside the transaction.
- The region in `core/options.ts` and `AppConfig.functionsRegion` must match.
- **Database.** Neon (Postgres), reached only through the `Database` port in
  `core/database.ts`. Repositories write plain SQL and cast `bigint` and
  `date` columns to text, so rows look the same from every driver. Writes
  that belong together go through `Database.transaction`. Schema changes are
  new files in `functions/migrations`, never edits to applied ones.
- **Multi-tenant.** A temple is the tenant. Every table that belongs to a
  temple has `temple_id`, its indexes and unique constraints lead with it,
  every query filters on it, and a row may only reference rows of the same
  temple (composite foreign keys, as `member_cards` → `members`). What
  differs between temples is configuration on the `temples` row (time zone,
  card template, membership term, how membership numbers are written), not
  code: add a column there before adding an `if` here.
- **Access.** Who may do what is decided by `TempleAccess` from the
  `temple_staff` table, matched on the caller's email. That table is also
  the invitation list for sign-in, so `auth` asks the same `TempleAccess`.
- **Files.** Photos and generated documents go to Cloudflare R2 through the
  `FileStore` port in `core/file-store.ts`; the database stores only their
  keys. Keys start `temples/<temple id>/`.
- **Stand-ins.** Tests build an in-memory Postgres (PGlite, same migrations)
  and an `InMemoryFileStore` themselves. `runtime.ts` uses the same pair
  instead of Neon and R2 when `standIns` is on: only in the emulator, for a
  `demo-` project (which is what `npm run test:e2e` uses) or with
  `STAND_INS=true`. It is one switch for both, so the two are never mixed and
  tests never reach Neon or R2. With the in-memory database,
  `LOCAL_STAFF_EMAIL` is put on every temple's team.
- **Cards and other documents must match the temple's own design exactly.**
  A card is the designer's exported artwork (`assets/cards/<template>/`) with
  the member's details set on top by `CardRenderer`, at positions read from a
  finished card exported from the same design file
  (`cards/templates/<template>.ts`). The fonts are the exact releases the
  design uses. After any change to a template or the renderer, draw a
  generated card over the designer's export of the same member and compare
  them: the text must land on the same thousandth of a point. The renderer
  has no Firebase imports, so it can move to Cloud Run unchanged if rendering
  ever outgrows a function.
- Unit tests (`test/`) cover services and the core with fakes. `test/e2e`
  drives real flows through the emulators. Add both with each new function.

## Error handling

One path, used everywhere. Do not add `try/catch` in views or view models.

- **`AppFailure`** (`core/error/app_failure.dart`) is the only error type above
  the data layer: a sealed hierarchy (`NetworkFailure`, `PermissionFailure`,
  `ConflictFailure`, `NotFoundFailure`, …). New kinds of error are new
  subclasses or new `reason` enum values there.
- **`FailureMapper.map`** is the single place raw exceptions and Firebase
  error codes (Auth, and the backend's — see "Backend") become `AppFailure`.
  `guardFailures` applies it to every repository call.
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
  fake latency. Use them rather than hand-rolling overrides. Tests run with
  Firebase off, so every repository is its fake.
- A Firebase repository is tested against fakes of what it calls (`Backend`,
  and `Fake implements FirebaseAuth`), as in `test/features/auth_test.dart`.
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
