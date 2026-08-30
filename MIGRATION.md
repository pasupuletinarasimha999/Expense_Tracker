# Migration notes: Android/Kotlin → Flutter

This app was rewritten from a native Android (Kotlin) app to Flutter for full feature
parity. The original source is preserved in git history — see the "Baseline: original
Android/Kotlin Expense Tracker app" commit — in case anything here needs to be
cross-checked against the original behavior.

## Required setup: Google Sign-In & Drive backup

Google Sign-In and Drive sync are fully implemented in code (`lib/features/auth/`,
`lib/data/remote/drive_sync_manager.dart`) but **will not authenticate** until you provide
your own Google Cloud OAuth client. Steps:

1. Create (or reuse) a project at [Google Cloud Console](https://console.cloud.google.com/).
2. Enable the **Google Drive API** for that project.
3. Configure the **OAuth consent screen** (Branding + Audience tabs) — App name, support
   email, and developer contact email are required before anything else will save. User
   type "External" + Publishing status "Testing" is fine for personal use; add your own
   Google account under **Audience → Test users**. Going to "Production" (open to any
   Google account) requires Google's app verification process — not needed for personal use.
4. Under **APIs & Services → Credentials**, create an **OAuth 2.0 Client ID** of type
   **Android**, using:
   - Package name: `com.expensetracker.mobile` (from `android/app/build.gradle.kts`)
   - SHA-1 fingerprint: get it with `cd android && ./gradlew signingReport` — you need
     **both** the debug SHA-1 (for `flutter run`) and, later, your release-key SHA-1, each
     as a separate Android OAuth client entry. A given (package name, SHA-1) pair can only
     be registered once across *all* of your Cloud projects — if creating it fails with
     "already in use," it already exists somewhere; find it under Credentials in whichever
     project you made it in previously rather than trying to duplicate it.
5. No client ID needs to be pasted into the Flutter code — `google_sign_in` on Android
   resolves the OAuth client automatically from the package name + SHA-1 match at the
   Google Play Services level, checked against every OAuth client across every project you
   have. Once the client exists in Cloud Console, sign-in should work within a minute or two.

Without this, tapping "Sign in with Google" will fail — every other screen (Dashboard,
Transactions, Analytics, Trips, Settings' non-sync rows) works fully offline regardless.

## Deviations from the original app

These are deliberate, called out so they don't look like bugs:

- **App/package ID changed**: `com.expensetracker.app` (original) → `com.expensetracker.mobile`
  (this app). Went through an intermediate `com.expensetracker.expense_tracker` (Flutter's
  default scaffolding) before landing here — changed again because that package+SHA-1 pair
  had already been registered as an Android OAuth client during setup and needed a fresh,
  non-conflicting identity. Since the package ID is part of an installed app's identity on
  Android, each rename means a genuinely different app as far as the OS is concerned — see
  "Data migration" below for how existing on-device data was carried across each time.
- **Recurring-transaction background job dropped**: the original scheduled a daily
  WorkManager job (`RecurringTransactionWorker`) that, per its own implementation, did
  nothing but stamp an internal `lastRecurringSync` timestamp never shown in the UI — all
  actual recurring-row generation happens eagerly at insert/edit time (25 months deep),
  unaffected by this. The `workmanager` plugin (0.5.2, the latest resolvable against this
  project's other dependencies) doesn't build against the current Flutter/Android Gradle
  Kotlin toolchain (it references removed v1-embedding APIs), so rather than fight a
  dead plugin for a feature with no observable effect, it was dropped.
- **Gmail export can't pre-fill the recipient address**: Android's `Intent.EXTRA_EMAIL`
  has no equivalent in `share_plus` — the share sheet opens with the report attached,
  subject and body filled in, but the user picks the recipient app/account themselves.
- **Drift schema starts fresh, not migrated from Room's 13 versions**: the Room database
  went through 8→13 versioned migrations as the native app evolved; since this is a new
  SQLite database with no prior installed history, there's nothing to migrate *from* —
  `lib/data/local/database.dart`'s `onCreate` builds the final v13-equivalent schema
  directly instead of replaying that history.
- **App Lock back-button behavior**: the original sent the app to background
  (`moveTaskToBack`) rather than exiting when back is pressed on the lock screen. Flutter
  has no direct cross-platform equivalent without a platform channel, so the lock screen
  just blocks back navigation outright (`PopScope(canPop: false)`) instead.
- **Month selector**: reimplemented as a `ListView` that scrolls the selected month toward
  center on change, rather than porting the original's `LinearSnapHelper` fling-and-snap
  physics exactly.
- **Trips/trip-expenses are now included in Drive backup** (the opposite of the original,
  which deliberately excluded them). Added at the user's request so a fresh device install
  restores *everything*, not just transactions/categories/currency. `DriveSyncManager`'s
  backup payload now also carries `trips` and `tripExpenses` arrays, and `TripRepository`
  triggers the same fire-and-forget auto-push on every trip/trip-expense mutation that
  `TransactionRepository`/`CategoryRepository` already did.

## Data migration from the original app

The original Kotlin app was installed on a real device with real data (347 transactions,
19 categories, 1 trip, 5 trip-expense items) before this rewrite existed, and needed to be
carried across rather than lost. Since Android sandboxes each app's storage — and the
package ID changed, so this is a different app as far as Android is concerned — there's no
automatic migration path; the old app's local database and this app's are on-device but
mutually invisible to each other. Google Drive's per-app backup couldn't help either: it's
scoped per OAuth client, so a backup made by the old app's client isn't visible to a new one
even for the same Google account.

What was actually done (repeatable if needed again, e.g. after another package rename):

1. Pull the old app's live Room database off the device via `adb`, using `run-as` (works
   because the old app is a debug build) — `adb exec-out run-as com.expensetracker.app cat
   /data/data/com.expensetracker.app/databases/expense_tracker_database > local.db`, plus
   its `-wal`/`-shm` sidecar files for any not-yet-checkpointed writes.
2. Install this app once and launch it briefly so its drift database gets created with the
   current schema and seeded default categories, then pull that empty file the same way.
3. The two schemas are column-for-column identical in order (drift just renders Dart
   camelCase as snake_case; Room used camelCase directly) — so merging is a plain SQL
   `ATTACH` + positional `INSERT INTO x SELECT * FROM old.x` for each of the four tables,
   after clearing the freshly-seeded default categories and fixing up `sqlite_sequence` so
   future auto-generated IDs don't collide with imported ones.
4. Push the merged file back into this app's private storage the same way (`adb push` to
   `/data/local/tmp` — NOT `/sdcard`, which is blocked by scoped storage for `run-as` reads
   on at least some OEM Android builds — then `run-as ... cp` into the app's own directory).
5. Verified at each step by comparing row counts and `SUM(amount)` across old vs. new —
   confirmed exact matches (347/19/1/5 rows, identical total transaction amount) both right
   after the merge and again after a normal `adb install -r` app update, to confirm data
   survives ordinary updates going forward.

The original app was never modified or uninstalled during this — only read from — so it
remains available as a fallback.

## Verification performed

- `flutter analyze` — clean, no issues.
- `flutter test` — unit tests for `DateTimeUtils`/`CurrencyUtils`/`PaymentMethod` pass.
- `flutter build apk --debug` — succeeds, exercising the full native plugin build (drift/
  sqlite3, local_auth, flutter_local_notifications, google_sign_in, share_plus, pdf,
  permission_handler) against the Android toolchain.
- Installed on a real physical device via `adb`; migrated real data verified intact (see
  "Data migration" above) and confirmed to survive a normal `adb install -r` update.
- **Not yet done**: walking the actual UI golden paths on-device (add income/expense,
  recurring series edit/delete scopes, trip savings tagging, CSV/PDF export, dark
  mode/currency toggles) and a full Google sign-in round-trip (blocked on completing the
  OAuth client setup above) — everything so far has been verified at the build and data
  layer, not by exercising the running UI.
