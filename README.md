# fastlane-plugin-fastlane_configurator

Fastlane plugin to bootstrap a Flutter project's delivery setup as ready-to-run commands.

After installation, you can run commands to:

- generate Fastlane config files
- fetch build/release metadata as JSON
- wire CI directly with GitHub Actions
- distribute builds directly to Firebase App Distribution

## Install

### Local path (this repository)

In target project `fastlane/Pluginfile`:

```ruby
gem "fastlane-plugin-fastlane_configurator", path: "/Users/tolba/StudioProjects/fastlane"
```

Then:

```bash
bundle install
```

### RubyGems (after publishing)

```ruby
gem "fastlane-plugin-fastlane_configurator"
```

## Main commands

### 1) Bootstrap full setup

```bash
bundle exec fastlane run configure_fastlane overwrite:true
```

This creates/updates:

- `fastlane/Fastfile`
- `fastlane/Appfile`
- `fastlane/Pluginfile`
- `fastlane/.env.default`
- `.github/workflows/mobile_delivery.yml`

### 2) Fetch data (local + git + GitHub API)

```bash
bundle exec fastlane run fetch_mobile_data output_path:"fastlane/build_data.json"
```

### 3) Run ready lanes

```bash
bundle exec fastlane fetch_data
bundle exec fastlane android ci_android
bundle exec fastlane ios ci_ios
```

## Generated lanes

Top-level lane:

- `fetch_data`: writes `fastlane/build_data.json`

Android lanes:

- `build_android`
- `firebase_android`
- `release_android`
- `ci_android` (fetch + build + firebase)

iOS lanes:

- `build_ios`
- `firebase_ios`
- `release_ios`
- `ci_ios` (fetch + build + firebase)

## Required environment variables

Set these in local shell or GitHub Secrets/Vars:

- `FIREBASE_TOKEN`
- `FIREBASE_APP_ID_ANDROID`
- `FIREBASE_APP_ID_IOS`
- `FIREBASE_TESTER_GROUPS`
- `GITHUB_REPOSITORY`
- `GITHUB_TOKEN`
- `FASTLANE_APP_IDENTIFIER`
- `FASTLANE_ANDROID_PACKAGE_NAME`

## Workflow behavior

Generated workflow `.github/workflows/mobile_delivery.yml`:

- runs Android on `ubuntu-latest`
- runs iOS on `macos-latest` only if `vars.ENABLE_IOS == 'true'`
- installs Firebase CLI and triggers Fastlane CI lanes directly
