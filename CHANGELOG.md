## 0.1.12

- Added iOS Firebase native integration step in `firebase-sync` to patch
  `ios/Runner/AppDelegate.swift` automatically:
  - add `import FirebaseCore` when missing
  - add guarded `FirebaseApp.configure()` in `didFinishLaunchingWithOptions`
    when missing.
- Added tests for AppDelegate integration add/no-duplicate behavior.

## 0.1.11

- Updated generated Android build mode prompt to numeric choices:
  `1) release`, `2) debug`, with safe defaults.
- Added numeric mode compatibility (`1`/`2`) when passed through
  lane options or environment variables.

## 0.1.10

- Added automatic `Firebase.initializeApp` injection in `lib/main.dart` during
  `firebase-sync` when initialization is missing.
- Fixed generated Fastfile paths so commands run correctly from the `fastlane/`
  working directory (`project-root ..`, correct output/artifact paths).
- Changed default App Distribution group from `qa` to `testers`.
- Updated Android local Firebase release lane to build/distribute APK by default
  (with AAB fallback) for simpler App Distribution onboarding.

## 0.1.9

- Fixed generated Fastfile script paths for `bootstrap_cli_env` and
  `apple_account_info` lanes so they work from the `fastlane/` working
  directory at runtime.

## 0.1.8

- Added generated `fastlane/scripts/sync_cli_env.sh` to auto-detect and inject
  `GITHUB_REPOSITORY`, `GITHUB_TOKEN`, and `FIREBASE_TOKEN` from local CLI
  sessions into `fastlane/.env`.
- Added generated `fastlane/scripts/apple_account_info.sh` and Fastlane lane
  `apple_account_info` to fetch Apple provider/team account data using `altool`.
- Updated generated `Fastfile` to bootstrap CLI credentials before Firebase and
  GitHub metadata operations, with fallback reads from `fastlane/.env`.
- Stopped generating empty managed `fastlane/Pluginfile` files to avoid plugin
  load warnings in Fastlane.

## 0.1.7

- Updated package links to the renamed GitHub repository: `Mahmoud-t0lba/fastlane_cli`.
- Published maintenance release to keep `pub.dev` metadata aligned with `fastlane_cli`.

## 0.1.6

- Renamed package to `fastlane_cli`.
- Renamed executable command to `fastlane_cli` while keeping `flc` alias.
- Updated imports and examples to `package:fastlane_cli/fastlane_cli.dart`.

## 0.1.5

- Added Firebase App Distribution group setup during `init`/`firebase-sync`:
  can resolve group aliases and create missing groups automatically.
- Added new flags for App Distribution setup:
  `--appdist-groups`, `--appdist-skip-group-setup`, and `--skip-group-setup`.
- Updated metadata payload so `build_data.json` now includes:
  `app.version` and `app.version_source` from `pubspec.yaml`.
- Improved generated Fastfile with direct one-shot local lanes:
  `release_android_to_firebase` and `release_ios_to_firebase`.
- Updated README with full command/flow details for build + direct Firebase distribution.

## 0.1.4

- Added interactive Firebase project resolution for `init`/`firebase-sync`:
  select an existing project or choose `0) Create new Firebase project`.
- Added placeholder project-id detection (for examples like
  `your-firebase-project-id`) with safer fallback behavior.
- Added automatic `firebase_core` dependency check/add in `pubspec.yaml`
  before running `flutterfire configure`.
- Expanded README with full command reference and Firebase interactive flow.
- Added and updated tests for project selection/create and dependency handling.

## 0.1.3

- Fixed `firebase-sync` to auto-connect unlinked projects by updating `.firebaserc`
  and running `firebase use <projectId>` before retrying `apps:list`.
- Added retry flow for `firebase apps:list` with clearer error guidance.
- Added tests covering reconnect-on-failure behavior.

## 0.1.2

- Added `firebase-sync` command to fetch Firebase app/project data via Firebase CLI.
- Added automatic env injection into `fastlane/.env.default` from fetched Firebase data.
- Added `init` one-shot command (`setup` + `firebase-sync` + `fetch-data`).
- Updated generated `Fastfile` `fetch_data` lane to run Firebase sync automatically.
- Added Dartdoc comments for public API symbols.
- Added `example/main.dart` for pub.dev example scoring.

## 0.1.1

- Improved executable usage with a short alias: `flc`.
- Added clear "Use this package as an executable" section in README.
- Added no-global-install command example using `dart run`.

## 0.1.0

- Initial public release.
- Added `setup` command to generate Fastlane, environment, and GitHub Actions files.
- Added `fetch-data` command to export app/git/GitHub metadata JSON.
- Added Firebase App Distribution and CI lane templates for Flutter projects.
