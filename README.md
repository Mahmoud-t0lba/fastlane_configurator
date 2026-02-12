# fastlane_cli

`fastlane_cli` is a Dart CLI package that bootstraps Fastlane + Firebase + GitHub Actions for Flutter projects.

It can:

- generate Fastlane files (`Fastfile`, `Appfile`, `Pluginfile`, `.env.default`)
- generate GitHub Actions workflow for Android/iOS
- fetch project/git/GitHub metadata JSON
- sync Firebase app/project data into your project files
- run Firebase login and FlutterFire configuration automatically
- auto-setup Firebase App Distribution groups (create if missing)

## Install

```bash
dart pub global activate fastlane_cli
```

If needed:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

## Use As Executable

```bash
fastlane_cli --help
flc --help
dart run fastlane_cli:fastlane_cli --help
```

## Quick Start

Use this single command from your Flutter project root:

```bash
flc init --project-root . --overwrite
```

`init` runs:

1. `setup`
2. `firebase-sync`
3. `fetch-data`

## Command Reference

### `init`

One command setup for everything.

```bash
flc init --project-root . --overwrite
```

Common flags:

- `--project-root <path>`: override target project directory
- `--overwrite`: replace generated files if changed
- `--firebase-project <project-id>`: use explicit Firebase project id
- `--firebase-output-path <path>`: firebase JSON output path
- `--output-path <path>`: build metadata JSON output path
- `--appdist-groups <aliases>`: comma-separated tester groups (example: `qa,beta`)
- `--appdist-skip-group-setup`: skip App Distribution group create/check step
- `--no-include-github`: skip GitHub API metadata
- `--firebase-optional`: do not fail hard if Firebase is not available

### `setup`

Generate Fastlane and workflow files only.

```bash
flc setup --project-root . --overwrite
```

Common flags:

- `--no-ci`
- `--no-env`
- `--workflow-filename mobile_delivery.yml`
- `--ci-branch main`
- `--ios-bundle-id <bundle-id>`
- `--android-package-name <package-name>`
- `--apple-id <email>`
- `--team-id <team-id>`
- `--itc-team-id <itc-team-id>`

### `firebase-sync`

Fetch Firebase metadata, update env, and configure Firebase integration.

```bash
flc firebase-sync --project-root . --overwrite
```

Common flags:

- `--firebase-project <project-id>`
- `--output-path fastlane/firebase_data.json`
- `--env-path fastlane/.env.default`
- `--no-update-env`
- `--overwrite`
- `--optional`
- `--appdist-groups <aliases>`
- `--skip-group-setup`

### `fetch-data`

Write project/git/GitHub metadata to JSON.

```bash
flc fetch-data --project-root . --output-path fastlane/build_data.json --include-github
```

Common flags:

- `--project-root <path>`
- `--output-path <path>`
- `--include-github` / `--no-include-github`
- `--github-repository owner/repo`
- `--github-token <token>`

`build_data.json` app section reads directly from `pubspec.yaml`:

- `app.version` (raw value, e.g. `1.2.3+45`)
- `app.version_name`
- `app.version_code`
- `app.version_source` (`pubspec.yaml`)

## Firebase Interactive Flow

When running `init` or `firebase-sync`:

1. Checks Firebase login (`firebase login:list`), then runs `firebase login` if needed.
2. Resolves project id from:
   - `--firebase-project`
   - environment (`FIREBASE_PROJECT_ID` / `GCLOUD_PROJECT`)
   - active Firebase target (`firebase use --json`)
3. If no project is linked, it lists your Firebase projects and prompts:
   - select existing project
   - or choose `0) Create new Firebase project`
4. If selected project id is invalid/not found, it can create a new one.
5. Links project locally (`.firebaserc` + `firebase use <projectId>`).
6. Checks `pubspec.yaml` for `firebase_core`:
   - if exists, continues
   - if missing, adds it automatically (`flutter pub add firebase_core`), with fallback file update
7. Runs `flutterfire configure --project <projectId> --yes`.
8. Resolves App Distribution groups from `--appdist-groups`, env, or defaults (`qa`), then creates missing groups automatically.
9. Writes:
   - `fastlane/firebase_data.json`
   - updates `fastlane/.env.default`

## Direct Build + Upload To Firebase App Distribution

After `flc init`, run from your app project:

```bash
fastlane android release_android_to_firebase
fastlane ios release_ios_to_firebase
```

These lanes:

1. refresh data (`fetch_data`)
2. build release artifact
3. upload direct to Firebase App Distribution

## Generated/Updated Files

- `fastlane/Fastfile`
- `fastlane/Appfile`
- `fastlane/Pluginfile`
- `fastlane/.env.default`
- `.github/workflows/mobile_delivery.yml`
- `fastlane/firebase_data.json`
- `fastlane/build_data.json`
- `.firebaserc` (when Firebase project is linked)
- `pubspec.yaml` (adds `firebase_core` if missing)

## Required Env Vars For CI Lanes

- `FIREBASE_TOKEN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_APP_ID_ANDROID`
- `FIREBASE_APP_ID_IOS`
- `FIREBASE_TESTER_GROUPS`
- `GITHUB_REPOSITORY`
- `GITHUB_TOKEN`
- `FASTLANE_APP_IDENTIFIER`
- `FASTLANE_ANDROID_PACKAGE_NAME`
