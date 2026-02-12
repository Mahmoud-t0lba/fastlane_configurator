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
