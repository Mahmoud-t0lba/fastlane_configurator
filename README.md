# fastlane_configurator

`fastlane_configurator` is a Dart CLI package that bootstraps Fastlane configuration for Flutter projects.

It provides ready commands to:

- generate Fastlane files (`Fastfile`, `Appfile`, `.env.default`, `Pluginfile`)
- generate GitHub Actions workflow for Android/iOS CI delivery
- fetch project/git/GitHub metadata into JSON for CI and release automation
- wire Firebase App Distribution lanes directly

## Install

### Global CLI install

```bash
dart pub global activate fastlane_configurator
```

If needed, add pub global binaries to your PATH:

```bash
export PATH="$PATH:$HOME/.pub-cache/bin"
```

## Use this package as an executable

Fastest usage after install:

```bash
fastlane_configurator --help
```

Short alias:

```bash
flc --help
```

Run without global install:

```bash
dart run fastlane_configurator:fastlane_configurator --help
```

## Commands

### 1) One-shot init (recommended)

Use this after install to prepare everything automatically:

```bash
flc init --project-root . --firebase-project your-firebase-project-id --overwrite
```

This single command does:

- `setup` (Fastlane + workflow files)
- `firebase-sync` (fetch from Firebase CLI and auto-inject values)
- `fetch-data` (project metadata JSON for CI)

### 2) Setup project delivery files only

```bash
fastlane_configurator setup --project-root . --overwrite
# or:
flc setup --project-root . --overwrite
```

Generated files:

- `fastlane/Fastfile`
- `fastlane/Appfile`
- `fastlane/Pluginfile`
- `fastlane/.env.default`
- `.github/workflows/mobile_delivery.yml`

Useful setup flags:

- `--no-ci` skip workflow generation
- `--no-env` skip `.env.default` generation
- `--ci-branch main` set workflow push branch
- `--workflow-filename mobile_delivery.yml` customize workflow filename
- `--ios-bundle-id com.example.app` manual override
- `--android-package-name com.example.app` manual override

### 3) Firebase sync (auto-fetch + auto-inject)

```bash
flc firebase-sync --project-root . --firebase-project your-firebase-project-id --overwrite
```

This creates:

- `fastlane/firebase_data.json`

And updates automatically:

- `fastlane/.env.default`
  - `FIREBASE_PROJECT_ID`
  - `FIREBASE_APP_ID_ANDROID`
  - `FIREBASE_APP_ID_IOS`
  - `FASTLANE_ANDROID_PACKAGE_NAME`
  - `FASTLANE_APP_IDENTIFIER`

If Firebase CLI is not configured yet and you want to skip hard failure:

```bash
flc firebase-sync --project-root . --optional
```

If the local project is not connected to Firebase yet, `firebase-sync` now
auto-connects it by setting `.firebaserc` default project and retrying.

### 4) Fetch metadata for CI

```bash
fastlane_configurator fetch-data --project-root . --output-path fastlane/build_data.json --include-github
# or:
flc fetch-data --project-root . --output-path fastlane/build_data.json --include-github
```

This writes a JSON file with:

- app package name and version
- inferred iOS/Android identifiers
- git branch/sha/tag
- optional GitHub latest release/workflow run

Use `--no-include-github` to skip GitHub API calls.

## Required environment variables for generated lanes/workflow

- `FIREBASE_TOKEN`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_APP_ID_ANDROID`
- `FIREBASE_APP_ID_IOS`
- `FIREBASE_TESTER_GROUPS`
- `GITHUB_REPOSITORY`
- `GITHUB_TOKEN`
- `FASTLANE_APP_IDENTIFIER`
- `FASTLANE_ANDROID_PACKAGE_NAME`
