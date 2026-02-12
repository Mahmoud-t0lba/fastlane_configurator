import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

/// Writes a single line message to CLI output.
typedef LineWriter = void Function(String message);

/// Abstraction for spawning shell commands.
///
/// This allows tests to mock external processes (like `firebase` and `git`).
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

/// Prompts the user and returns one-line input.
typedef PromptReader = String? Function(String prompt);

@Deprecated('Use FastlaneCli instead.')
typedef FastlaneConfiguratorCli = FastlaneCli;

/// CLI entrypoint for generating and syncing Fastlane/Firebase configuration.
///
/// Backward compatibility:
/// `FastlaneConfiguratorCli` remains available as a deprecated type alias.
class FastlaneCli {
  /// Creates a new CLI runner.
  ///
  /// Optional dependencies can be injected for custom output and testing.
  FastlaneCli({
    LineWriter? out,
    LineWriter? err,
    http.Client? httpClient,
    ProcessRunner? processRunner,
    PromptReader? promptReader,
  })  : _out = out ?? ((message) => stdout.writeln(message)),
        _err = err ?? ((message) => stderr.writeln(message)),
        _httpClient = httpClient ?? http.Client(),
        _processRunner = processRunner ??
            ((executable, arguments, {workingDirectory}) => Process.run(
                  executable,
                  arguments,
                  workingDirectory: workingDirectory,
                )),
        _promptReader = promptReader ??
            ((prompt) {
              stdout.write(prompt);
              return stdin.readLineSync();
            });

  final LineWriter _out;
  final LineWriter _err;
  final http.Client _httpClient;
  final ProcessRunner _processRunner;
  final PromptReader _promptReader;

  ArgParser _buildParser() {
    final parser = ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show this help message.',
      );

    parser.addCommand('init', _initParser());
    parser.addCommand('setup', _setupParser());
    parser.addCommand('firebase-sync', _firebaseSyncParser());
    parser.addCommand('fetch-data', _fetchDataParser());
    return parser;
  }

  ArgParser _initParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show init command help.',
      )
      ..addOption(
        'project-root',
        help: 'Root path of target Flutter project.',
        defaultsTo: '.',
      )
      ..addFlag(
        'overwrite',
        help: 'Overwrite existing generated files.',
        defaultsTo: false,
      )
      ..addFlag(
        'ci',
        help: 'Generate .github/workflows workflow.',
        defaultsTo: true,
        negatable: true,
      )
      ..addFlag(
        'env',
        help: 'Generate fastlane/.env.default file.',
        defaultsTo: true,
        negatable: true,
      )
      ..addOption(
        'workflow-filename',
        help: 'Workflow filename under .github/workflows.',
        defaultsTo: 'mobile_delivery.yml',
      )
      ..addOption(
        'ci-branch',
        help: 'Branch that triggers workflow push.',
        defaultsTo: 'main',
      )
      ..addOption(
        'ios-bundle-id',
        help: 'Manual iOS bundle id override.',
      )
      ..addOption(
        'android-package-name',
        help: 'Manual Android package name override.',
      )
      ..addOption(
        'apple-id',
        help: 'Apple ID email for App Store Connect operations.',
      )
      ..addOption(
        'team-id',
        help: 'Apple Developer Team ID.',
      )
      ..addOption(
        'itc-team-id',
        help: 'App Store Connect Team ID.',
      )
      ..addOption(
        'firebase-project',
        help:
            'Firebase project id. If omitted, CLI tries active firebase target.',
      )
      ..addOption(
        'firebase-output-path',
        help: 'Firebase metadata JSON output path.',
        defaultsTo: 'fastlane/firebase_data.json',
      )
      ..addOption(
        'appdist-groups',
        help:
            'Comma-separated Firebase App Distribution group aliases to ensure/create.',
      )
      ..addFlag(
        'appdist-skip-group-setup',
        help: 'Skip Firebase App Distribution group setup.',
        defaultsTo: false,
      )
      ..addFlag(
        'firebase-optional',
        help: 'Skip firebase sync errors if Firebase CLI is unavailable.',
        defaultsTo: false,
      )
      ..addOption(
        'output-path',
        help: 'General metadata JSON output path.',
        defaultsTo: 'fastlane/build_data.json',
      )
      ..addFlag(
        'include-github',
        help: 'Include latest release and workflow run data from GitHub API.',
        defaultsTo: false,
        negatable: true,
      )
      ..addOption(
        'github-repository',
        help: 'GitHub repository in owner/repo format.',
      )
      ..addOption(
        'github-token',
        help: 'GitHub token for authenticated API requests.',
      );
  }

  ArgParser _setupParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show setup command help.',
      )
      ..addOption(
        'project-root',
        help: 'Root path of target Flutter project.',
        defaultsTo: '.',
      )
      ..addFlag(
        'overwrite',
        help: 'Overwrite existing generated files.',
        defaultsTo: false,
      )
      ..addFlag(
        'ci',
        help: 'Generate .github/workflows workflow.',
        defaultsTo: true,
        negatable: true,
      )
      ..addFlag(
        'env',
        help: 'Generate fastlane/.env.default file.',
        defaultsTo: true,
        negatable: true,
      )
      ..addOption(
        'workflow-filename',
        help: 'Workflow filename under .github/workflows.',
        defaultsTo: 'mobile_delivery.yml',
      )
      ..addOption(
        'ci-branch',
        help: 'Branch that triggers workflow push.',
        defaultsTo: 'main',
      )
      ..addOption(
        'ios-bundle-id',
        help: 'Manual iOS bundle id override.',
      )
      ..addOption(
        'android-package-name',
        help: 'Manual Android package name override.',
      )
      ..addOption(
        'apple-id',
        help: 'Apple ID email for App Store Connect operations.',
      )
      ..addOption(
        'team-id',
        help: 'Apple Developer Team ID.',
      )
      ..addOption(
        'itc-team-id',
        help: 'App Store Connect Team ID.',
      );
  }

  ArgParser _fetchDataParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show fetch-data command help.',
      )
      ..addOption(
        'project-root',
        help: 'Root path of target Flutter project.',
        defaultsTo: '.',
      )
      ..addOption(
        'output-path',
        help: 'Output JSON file path.',
        defaultsTo: 'fastlane/build_data.json',
      )
      ..addFlag(
        'include-github',
        help: 'Include latest release and workflow run data from GitHub API.',
        defaultsTo: true,
        negatable: true,
      )
      ..addOption(
        'github-repository',
        help: 'GitHub repository in owner/repo format.',
      )
      ..addOption(
        'github-token',
        help: 'GitHub token for authenticated API requests.',
      );
  }

  ArgParser _firebaseSyncParser() {
    return ArgParser()
      ..addFlag(
        'help',
        abbr: 'h',
        negatable: false,
        help: 'Show firebase-sync command help.',
      )
      ..addOption(
        'project-root',
        help: 'Root path of target Flutter project.',
        defaultsTo: '.',
      )
      ..addOption(
        'firebase-project',
        help:
            'Firebase project id. If omitted, CLI tries active firebase target.',
      )
      ..addOption(
        'output-path',
        help: 'Firebase metadata JSON output path.',
        defaultsTo: 'fastlane/firebase_data.json',
      )
      ..addOption(
        'env-path',
        help: 'Environment file path to update with fetched Firebase values.',
        defaultsTo: 'fastlane/.env.default',
      )
      ..addFlag(
        'update-env',
        help: 'Update env file automatically with fetched values.',
        defaultsTo: true,
        negatable: true,
      )
      ..addFlag(
        'overwrite',
        help: 'Overwrite existing env values when update-env is enabled.',
        defaultsTo: true,
      )
      ..addFlag(
        'optional',
        help: 'Skip errors if Firebase CLI is unavailable or not configured.',
        defaultsTo: false,
      )
      ..addOption(
        'appdist-groups',
        help:
            'Comma-separated Firebase App Distribution group aliases to ensure/create.',
      )
      ..addFlag(
        'skip-group-setup',
        help: 'Skip Firebase App Distribution group setup.',
        defaultsTo: false,
      );
  }

  /// Runs the CLI command and returns a process-style exit code.
  ///
  /// Returns `0` on success, `64` for usage errors, and `1` for runtime errors.
  Future<int> run(List<String> args) async {
    final parser = _buildParser();
    try {
      final results = parser.parse(args);

      if (results['help'] as bool) {
        _out(_topLevelUsage(parser));
        return 0;
      }

      final command = results.command;
      if (command == null) {
        _err('Missing command.');
        _out(_topLevelUsage(parser));
        return 64;
      }

      final commandParser = parser.commands[command.name]!;
      if (command['help'] as bool) {
        _out(_commandUsage(command.name!, commandParser));
        return 0;
      }

      switch (command.name) {
        case 'init':
          await _runInit(command);
          return 0;
        case 'setup':
          await _runSetup(command);
          return 0;
        case 'firebase-sync':
          await _runFirebaseSync(command);
          return 0;
        case 'fetch-data':
          await _runFetchData(command);
          return 0;
        default:
          _err('Unknown command: ${command.name}');
          _out(_topLevelUsage(parser));
          return 64;
      }
    } on ArgParserException catch (error) {
      _err(error.message);
      _out(_topLevelUsage(parser));
      return 64;
    } catch (error) {
      _err('Error: $error');
      return 1;
    }
  }

  String _topLevelUsage(ArgParser parser) {
    return '''
Configure Fastlane + Firebase + GitHub Actions for Flutter projects.

Usage:
  fastlane_cli <command> [options]

Commands:
  init          One-shot setup + Firebase sync + metadata fetch.
  setup         Generate Fastlane, env, and GitHub Actions configuration files.
  firebase-sync Fetch Firebase apps/project data and inject it into project files.
  fetch-data    Collect project/git/GitHub metadata into JSON.

Global options:
${parser.usage}
''';
  }

  String _commandUsage(String commandName, ArgParser commandParser) {
    return '''
Usage:
  fastlane_cli $commandName [options]

Options:
${commandParser.usage}
''';
  }

  Future<void> _runInit(ArgResults command) async {
    final projectRoot =
        p.normalize(p.absolute(_stringValue(command['project-root']) ?? '.'));
    final overwrite = command['overwrite'] as bool;

    await _runSetupInternal(
      projectRoot: projectRoot,
      overwrite: overwrite,
      configureCi: command['ci'] as bool,
      configureEnv: command['env'] as bool,
      workflowFilename:
          _stringValue(command['workflow-filename']) ?? 'mobile_delivery.yml',
      ciBranch: _stringValue(command['ci-branch']) ?? 'main',
      iosBundleIdOverride: _stringValue(command['ios-bundle-id']),
      androidPackageNameOverride: _stringValue(command['android-package-name']),
      appleId: _stringValue(command['apple-id']),
      teamId: _stringValue(command['team-id']),
      itcTeamId: _stringValue(command['itc-team-id']),
    );

    await _runFirebaseSyncInternal(
      projectRoot: projectRoot,
      firebaseProject: _stringValue(command['firebase-project']),
      outputPath: _stringValue(command['firebase-output-path']) ??
          'fastlane/firebase_data.json',
      envPath: p.join(projectRoot, 'fastlane', '.env.default'),
      updateEnv: true,
      overwrite: true,
      optional: command['firebase-optional'] as bool,
      appDistributionGroups: _stringValue(command['appdist-groups']),
      setupAppDistributionGroups:
          !(command['appdist-skip-group-setup'] as bool),
    );

    await _runFetchDataInternal(
      projectRoot: projectRoot,
      outputPath:
          _stringValue(command['output-path']) ?? 'fastlane/build_data.json',
      includeGithub: command['include-github'] as bool,
      repository: _stringValue(command['github-repository']) ??
          _stringValue(Platform.environment['GITHUB_REPOSITORY']),
      token: _stringValue(command['github-token']) ??
          _stringValue(Platform.environment['GITHUB_TOKEN']),
    );

    _out('Init complete for: $projectRoot');
  }

  Future<void> _runSetup(ArgResults command) async {
    final projectRoot =
        p.normalize(p.absolute(_stringValue(command['project-root']) ?? '.'));
    await _runSetupInternal(
      projectRoot: projectRoot,
      overwrite: command['overwrite'] as bool,
      configureCi: command['ci'] as bool,
      configureEnv: command['env'] as bool,
      workflowFilename:
          _stringValue(command['workflow-filename']) ?? 'mobile_delivery.yml',
      ciBranch: _stringValue(command['ci-branch']) ?? 'main',
      iosBundleIdOverride: _stringValue(command['ios-bundle-id']),
      androidPackageNameOverride: _stringValue(command['android-package-name']),
      appleId: _stringValue(command['apple-id']),
      teamId: _stringValue(command['team-id']),
      itcTeamId: _stringValue(command['itc-team-id']),
    );
  }

  Future<void> _runSetupInternal({
    required String projectRoot,
    required bool overwrite,
    required bool configureCi,
    required bool configureEnv,
    required String workflowFilename,
    required String ciBranch,
    required String? iosBundleIdOverride,
    required String? androidPackageNameOverride,
    required String? appleId,
    required String? teamId,
    required String? itcTeamId,
  }) async {
    final iosBundleId = iosBundleIdOverride ??
        _inferIosBundleId(projectRoot) ??
        'com.example.app';
    final androidPackageName = androidPackageNameOverride ??
        _inferAndroidPackageName(projectRoot) ??
        'com.example.app';

    final fastlaneDir = Directory(p.join(projectRoot, 'fastlane'));
    fastlaneDir.createSync(recursive: true);

    final results = <String, String>{};
    results['fastlane/Fastfile'] = _writeTextFile(
      p.join(projectRoot, 'fastlane', 'Fastfile'),
      _buildFastfile(androidPackageName),
      overwrite,
    );
    results['fastlane/Appfile'] = _writeTextFile(
      p.join(projectRoot, 'fastlane', 'Appfile'),
      _buildAppfile(
        iosBundleId: iosBundleId,
        appleId: appleId,
        teamId: teamId,
        itcTeamId: itcTeamId,
      ),
      overwrite,
    );
    results['fastlane/Pluginfile'] = _ensurePluginfile(
      p.join(projectRoot, 'fastlane', 'Pluginfile'),
      overwrite,
    );
    results['fastlane/scripts/sync_cli_env.sh'] = _writeTextFile(
      p.join(projectRoot, 'fastlane', 'scripts', 'sync_cli_env.sh'),
      _buildSyncCliEnvScript(),
      overwrite,
    );
    results['fastlane/scripts/apple_account_info.sh'] = _writeTextFile(
      p.join(projectRoot, 'fastlane', 'scripts', 'apple_account_info.sh'),
      _buildAppleAccountInfoScript(),
      overwrite,
    );

    if (configureEnv) {
      results['fastlane/.env.default'] = _writeTextFile(
        p.join(projectRoot, 'fastlane', '.env.default'),
        _buildEnvFile(
          iosBundleId: iosBundleId,
          androidPackageName: androidPackageName,
          appleId: appleId,
          teamId: teamId,
          itcTeamId: itcTeamId,
        ),
        overwrite,
      );
    }

    if (configureCi) {
      final workflowPath =
          p.join(projectRoot, '.github', 'workflows', workflowFilename);
      results['.github/workflows/$workflowFilename'] = _writeTextFile(
        workflowPath,
        _buildGithubWorkflow(ciBranch),
        overwrite,
      );
    }

    _out('Setup complete for: $projectRoot');
    _out('Detected iOS bundle id: $iosBundleId');
    _out('Detected Android package: $androidPackageName');
    for (final entry in results.entries) {
      _out('- ${entry.key}: ${entry.value}');
    }
  }

  Future<void> _runFirebaseSync(ArgResults command) async {
    final projectRoot =
        p.normalize(p.absolute(_stringValue(command['project-root']) ?? '.'));
    await _runFirebaseSyncInternal(
      projectRoot: projectRoot,
      firebaseProject: _stringValue(command['firebase-project']),
      outputPath:
          _stringValue(command['output-path']) ?? 'fastlane/firebase_data.json',
      envPath: _resolveAbsolutePath(
        projectRoot,
        _stringValue(command['env-path']) ?? 'fastlane/.env.default',
      ),
      updateEnv: command['update-env'] as bool,
      overwrite: command['overwrite'] as bool,
      optional: command['optional'] as bool,
      appDistributionGroups: _stringValue(command['appdist-groups']),
      setupAppDistributionGroups: !(command['skip-group-setup'] as bool),
    );
  }

  Future<void> _runFirebaseSyncInternal({
    required String projectRoot,
    required String? firebaseProject,
    required String outputPath,
    required String envPath,
    required bool updateEnv,
    required bool overwrite,
    required bool optional,
    required String? appDistributionGroups,
    required bool setupAppDistributionGroups,
  }) async {
    final loggedIn = await _ensureFirebaseLogin(
      projectRoot: projectRoot,
      optional: optional,
    );
    if (!loggedIn) {
      if (optional) {
        _out('Firebase sync skipped: unable to login to Firebase CLI.');
        return;
      }
      throw Exception('Unable to login to Firebase CLI.');
    }

    final resolvedProject = await _resolveOrCreateFirebaseProject(
      projectRoot: projectRoot,
      firebaseProject: firebaseProject,
      optional: optional,
    );
    if (resolvedProject == null) {
      if (optional) {
        _out('Firebase sync skipped: no Firebase project id resolved.');
        return;
      }
      throw Exception(
        'Firebase project not found. Pass --firebase-project or set FIREBASE_PROJECT_ID.',
      );
    }

    await _ensureFirebaseProjectLinked(
      projectRoot: projectRoot,
      projectId: resolvedProject,
      optional: true,
    );

    await _ensureFirebaseCoreDependency(projectRoot: projectRoot);

    await _runFlutterfireConfigure(
      projectRoot: projectRoot,
      projectId: resolvedProject,
      optional: true,
    );

    final resolvedGroupAliases = _resolveAppDistributionGroupAliases(
      envPath: envPath,
      explicitGroups: appDistributionGroups,
    );
    if (setupAppDistributionGroups) {
      await _ensureFirebaseAppDistributionGroups(
        projectRoot: projectRoot,
        projectId: resolvedProject,
        groupAliases: resolvedGroupAliases,
        optional: true,
      );
    }

    var appsResponse = await _runCommand(
      'firebase',
      <String>['apps:list', '--project', resolvedProject, '--json'],
      projectRoot,
      optional: optional,
    );
    if (appsResponse == null) {
      _out('Firebase sync skipped: Firebase CLI is unavailable.');
      return;
    }
    if (appsResponse.exitCode != 0) {
      _out(
        'firebase apps:list failed, trying to connect Firebase project and retry...',
      );
      await _ensureFirebaseProjectLinked(
        projectRoot: projectRoot,
        projectId: resolvedProject,
        optional: true,
      );

      final retry = await _runCommand(
        'firebase',
        <String>['apps:list', '--project', resolvedProject, '--json'],
        projectRoot,
        optional: optional,
      );
      if (retry == null) {
        _out('Firebase sync skipped: Firebase CLI is unavailable.');
        return;
      }
      appsResponse = retry;
    }

    if (appsResponse.exitCode != 0) {
      if (optional) {
        _out('Firebase sync skipped: apps:list failed after retry.');
        return;
      }
      throw Exception(
        'firebase apps:list failed: ${appsResponse.stderr.toString().trim()}\n'
        'Tip: run "firebase login" then retry, or pass --firebase-project.',
      );
    }

    final appsDecoded = _decodeJsonOrEmpty(appsResponse.stdout.toString());
    final apps = _extractFirebaseApps(appsDecoded);
    final androidApp = _findFirebaseApp(apps, 'ANDROID');
    final iosApp = _findFirebaseApp(apps, 'IOS');

    String? projectNumber;
    final projectsResponse = await _runCommand(
      'firebase',
      <String>['projects:list', '--json'],
      projectRoot,
      optional: true,
    );
    if (projectsResponse != null && projectsResponse.exitCode == 0) {
      final projectsDecoded =
          _decodeJsonOrEmpty(projectsResponse.stdout.toString());
      projectNumber =
          _extractFirebaseProjectNumber(projectsDecoded, resolvedProject);
    }

    final payload = <String, Object?>{
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'firebase_project_id': resolvedProject,
      'firebase_project_number': projectNumber,
      'android_app_id': _stringValue(androidApp?['appId']),
      'ios_app_id': _stringValue(iosApp?['appId']),
      'apps': apps
          .map((app) => <String, Object?>{
                'app_id': _stringValue(app['appId']),
                'platform': _stringValue(app['platform']),
                'display_name': _stringValue(app['displayName']),
                'package_name': _stringValue(app['packageName']),
                'bundle_id': _stringValue(app['bundleId']),
              })
          .toList(),
    };

    final absoluteOutputPath = _resolveAbsolutePath(projectRoot, outputPath);
    final outputFile = File(absoluteOutputPath);
    outputFile.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    outputFile.writeAsStringSync('${encoder.convert(payload)}\n');
    _out('Firebase data written to $absoluteOutputPath');

    if (updateEnv) {
      final envUpdates = <String, String?>{
        'FIREBASE_PROJECT_ID': resolvedProject,
        'FIREBASE_APP_ID_ANDROID': _stringValue(androidApp?['appId']),
        'FIREBASE_APP_ID_IOS': _stringValue(iosApp?['appId']),
        'FASTLANE_ANDROID_PACKAGE_NAME':
            _stringValue(androidApp?['packageName']),
        'FASTLANE_APP_IDENTIFIER': _stringValue(iosApp?['bundleId']),
        if (resolvedGroupAliases.isNotEmpty)
          'FIREBASE_TESTER_GROUPS': resolvedGroupAliases.join(','),
      };

      final envStatus = _upsertEnvFile(
        path: envPath,
        values: envUpdates,
        overwrite: overwrite,
      );
      _out('- ${p.relative(envPath, from: projectRoot)}: $envStatus');
    }
  }

  Future<void> _runFetchData(ArgResults command) async {
    final projectRoot =
        p.normalize(p.absolute(_stringValue(command['project-root']) ?? '.'));
    await _runFetchDataInternal(
      projectRoot: projectRoot,
      outputPath:
          _stringValue(command['output-path']) ?? 'fastlane/build_data.json',
      includeGithub: command['include-github'] as bool,
      repository: _stringValue(command['github-repository']) ??
          _stringValue(Platform.environment['GITHUB_REPOSITORY']),
      token: _stringValue(command['github-token']) ??
          _stringValue(Platform.environment['GITHUB_TOKEN']),
    );
  }

  Future<void> _runFetchDataInternal({
    required String projectRoot,
    required String outputPath,
    required bool includeGithub,
    required String? repository,
    required String? token,
  }) async {
    final appData = _readPubspecAppData(projectRoot);

    final payload = <String, Object?>{
      'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
      'project_root': projectRoot,
      'app': <String, Object?>{
        'name': appData['name'],
        'version': appData['version'],
        'version_name': appData['version_name'],
        'version_code': appData['version_code'],
        'version_source': appData['version_source'],
      },
      'identifiers': <String, Object?>{
        'ios_bundle_id': _inferIosBundleId(projectRoot),
        'android_package_name': _inferAndroidPackageName(projectRoot),
      },
      'git': <String, Object?>{
        'branch': await _gitOutput(projectRoot, const <String>[
          'rev-parse',
          '--abbrev-ref',
          'HEAD',
        ]),
        'sha':
            await _gitOutput(projectRoot, const <String>['rev-parse', 'HEAD']),
        'latest_tag': await _gitOutput(projectRoot, const <String>[
          'describe',
          '--tags',
          '--abbrev=0',
        ]),
      },
    };

    if (includeGithub) {
      payload['github'] = await _buildGithubPayload(repository, token);
    }

    final absoluteOutputPath = _resolveAbsolutePath(projectRoot, outputPath);
    final outputFile = File(absoluteOutputPath);
    outputFile.parent.createSync(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    outputFile.writeAsStringSync('${encoder.convert(payload)}\n');

    _out('Metadata written to $absoluteOutputPath');
  }

  String? _stringValue(Object? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }

  Map<String, String?> _readPubspecAppData(String projectRoot) {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return <String, String?>{
        'name': null,
        'version': null,
        'version_name': null,
        'version_code': null,
        'version_source': null,
      };
    }

    final yaml = loadYaml(pubspecFile.readAsStringSync());
    if (yaml is! YamlMap) {
      return <String, String?>{
        'name': null,
        'version': null,
        'version_name': null,
        'version_code': null,
        'version_source': null,
      };
    }

    final name = _stringValue(yaml['name']);
    final version = _stringValue(yaml['version']);

    String? versionName;
    String? versionCode;
    if (version != null) {
      final parts = version.split('+');
      versionName = parts[0];
      if (parts.length > 1) {
        versionCode = parts[1];
      }
    }

    return <String, String?>{
      'name': name,
      'version': version,
      'version_name': versionName,
      'version_code': versionCode,
      'version_source': 'pubspec.yaml',
    };
  }

  String _resolveAbsolutePath(String projectRoot, String path) {
    return p.isAbsolute(path) ? path : p.join(projectRoot, path);
  }

  Future<void> _ensureFirebaseProjectLinked({
    required String projectRoot,
    required String projectId,
    required bool optional,
  }) async {
    _setFirebasercDefaultProject(projectRoot, projectId);

    final useResult = await _runCommand(
      'firebase',
      <String>['use', projectId],
      projectRoot,
      optional: true,
    );

    if (useResult == null) {
      return;
    }
    if (useResult.exitCode != 0) {
      final stderr = useResult.stderr.toString().trim();
      if (stderr.isNotEmpty) {
        _out('firebase use warning: $stderr');
      } else if (!optional) {
        _out('firebase use returned non-zero exit code.');
      }
    }
  }

  void _setFirebasercDefaultProject(String projectRoot, String projectId) {
    final firebasercPath = p.join(projectRoot, '.firebaserc');
    final file = File(firebasercPath);

    Map<String, dynamic> root = <String, dynamic>{};
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          root = decoded;
        }
      } catch (_) {
        root = <String, dynamic>{};
      }
    }

    final projects = <String, dynamic>{};
    final existingProjects = root['projects'];
    if (existingProjects is Map) {
      existingProjects.forEach((key, value) {
        if (key != null) {
          projects[key.toString()] = value;
        }
      });
    }
    projects['default'] = projectId;
    root['projects'] = projects;

    const encoder = JsonEncoder.withIndent('  ');
    file.writeAsStringSync('${encoder.convert(root)}\n');
  }

  Future<ProcessResult?> _runCommand(
    String executable,
    List<String> args,
    String workingDirectory, {
    bool optional = false,
  }) async {
    try {
      return await _processRunner(
        executable,
        args,
        workingDirectory: workingDirectory,
      );
    } on ProcessException catch (error) {
      if (optional) {
        _out(
          'Skipping command "$executable ${args.join(' ')}": ${error.message}',
        );
        return null;
      }
      rethrow;
    }
  }

  Future<bool> _ensureFirebaseLogin({
    required String projectRoot,
    required bool optional,
  }) async {
    final loginList = await _runCommand(
      'firebase',
      const <String>['login:list', '--json'],
      projectRoot,
      optional: true,
    );

    final loggedIn = _hasFirebaseLoggedInUser(loginList);
    if (loggedIn) {
      return true;
    }

    _out('Firebase login required. Running "firebase login"...');
    final loginResult = await _runCommand(
      'firebase',
      const <String>['login'],
      projectRoot,
      optional: true,
    );
    if (loginResult == null) {
      return false;
    }

    if (loginResult.exitCode != 0) {
      final stderr = loginResult.stderr.toString().trim();
      if (stderr.isNotEmpty) {
        _err('firebase login failed: $stderr');
      }
      return optional ? false : false;
    }

    return true;
  }

  bool _hasFirebaseLoggedInUser(ProcessResult? loginListResult) {
    if (loginListResult == null || loginListResult.exitCode != 0) {
      return false;
    }

    final decoded = _decodeJsonOrEmpty(loginListResult.stdout.toString());
    if (decoded is List) {
      return decoded.isNotEmpty;
    }
    if (decoded is Map<String, dynamic>) {
      final result = decoded['result'];
      if (result is List && result.isNotEmpty) {
        return true;
      }
      final user = decoded['user'];
      if (user is String && user.trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  Future<String?> _resolveOrCreateFirebaseProject({
    required String projectRoot,
    required String? firebaseProject,
    required bool optional,
  }) async {
    final resolved =
        await _resolveFirebaseProject(projectRoot, firebaseProject);
    if (resolved != null) {
      final exists = await _firebaseProjectExists(
        projectRoot: projectRoot,
        projectId: resolved,
      );
      if (exists != false) {
        return resolved;
      }

      final selected = await _selectFirebaseProjectFromAccount(
        projectRoot: projectRoot,
      );
      if (selected != null) {
        return selected;
      }

      if (optional) {
        return null;
      }
      _out('Firebase project "$resolved" was not found in your account.');
      final createResolved = _promptYesNo(
        'Create Firebase project "$resolved" now? (yes/no): ',
      );
      if (!createResolved) {
        throw Exception(
          'Firebase project "$resolved" is not available. '
          'Use a valid --firebase-project value.',
        );
      }

      final suggestedDisplayName = _suggestFirebaseDisplayName(projectRoot);
      final enteredDisplayName = _stringValue(
        _promptReader('Firebase display name [$suggestedDisplayName]: '),
      );
      final displayName = enteredDisplayName ?? suggestedDisplayName;
      await _createFirebaseProject(
        projectRoot: projectRoot,
        projectId: resolved,
        displayName: displayName,
      );
      return resolved;
    }

    final selected = await _selectFirebaseProjectFromAccount(
      projectRoot: projectRoot,
    );
    if (selected != null) {
      return selected;
    }

    if (optional) {
      return null;
    }

    final allowed = _promptYesNo(
      'No Firebase project is linked. Create a new Firebase project now? (yes/no): ',
    );
    if (!allowed) {
      return null;
    }

    final suggestedProjectId = _suggestFirebaseProjectId(projectRoot);
    final enteredProjectId = _stringValue(
      _promptReader('Firebase project id [$suggestedProjectId]: '),
    );
    final projectId = enteredProjectId ?? suggestedProjectId;

    final suggestedDisplayName = _suggestFirebaseDisplayName(projectRoot);
    final enteredDisplayName = _stringValue(
      _promptReader('Firebase display name [$suggestedDisplayName]: '),
    );
    final displayName = enteredDisplayName ?? suggestedDisplayName;

    await _createFirebaseProject(
      projectRoot: projectRoot,
      projectId: projectId,
      displayName: displayName,
    );
    return projectId;
  }

  Future<void> _createFirebaseProject({
    required String projectRoot,
    required String projectId,
    required String displayName,
  }) async {
    if (_looksLikePlaceholderFirebaseProject(projectId)) {
      throw Exception(
        'Invalid Firebase project id "$projectId". '
        'Replace placeholders with a real project id.',
      );
    }

    _out('Creating Firebase project "$projectId"...');
    final createResult = await _runCommand(
      'firebase',
      <String>[
        'projects:create',
        projectId,
        '--display-name',
        displayName,
      ],
      projectRoot,
      optional: false,
    );
    if (createResult == null || createResult.exitCode != 0) {
      throw Exception(
        'firebase projects:create failed: '
        '${createResult?.stderr.toString().trim() ?? 'unknown error'}',
      );
    }

    _out('Firebase project created: $projectId');
  }

  Future<String?> _selectFirebaseProjectFromAccount({
    required String projectRoot,
  }) async {
    final projects = await _listFirebaseProjects(projectRoot);
    if (projects == null || projects.isEmpty) {
      return null;
    }

    if (projects.length == 1) {
      final projectId = projects.first['projectId']!;
      _out('Using Firebase project "$projectId" from your account.');
      return projectId;
    }

    _out('Select Firebase project to use:');
    _out('0) Create new Firebase project');
    for (var i = 0; i < projects.length; i++) {
      final project = projects[i];
      final projectId = project['projectId']!;
      final displayName = project['displayName'];
      final displaySuffix =
          displayName == null ? '' : ' (${displayName.trim()})';
      _out('${i + 1}) $projectId$displaySuffix');
    }

    final answer = _stringValue(
      _promptReader(
        'Enter project number, project id, or 0 to create new (leave empty to skip): ',
      ),
    );
    if (answer == null) {
      return null;
    }

    final normalizedAnswer = answer.toLowerCase();
    if (normalizedAnswer == '0' ||
        normalizedAnswer == 'new' ||
        normalizedAnswer == 'create') {
      final suggestedProjectId = _suggestFirebaseProjectId(projectRoot);
      final enteredProjectId = _stringValue(
        _promptReader('Firebase project id [$suggestedProjectId]: '),
      );
      final projectId = enteredProjectId ?? suggestedProjectId;

      final suggestedDisplayName = _suggestFirebaseDisplayName(projectRoot);
      final enteredDisplayName = _stringValue(
        _promptReader('Firebase display name [$suggestedDisplayName]: '),
      );
      final displayName = enteredDisplayName ?? suggestedDisplayName;
      await _createFirebaseProject(
        projectRoot: projectRoot,
        projectId: projectId,
        displayName: displayName,
      );
      return projectId;
    }

    final index = int.tryParse(answer);
    if (index != null && index >= 1 && index <= projects.length) {
      return projects[index - 1]['projectId'];
    }

    for (final project in projects) {
      if (project['projectId'] == answer) {
        return answer;
      }
    }

    _out('Invalid Firebase project selection: "$answer".');
    return null;
  }

  Future<List<Map<String, String?>>?> _listFirebaseProjects(
    String projectRoot,
  ) async {
    final projectsResponse = await _runCommand(
      'firebase',
      const <String>['projects:list', '--json'],
      projectRoot,
      optional: true,
    );
    if (projectsResponse == null || projectsResponse.exitCode != 0) {
      return null;
    }

    final decoded = _decodeJsonOrEmpty(projectsResponse.stdout.toString());
    return _extractFirebaseProjects(decoded);
  }

  Future<bool?> _firebaseProjectExists({
    required String projectRoot,
    required String projectId,
  }) async {
    final projects = await _listFirebaseProjects(projectRoot);
    if (projects == null) {
      return null;
    }

    for (final project in projects) {
      if (project['projectId'] == projectId) {
        return true;
      }
    }

    return false;
  }

  List<Map<String, String?>> _extractFirebaseProjects(dynamic decoded) {
    final projects = <Map<String, String?>>[];

    void addProjectsFromList(dynamic rawList) {
      if (rawList is! List) {
        return;
      }
      for (final entry in rawList.whereType<Map>()) {
        final map = Map<String, dynamic>.from(entry);
        final projectId =
            _stringValue(map['projectId']) ?? _stringValue(map['project_id']);
        if (projectId == null) {
          continue;
        }
        projects.add(<String, String?>{
          'projectId': projectId,
          'displayName': _stringValue(map['displayName']),
        });
      }
    }

    if (decoded is Map<String, dynamic>) {
      addProjectsFromList(decoded['result']);
      addProjectsFromList(decoded['projects']);
    } else {
      addProjectsFromList(decoded);
    }

    return projects;
  }

  Future<void> _ensureFirebaseCoreDependency({
    required String projectRoot,
  }) async {
    final pubspecFile = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspecFile.existsSync()) {
      return;
    }

    final currentContent = pubspecFile.readAsStringSync();
    if (_pubspecHasFirebaseCoreDependency(currentContent)) {
      _out('firebase_core already exists in pubspec.yaml');
      return;
    }

    _out('firebase_core not found in pubspec.yaml. Adding dependency...');

    final flutterAdd = await _runCommand(
      'flutter',
      const <String>['pub', 'add', 'firebase_core'],
      projectRoot,
      optional: true,
    );
    if (flutterAdd != null && flutterAdd.exitCode == 0) {
      _out('Added firebase_core using "flutter pub add firebase_core".');
      return;
    }

    final dartAdd = await _runCommand(
      'dart',
      const <String>['pub', 'add', 'firebase_core'],
      projectRoot,
      optional: true,
    );
    if (dartAdd != null && dartAdd.exitCode == 0) {
      _out('Added firebase_core using "dart pub add firebase_core".');
      return;
    }

    final fallbackContent =
        _insertFirebaseCoreDependencyFallback(currentContent);
    if (fallbackContent == currentContent) {
      _err(
        'Unable to add firebase_core automatically. '
        'Run "flutter pub add firebase_core" manually.',
      );
      return;
    }

    pubspecFile.writeAsStringSync(fallbackContent);
    _out('Added firebase_core to pubspec.yaml using file fallback.');
  }

  bool _pubspecHasFirebaseCoreDependency(String content) {
    try {
      final decoded = loadYaml(content);
      if (decoded is YamlMap) {
        final dependencies = decoded['dependencies'];
        if (dependencies is YamlMap &&
            dependencies.containsKey('firebase_core')) {
          return true;
        }
      }
    } catch (_) {
      // Fall back to regex check for malformed YAML files.
    }

    return RegExp(
      r'^\s*firebase_core\s*:',
      multiLine: true,
    ).hasMatch(content);
  }

  String _insertFirebaseCoreDependencyFallback(String content) {
    final lines = content.split('\n');
    final dependenciesIndex = lines
        .indexWhere((line) => RegExp(r'^\s*dependencies:\s*$').hasMatch(line));

    if (dependenciesIndex != -1) {
      lines.insert(dependenciesIndex + 1, '  firebase_core: any');
      return '${lines.join('\n').trimRight()}\n';
    }

    final normalized = content.trimRight();
    if (normalized.isEmpty) {
      return 'dependencies:\n  firebase_core: any\n';
    }

    return '$normalized\n\ndependencies:\n  firebase_core: any\n';
  }

  List<String> _resolveAppDistributionGroupAliases({
    required String envPath,
    required String? explicitGroups,
  }) {
    var raw = _stringValue(explicitGroups);

    if (raw == null) {
      final envValue =
          _stringValue(Platform.environment['FIREBASE_TESTER_GROUPS']);
      if (envValue != null) {
        raw = envValue;
      }
    }

    if (raw == null) {
      final envFile = File(envPath);
      if (envFile.existsSync()) {
        for (final line in envFile.readAsLinesSync()) {
          final trimmed = line.trim();
          if (trimmed.isEmpty || trimmed.startsWith('#')) {
            continue;
          }
          if (!trimmed.startsWith('FIREBASE_TESTER_GROUPS=')) {
            continue;
          }
          raw = _stringValue(
            trimmed.substring('FIREBASE_TESTER_GROUPS='.length),
          );
          if (raw != null) {
            break;
          }
        }
      }
    }

    raw ??= 'qa';

    final aliases = <String>{};
    for (final entry in raw.split(',')) {
      final alias = _stringValue(entry)?.toLowerCase();
      if (alias != null) {
        aliases.add(alias);
      }
    }

    return aliases.toList()..sort();
  }

  Future<void> _ensureFirebaseAppDistributionGroups({
    required String projectRoot,
    required String projectId,
    required List<String> groupAliases,
    required bool optional,
  }) async {
    if (groupAliases.isEmpty) {
      return;
    }

    final existingAliases = await _listFirebaseAppDistributionGroups(
      projectRoot: projectRoot,
      projectId: projectId,
    );

    for (final alias in groupAliases) {
      if (existingAliases != null && existingAliases.contains(alias)) {
        _out('Firebase App Distribution group "$alias" already exists.');
        continue;
      }

      final displayName = _appDistributionDisplayName(alias);
      final createResult = await _runCommand(
        'firebase',
        <String>[
          'appdistribution:group:create',
          displayName,
          alias,
          '--project',
          projectId,
        ],
        projectRoot,
        optional: true,
      );
      if (createResult == null) {
        if (!optional) {
          throw Exception(
            'Unable to run firebase appdistribution:group:create for "$alias".',
          );
        }
        _out(
          'Skipping App Distribution group setup for "$alias": Firebase CLI is unavailable.',
        );
        continue;
      }

      if (createResult.exitCode == 0) {
        _out('Created Firebase App Distribution group "$alias".');
        continue;
      }

      final outputText =
          '${createResult.stdout}\n${createResult.stderr}'.toLowerCase();
      if (outputText.contains('already exists') ||
          outputText.contains('already in use')) {
        _out('Firebase App Distribution group "$alias" already exists.');
        continue;
      }

      if (!optional) {
        throw Exception(
          'Failed to create App Distribution group "$alias": '
          '${createResult.stderr.toString().trim()}',
        );
      }
      _out(
        'Skipping App Distribution group "$alias": '
        '${createResult.stderr.toString().trim()}',
      );
    }
  }

  Future<Set<String>?> _listFirebaseAppDistributionGroups({
    required String projectRoot,
    required String projectId,
  }) async {
    final listResult = await _runCommand(
      'firebase',
      <String>[
        'appdistribution:group:list',
        '--project',
        projectId,
        '--json',
      ],
      projectRoot,
      optional: true,
    );
    if (listResult == null || listResult.exitCode != 0) {
      return null;
    }

    final decoded = _decodeJsonOrEmpty(listResult.stdout.toString());
    final aliases = <String>{};

    void collectFromList(dynamic entries) {
      if (entries is! List) {
        return;
      }
      for (final entry in entries.whereType<Map>()) {
        final map = Map<String, dynamic>.from(entry);
        final alias = _stringValue(map['alias']);
        if (alias != null) {
          aliases.add(alias.toLowerCase());
        }
      }
    }

    if (decoded is Map<String, dynamic>) {
      collectFromList(decoded['result']);
      collectFromList(decoded['groups']);
    } else {
      collectFromList(decoded);
    }

    return aliases;
  }

  String _appDistributionDisplayName(String alias) {
    final normalized = alias.replaceAll('-', ' ').trim();
    if (normalized.isEmpty) {
      return 'QA';
    }
    final words = normalized
        .split(RegExp(r'\s+'))
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}')
        .toList();
    return words.join(' ');
  }

  bool _looksLikePlaceholderFirebaseProject(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'your-firebase-project-id' ||
        normalized == 'your-project-id' ||
        normalized == 'your_project_id' ||
        normalized == 'firebase-project-id' ||
        normalized.contains('<') ||
        normalized.contains('>');
  }

  bool _promptYesNo(String prompt) {
    final answer = _stringValue(_promptReader(prompt))?.toLowerCase();
    if (answer == null) {
      return false;
    }
    return answer == 'y' || answer == 'yes';
  }

  String _suggestFirebaseProjectId(String projectRoot) {
    final appName = _readPubspecAppData(projectRoot)['name'];
    final raw = (appName ?? 'my-firebase-project').toLowerCase();
    final normalized = raw
        .replaceAll(RegExp(r'[^a-z0-9-]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final base = normalized.isEmpty ? 'my-firebase-project' : normalized;

    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = timestamp.substring(timestamp.length - 6);
    return '$base-$suffix';
  }

  String _suggestFirebaseDisplayName(String projectRoot) {
    final appName = _readPubspecAppData(projectRoot)['name'];
    if (appName == null || appName.trim().isEmpty) {
      return 'My Firebase Project';
    }
    return appName.trim();
  }

  Future<void> _runFlutterfireConfigure({
    required String projectRoot,
    required String projectId,
    required bool optional,
  }) async {
    final pubspec = File(p.join(projectRoot, 'pubspec.yaml'));
    if (!pubspec.existsSync()) {
      return;
    }

    _out('Running flutterfire configure for project "$projectId"...');

    final directRun = await _runCommand(
      'flutterfire',
      <String>['configure', '--project', projectId, '--yes'],
      projectRoot,
      optional: true,
    );
    if (directRun != null && directRun.exitCode == 0) {
      _out('flutterfire configure completed.');
      return;
    }

    final activateResult = await _runCommand(
      'dart',
      const <String>['pub', 'global', 'activate', 'flutterfire_cli'],
      projectRoot,
      optional: true,
    );
    if (activateResult == null || activateResult.exitCode != 0) {
      if (!optional) {
        throw Exception('Unable to activate flutterfire_cli.');
      }
      _out(
          'Skipping flutterfire configure: flutterfire_cli activation failed.');
      return;
    }

    final globalRun = await _runCommand(
      'dart',
      <String>[
        'pub',
        'global',
        'run',
        'flutterfire_cli:flutterfire',
        'configure',
        '--project',
        projectId,
        '--yes',
      ],
      projectRoot,
      optional: true,
    );
    if (globalRun != null && globalRun.exitCode == 0) {
      _out('flutterfire configure completed.');
      return;
    }

    if (!optional) {
      throw Exception('flutterfire configure failed.');
    }
    _out(
      'Skipping flutterfire configure: command failed. '
      'You can run it manually with "flutterfire configure --project $projectId".',
    );
  }

  Future<String?> _resolveFirebaseProject(
    String projectRoot,
    String? firebaseProject,
  ) async {
    final explicit = _stringValue(firebaseProject);
    if (explicit != null) {
      if (_looksLikePlaceholderFirebaseProject(explicit)) {
        _out(
          'The provided Firebase project id "$explicit" looks like a placeholder. '
          'Trying auto-detection instead.',
        );
      } else {
        return explicit;
      }
    }

    final envProjectFromCli =
        _stringValue(Platform.environment['FIREBASE_PROJECT_ID']) ??
            _stringValue(Platform.environment['GCLOUD_PROJECT']);
    if (envProjectFromCli != null &&
        !_looksLikePlaceholderFirebaseProject(envProjectFromCli)) {
      return envProjectFromCli;
    }
    if (envProjectFromCli != null) {
      _out(
        'The environment Firebase project id "$envProjectFromCli" looks like a placeholder. '
        'Trying auto-detection instead.',
      );
    }

    final useCommand = await _runCommand(
      'firebase',
      const <String>['use', '--json'],
      projectRoot,
      optional: true,
    );
    if (useCommand == null || useCommand.exitCode != 0) {
      return null;
    }

    final decoded = _decodeJsonOrEmpty(useCommand.stdout.toString());
    if (decoded is Map<String, dynamic>) {
      final result = decoded['result'];
      if (result is String && result.trim().isNotEmpty) {
        final projectId = result.trim();
        if (_looksLikePlaceholderFirebaseProject(projectId)) {
          return null;
        }
        return projectId;
      }
      if (result is Map<String, dynamic>) {
        final project = _stringValue(result['projectId']);
        if (project != null && !_looksLikePlaceholderFirebaseProject(project)) {
          return project;
        }
      }
    }

    return null;
  }

  dynamic _decodeJsonOrEmpty(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(normalized);
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  List<Map<String, dynamic>> _extractFirebaseApps(dynamic decoded) {
    List<Map<String, dynamic>> toList(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    if (decoded is List) {
      return toList(decoded);
    }
    if (decoded is Map<String, dynamic>) {
      if (decoded['result'] is List) {
        return toList(decoded['result']);
      }
      if (decoded['result'] is Map<String, dynamic>) {
        final resultMap = decoded['result'] as Map<String, dynamic>;
        if (resultMap['apps'] is List) {
          return toList(resultMap['apps']);
        }
      }
      if (decoded['apps'] is List) {
        return toList(decoded['apps']);
      }
    }
    return <Map<String, dynamic>>[];
  }

  String? _extractFirebaseProjectNumber(dynamic decoded, String projectId) {
    List<Map<String, dynamic>> toProjects(dynamic value) {
      if (value is List) {
        return value
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    final candidates = <Map<String, dynamic>>[];
    if (decoded is Map<String, dynamic>) {
      candidates.addAll(toProjects(decoded['result']));
      candidates.addAll(toProjects(decoded['projects']));
    } else if (decoded is List) {
      candidates.addAll(toProjects(decoded));
    }

    for (final project in candidates) {
      final id = _stringValue(project['projectId']) ??
          _stringValue(project['project_id']);
      if (id == projectId) {
        return _stringValue(project['projectNumber']) ??
            _stringValue(project['project_number']);
      }
    }

    return null;
  }

  Map<String, dynamic>? _findFirebaseApp(
    List<Map<String, dynamic>> apps,
    String platform,
  ) {
    for (final app in apps) {
      final appPlatform = (_stringValue(app['platform']) ?? '').toUpperCase();
      if (appPlatform == platform.toUpperCase()) {
        return app;
      }
    }
    return null;
  }

  String _upsertEnvFile({
    required String path,
    required Map<String, String?> values,
    required bool overwrite,
  }) {
    final envFile = File(path);
    envFile.parent.createSync(recursive: true);

    final originalLines =
        envFile.existsSync() ? envFile.readAsLinesSync() : <String>[];
    var updatedLines = List<String>.from(originalLines);
    final indexByKey = <String, int>{};

    for (var i = 0; i < updatedLines.length; i++) {
      final line = updatedLines[i].trim();
      if (line.isEmpty || line.startsWith('#') || !line.contains('=')) {
        continue;
      }
      final separatorIndex = line.indexOf('=');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = line.substring(0, separatorIndex).trim();
      if (key.isNotEmpty) {
        indexByKey[key] = i;
      }
    }

    var changed = false;
    values.forEach((key, value) {
      final normalized = _stringValue(value);
      if (normalized == null) {
        return;
      }

      final newLine = '$key=$normalized';
      final existingIndex = indexByKey[key];
      if (existingIndex == null) {
        updatedLines.add(newLine);
        changed = true;
        return;
      }

      if (!overwrite) {
        return;
      }
      if (updatedLines[existingIndex] != newLine) {
        updatedLines[existingIndex] = newLine;
        changed = true;
      }
    });

    if (!envFile.existsSync()) {
      if (updatedLines.isEmpty) {
        updatedLines = <String>['# Managed by fastlane_cli'];
      }
      envFile.writeAsStringSync('${updatedLines.join('\n')}\n');
      return 'created';
    }

    if (!changed) {
      return 'unchanged';
    }

    envFile.writeAsStringSync('${updatedLines.join('\n')}\n');
    return 'updated';
  }

  String _writeTextFile(String path, String content, bool overwrite) {
    final file = File(path);
    file.parent.createSync(recursive: true);

    if (file.existsSync()) {
      final existing = file.readAsStringSync();
      if (existing == content) {
        return 'unchanged';
      }
      if (!overwrite) {
        return 'skipped';
      }

      file.writeAsStringSync(content);
      return 'updated';
    }

    file.writeAsStringSync(content);
    return 'created';
  }

  String _ensurePluginfile(String path, bool overwrite) {
    final file = File(path);
    if (!file.existsSync()) {
      return 'skipped';
    }

    final current = file.readAsStringSync();
    final hasPluginGem = current
        .split('\n')
        .map((line) => line.trimLeft())
        .any((line) => line.startsWith('gem "') || line.startsWith("gem '"));

    if (current.contains('Managed by fastlane_cli') && !hasPluginGem) {
      if (!overwrite) {
        return 'skipped';
      }
      file.deleteSync();
      return 'removed';
    }

    return 'unchanged';
  }

  String _buildFastfile(String androidPackageName) {
    final packageLiteral = _rubyLiteral(androidPackageName);
    return '''# Autogenerated by fastlane_cli
# Quick commands:
# - fastlane android release_android_to_firebase
# - fastlane ios release_ios_to_firebase

default_platform(:android)

def env_value_from_fastlane_files(key)
  ["fastlane/.env", "fastlane/.env.default"].each do |path|
    next unless File.exist?(path)

    File.foreach(path) do |line|
      stripped = line.strip
      next if stripped.empty? || stripped.start_with?("#")

      name, value = stripped.split("=", 2)
      return value.to_s if name == key
    end
  end

  ""
end

desc "Populate fastlane/.env secrets from local CLI sessions"
lane :bootstrap_cli_env do
  sh("bash", "scripts/sync_cli_env.sh", "--project-root", "..", "--env-path", "fastlane/.env")
end

desc "Show Apple account providers/teams using altool"
lane :apple_account_info do |options|
  args = ["bash", "scripts/apple_account_info.sh"]
  apple_id = options[:apple_id].to_s
  args += ["--apple-id", apple_id] unless apple_id.empty?
  sh(*args)
end

desc "Fetch Firebase + project metadata and write JSON files for CI"
lane :fetch_data do
  bootstrap_cli_env
  sh("flc", "firebase-sync", "--project-root", ".", "--output-path", "fastlane/firebase_data.json", "--update-env", "--overwrite", "--optional")
  fetch_args = ["fastlane_cli", "fetch-data", "--project-root", ".", "--output-path", "fastlane/build_data.json", "--include-github"]
  github_repository = env_value_from_fastlane_files("GITHUB_REPOSITORY")
  github_token = env_value_from_fastlane_files("GITHUB_TOKEN")
  fetch_args += ["--github-repository", github_repository] unless github_repository.to_s.empty?
  fetch_args += ["--github-token", github_token] unless github_token.to_s.empty?
  sh(*fetch_args)
end

platform :android do
  desc "Build Android AAB release for Flutter"
  lane :build_android do
    sh("flutter", "pub", "get")
    sh("flutter", "build", "appbundle", "--release")
  end

  desc "Distribute Android build to Firebase App Distribution"
  lane :firebase_android do |options|
    bootstrap_cli_env
    artifact_path = options[:artifact_path] || Dir["build/app/outputs/bundle/release/*.aab"].max_by { |file| File.mtime(file) }
    UI.user_error!("Android artifact not found. Run build_android first.") unless artifact_path

    app_id = options[:app_id] || ENV["FIREBASE_APP_ID_ANDROID"]
    app_id = env_value_from_fastlane_files("FIREBASE_APP_ID_ANDROID") if app_id.to_s.empty?
    token = ENV["FIREBASE_TOKEN"]
    token = env_value_from_fastlane_files("FIREBASE_TOKEN") if token.to_s.empty?
    groups = options[:groups] || ENV["FIREBASE_TESTER_GROUPS"]
    groups = env_value_from_fastlane_files("FIREBASE_TESTER_GROUPS") if groups.to_s.empty?
    release_notes = options[:release_notes] || ENV["FIREBASE_RELEASE_NOTES"]
    release_notes = env_value_from_fastlane_files("FIREBASE_RELEASE_NOTES") if release_notes.to_s.empty?

    UI.user_error!("Missing FIREBASE_APP_ID_ANDROID") if app_id.to_s.empty?
    UI.user_error!("Missing FIREBASE_TOKEN") if token.to_s.empty?

    args = ["firebase", "appdistribution:distribute", artifact_path, "--app", app_id, "--token", token]
    args += ["--groups", groups] unless groups.to_s.empty?
    args += ["--release-notes", release_notes] unless release_notes.to_s.empty?
    sh(*args)
  end

  desc "Build and upload Android app to Google Play"
  lane :release_android do
    build_android
    upload_to_play_store(
      package_name: ENV["FASTLANE_ANDROID_PACKAGE_NAME"] || $packageLiteral
    )
  end

  desc "CI lane: fetch data, build Android, and distribute to Firebase"
  lane :ci_android do
    fetch_data
    build_android
    firebase_android
  end

  # Use this lane for one-shot local release to Firebase App Distribution.
  desc "Local lane: build Android and upload directly to Firebase App Distribution"
  lane :release_android_to_firebase do
    fetch_data
    build_android
    firebase_android
  end
end

platform :ios do
  desc "Build iOS IPA release for Flutter"
  lane :build_ios do
    sh("flutter", "pub", "get")
    sh("flutter", "build", "ipa", "--release")
  end

  desc "Distribute iOS build to Firebase App Distribution"
  lane :firebase_ios do |options|
    bootstrap_cli_env
    artifact_path = options[:artifact_path] || Dir["build/ios/ipa/*.ipa"].max_by { |file| File.mtime(file) }
    UI.user_error!("iOS artifact not found. Run build_ios first.") unless artifact_path

    app_id = options[:app_id] || ENV["FIREBASE_APP_ID_IOS"]
    app_id = env_value_from_fastlane_files("FIREBASE_APP_ID_IOS") if app_id.to_s.empty?
    token = ENV["FIREBASE_TOKEN"]
    token = env_value_from_fastlane_files("FIREBASE_TOKEN") if token.to_s.empty?
    groups = options[:groups] || ENV["FIREBASE_TESTER_GROUPS"]
    groups = env_value_from_fastlane_files("FIREBASE_TESTER_GROUPS") if groups.to_s.empty?
    release_notes = options[:release_notes] || ENV["FIREBASE_RELEASE_NOTES"]
    release_notes = env_value_from_fastlane_files("FIREBASE_RELEASE_NOTES") if release_notes.to_s.empty?

    UI.user_error!("Missing FIREBASE_APP_ID_IOS") if app_id.to_s.empty?
    UI.user_error!("Missing FIREBASE_TOKEN") if token.to_s.empty?

    args = ["firebase", "appdistribution:distribute", artifact_path, "--app", app_id, "--token", token]
    args += ["--groups", groups] unless groups.to_s.empty?
    args += ["--release-notes", release_notes] unless release_notes.to_s.empty?
    sh(*args)
  end

  desc "Build and upload iOS app to TestFlight"
  lane :release_ios do
    build_ios
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end

  desc "CI lane: fetch data, build iOS, and distribute to Firebase"
  lane :ci_ios do
    fetch_data
    build_ios
    firebase_ios
  end

  # Use this lane for one-shot local release to Firebase App Distribution.
  desc "Local lane: build iOS and upload directly to Firebase App Distribution"
  lane :release_ios_to_firebase do
    fetch_data
    build_ios
    firebase_ios
  end
end
''';
  }

  String _buildSyncCliEnvScript() {
    return r'''#!/usr/bin/env bash
set -euo pipefail

project_root="."
env_path="fastlane/.env"
overwrite="false"

usage() {
  cat <<'EOF'
Usage: sync_cli_env.sh [options]

Options:
  --project-root <path>   Project root path. Default: .
  --env-path <path>       Target env file path. Default: fastlane/.env
  --overwrite             Overwrite existing non-empty values.
  -h, --help              Show this help message.
EOF
}

while (($# > 0)); do
  case "$1" in
    --project-root)
      project_root="${2:-}"
      shift 2
      ;;
    --env-path)
      env_path="${2:-}"
      shift 2
      ;;
    --overwrite)
      overwrite="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$project_root" ]]; then
  echo "project_root cannot be empty" >&2
  exit 1
fi

project_root="$(cd "$project_root" && pwd)"

if [[ "$env_path" != /* ]]; then
  env_path="$project_root/$env_path"
fi

mkdir -p "$(dirname "$env_path")"
touch "$env_path"

get_value_from_file() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key { value = substr($0, index($0, "=") + 1) }
    END { print value }
  ' "$env_path"
}

upsert_value() {
  local key="$1"
  local value="$2"
  local tmp_file
  tmp_file="$(mktemp)"
  awk -v key="$key" -v value="$value" '
    BEGIN { updated = 0 }
    index($0, key "=") == 1 {
      print key "=" value
      updated = 1
      next
    }
    { print $0 }
    END {
      if (updated == 0) {
        print key "=" value
      }
    }
  ' "$env_path" > "$tmp_file"
  mv "$tmp_file" "$env_path"
}

set_if_needed() {
  local key="$1"
  local value="$2"
  local source="$3"
  local secret="${4:-false}"
  local current
  current="$(get_value_from_file "$key")"

  if [[ -n "$current" && "$overwrite" != "true" ]]; then
    echo "[skip] $key already set in $(basename "$env_path")"
    return 0
  fi

  if [[ -z "$value" ]]; then
    echo "[warn] $key could not be detected automatically"
    return 0
  fi

  upsert_value "$key" "$value"
  if [[ "$secret" == "true" ]]; then
    echo "[ok] $key set from $source"
  else
    echo "[ok] $key=$value (from $source)"
  fi
}

detect_github_repository() {
  local remote_url repo
  remote_url="$(git -C "$project_root" remote get-url origin 2>/dev/null || true)"
  repo=""

  case "$remote_url" in
    git@github.com:*)
      repo="${remote_url#git@github.com:}"
      ;;
    ssh://git@github.com/*)
      repo="${remote_url#ssh://git@github.com/}"
      ;;
    https://github.com/*)
      repo="${remote_url#https://github.com/}"
      ;;
    http://github.com/*)
      repo="${remote_url#http://github.com/}"
      ;;
  esac

  repo="${repo%.git}"
  repo="${repo#/}"
  printf '%s' "$repo"
}

detect_github_token() {
  local token credential_output

  token="${GITHUB_TOKEN:-}"
  if [[ -n "$token" ]]; then
    printf '%s' "$token"
    return 0
  fi

  if command -v gh >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
    token="${token//$'\r'/}"
    token="${token//$'\n'/}"
    if [[ -n "$token" ]]; then
      printf '%s' "$token"
      return 0
    fi
  fi

  credential_output="$(printf 'protocol=https\nhost=github.com\n\n' | git credential fill 2>/dev/null || true)"
  token="$(printf '%s\n' "$credential_output" | awk -F= '$1 == "password" { print $2; exit }')"
  printf '%s' "$token"
}

detect_firebase_token() {
  local token config_path
  token="${FIREBASE_TOKEN:-}"
  if [[ -n "$token" ]]; then
    printf '%s' "$token"
    return 0
  fi

  config_path="${XDG_CONFIG_HOME:-$HOME/.config}/configstore/firebase-tools.json"
  if [[ ! -f "$config_path" ]]; then
    return 0
  fi

  ruby -rjson -e '
data = JSON.parse(File.read(ARGV[0]))
token = data.dig("tokens", "refresh_token").to_s
token = data.dig("tokens", "access_token").to_s if token.empty?
print token
' "$config_path" 2>/dev/null || true
}

github_repository="$(detect_github_repository)"
github_token="$(detect_github_token)"
firebase_token="$(detect_firebase_token)"

set_if_needed "GITHUB_REPOSITORY" "$github_repository" "git remote"
set_if_needed "GITHUB_TOKEN" "$github_token" "GitHub CLI or git credential helper" "true"
set_if_needed "FIREBASE_TOKEN" "$firebase_token" "firebase CLI local session" "true"

if [[ -z "$(get_value_from_file "FASTLANE_APPLE_ID")" ]]; then
  echo "[info] FASTLANE_APPLE_ID is still empty. Set it manually, then run:"
  echo "       fastlane apple_account_info apple_id:you@example.com"
fi

echo "[done] CLI sync complete: $env_path"
''';
  }

  String _buildAppleAccountInfoScript() {
    return r'''#!/usr/bin/env bash
set -euo pipefail

apple_id="${FASTLANE_APPLE_ID:-}"
api_key_id="${APP_STORE_CONNECT_API_KEY_ID:-}"
api_issuer_id="${APP_STORE_CONNECT_API_ISSUER_ID:-}"
keychain_item="${FASTLANE_APPLE_PASSWORD_ITEM:-}"
password="${FASTLANE_APPLE_APP_SPECIFIC_PASSWORD:-${FASTLANE_PASSWORD:-}}"

usage() {
  cat <<'EOF'
Usage: apple_account_info.sh [options]

Options:
  --apple-id <email>            Apple ID email.
  --api-key-id <id>             App Store Connect API key id.
  --api-issuer-id <id>          App Store Connect API issuer id.
  --password <value>            Apple account password/app-specific password.
  --password-keychain-item <n>  macOS keychain item name used by altool.
  -h, --help                    Show this help message.
EOF
}

while (($# > 0)); do
  case "$1" in
    --apple-id)
      apple_id="${2:-}"
      shift 2
      ;;
    --api-key-id)
      api_key_id="${2:-}"
      shift 2
      ;;
    --api-issuer-id)
      api_issuer_id="${2:-}"
      shift 2
      ;;
    --password)
      password="${2:-}"
      shift 2
      ;;
    --password-keychain-item)
      keychain_item="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$api_key_id" || -n "$api_issuer_id" ]]; then
  if [[ -z "$api_key_id" || -z "$api_issuer_id" ]]; then
    echo "Both --api-key-id and --api-issuer-id are required for API key auth." >&2
    exit 1
  fi
  exec xcrun altool --list-providers --api-key "$api_key_id" --api-issuer "$api_issuer_id" --output-format json
fi

if [[ -z "$apple_id" ]]; then
  echo "Missing Apple ID. Set FASTLANE_APPLE_ID or pass --apple-id <email>." >&2
  exit 1
fi

if [[ -n "$keychain_item" ]]; then
  exec xcrun altool --list-providers -u "$apple_id" -p "@keychain:$keychain_item" --output-format json
fi

if [[ -z "$password" ]]; then
  cat >&2 <<'EOF'
Missing Apple auth password.
Set one of:
  FASTLANE_APPLE_APP_SPECIFIC_PASSWORD
  FASTLANE_PASSWORD
Or pass:
  --password <value>
or:
  --password-keychain-item <name>
EOF
  exit 1
fi

exec xcrun altool --list-providers -u "$apple_id" -p "$password" --output-format json
''';
  }

  String _buildAppfile({
    required String iosBundleId,
    String? appleId,
    String? teamId,
    String? itcTeamId,
  }) {
    final lines = <String>[
      '# Autogenerated by fastlane_cli',
      'app_identifier(ENV["FASTLANE_APP_IDENTIFIER"] || ${_rubyLiteral(iosBundleId)})',
      _optionalAppfileSetting('apple_id', 'FASTLANE_APPLE_ID', appleId),
      _optionalAppfileSetting('team_id', 'FASTLANE_TEAM_ID', teamId),
      _optionalAppfileSetting('itc_team_id', 'FASTLANE_ITC_TEAM_ID', itcTeamId),
    ];

    return '${lines.join('\n')}\n';
  }

  String _optionalAppfileSetting(String key, String envKey, String? value) {
    if (value == null || value.isEmpty) {
      return '$key(ENV["$envKey"]) if ENV["$envKey"]';
    }

    return '$key(ENV["$envKey"] || ${_rubyLiteral(value)})';
  }

  String _buildEnvFile({
    required String iosBundleId,
    required String androidPackageName,
    String? appleId,
    String? teamId,
    String? itcTeamId,
  }) {
    return '''# Autogenerated by fastlane_cli
FASTLANE_APP_IDENTIFIER=$iosBundleId
FASTLANE_ANDROID_PACKAGE_NAME=$androidPackageName
FASTLANE_APPLE_ID=${appleId ?? ''}
FASTLANE_TEAM_ID=${teamId ?? ''}
FASTLANE_ITC_TEAM_ID=${itcTeamId ?? ''}
GITHUB_REPOSITORY=
GITHUB_TOKEN=
FIREBASE_TOKEN=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID_ANDROID=
FIREBASE_APP_ID_IOS=
FIREBASE_TESTER_GROUPS=qa
FIREBASE_RELEASE_NOTES=Automated distribution from Fastlane
''';
  }

  String _buildGithubWorkflow(String ciBranch) {
    return '''name: Mobile Delivery

on:
  workflow_dispatch:
  push:
    branches:
      - $ciBranch

jobs:
  android:
    runs-on: ubuntu-latest
    env:
      GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
      GITHUB_REPOSITORY: \${{ github.repository }}
      FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
      FIREBASE_APP_ID_ANDROID: \${{ secrets.FIREBASE_APP_ID_ANDROID }}
      FIREBASE_TESTER_GROUPS: \${{ vars.FIREBASE_TESTER_GROUPS }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install tools
        run: |
          gem install fastlane
          npm install -g firebase-tools
          dart pub global activate fastlane_cli
          echo "\$HOME/.pub-cache/bin" >> \$GITHUB_PATH

      - name: Fetch metadata
        run: fastlane_cli fetch-data --project-root . --output-path fastlane/build_data.json --include-github

      - name: Run Android CI lane
        run: fastlane android ci_android

  ios:
    if: \${{ vars.ENABLE_IOS == 'true' }}
    runs-on: macos-latest
    env:
      GITHUB_TOKEN: \${{ secrets.GITHUB_TOKEN }}
      GITHUB_REPOSITORY: \${{ github.repository }}
      FIREBASE_TOKEN: \${{ secrets.FIREBASE_TOKEN }}
      FIREBASE_APP_ID_IOS: \${{ secrets.FIREBASE_APP_ID_IOS }}
      FIREBASE_TESTER_GROUPS: \${{ vars.FIREBASE_TESTER_GROUPS }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: "20"

      - name: Install tools
        run: |
          gem install fastlane
          npm install -g firebase-tools
          dart pub global activate fastlane_cli
          echo "\$HOME/.pub-cache/bin" >> \$GITHUB_PATH

      - name: Fetch metadata
        run: fastlane_cli fetch-data --project-root . --output-path fastlane/build_data.json --include-github

      - name: Run iOS CI lane
        run: fastlane ios ci_ios
''';
  }

  String? _inferIosBundleId(String projectRoot) {
    final pbxproj = File(
      p.join(projectRoot, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
    );
    if (!pbxproj.existsSync()) {
      return null;
    }

    final matches = RegExp(
      r'PRODUCT_BUNDLE_IDENTIFIER\s*=\s*([^;]+);',
    ).allMatches(pbxproj.readAsStringSync());

    for (final match in matches) {
      final raw = match.group(1);
      if (raw == null) {
        continue;
      }

      final value = raw.trim().replaceAll('"', '');
      if (value.contains('RunnerTests') || value.contains(r'$(')) {
        continue;
      }

      if (value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  String? _inferAndroidPackageName(String projectRoot) {
    final gradleKts =
        File(p.join(projectRoot, 'android', 'app', 'build.gradle.kts'));
    if (gradleKts.existsSync()) {
      final match = RegExp(
        r'applicationId\s*=\s*"([^"]+)"',
      ).firstMatch(gradleKts.readAsStringSync());
      if (match != null) {
        return match.group(1);
      }
    }

    final gradle = File(p.join(projectRoot, 'android', 'app', 'build.gradle'));
    if (gradle.existsSync()) {
      final match = RegExp(
        r'''applicationId\s+["']([^"']+)["']''',
      ).firstMatch(gradle.readAsStringSync());
      if (match != null) {
        return match.group(1);
      }
    }

    final manifest = File(
      p.join(
          projectRoot, 'android', 'app', 'src', 'main', 'AndroidManifest.xml'),
    );
    if (manifest.existsSync()) {
      final match = RegExp(
        r'package\s*=\s*"([^"]+)"',
      ).firstMatch(manifest.readAsStringSync());
      if (match != null) {
        return match.group(1);
      }
    }

    return null;
  }

  Future<String?> _gitOutput(String projectRoot, List<String> args) async {
    try {
      final result = await _processRunner(
        'git',
        args,
        workingDirectory: projectRoot,
      );

      if (result.exitCode != 0) {
        return null;
      }

      final output = result.stdout.toString().trim();
      return output.isEmpty ? null : output;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _buildGithubPayload(
    String? repository,
    String? token,
  ) async {
    if (repository == null) {
      return <String, Object?>{
        'repository': null,
        'note':
            'Set --github-repository or GITHUB_REPOSITORY to fetch GitHub API data.',
      };
    }

    final payload = <String, Object?>{'repository': repository};

    final releaseResponse = await _githubGet(
      Uri.https('api.github.com', '/repos/$repository/releases/latest'),
      token,
    );

    if (releaseResponse.statusCode == 200) {
      payload['latest_release'] = <String, Object?>{
        'tag': releaseResponse.data['tag_name'],
        'name': releaseResponse.data['name'],
        'published_at': releaseResponse.data['published_at'],
      };
    } else if (releaseResponse.statusCode == 404) {
      payload['latest_release'] = null;
    } else {
      payload['latest_release_error'] =
          _errorMessage('latest release', releaseResponse);
    }

    final runsResponse = await _githubGet(
      Uri.https('api.github.com', '/repos/$repository/actions/runs',
          <String, String>{'per_page': '1'}),
      token,
    );

    if (runsResponse.statusCode == 200) {
      final runs = runsResponse.data['workflow_runs'];
      if (runs is List && runs.isNotEmpty && runs.first is Map) {
        final run = runs.first as Map;
        payload['latest_workflow_run'] = <String, Object?>{
          'id': run['id'],
          'name': run['name'],
          'status': run['status'],
          'conclusion': run['conclusion'],
          'created_at': run['created_at'],
          'url': run['html_url'],
        };
      } else {
        payload['latest_workflow_run'] = null;
      }
    } else {
      payload['latest_workflow_error'] =
          _errorMessage('workflow runs', runsResponse);
    }

    return payload;
  }

  String _errorMessage(String endpoint, _GithubResponse response) {
    if (response.statusCode == 0) {
      return 'Failed to fetch $endpoint: ${response.error ?? 'unknown error'}';
    }
    return 'GitHub API returned ${response.statusCode} for $endpoint';
  }

  Future<_GithubResponse> _githubGet(Uri uri, String? token) async {
    try {
      final response = await _httpClient.get(
        uri,
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'fastlane_cli',
          if (token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
        },
      );

      if (response.body.trim().isEmpty) {
        return _GithubResponse(response.statusCode, <String, dynamic>{}, null);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return _GithubResponse(response.statusCode, decoded, null);
      }

      return _GithubResponse(response.statusCode, <String, dynamic>{}, null);
    } catch (error) {
      return _GithubResponse(0, <String, dynamic>{}, error.toString());
    }
  }

  String _rubyLiteral(String value) {
    final escaped = value.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return '"$escaped"';
  }
}

class _GithubResponse {
  _GithubResponse(this.statusCode, this.data, this.error);

  final int statusCode;
  final Map<String, dynamic> data;
  final String? error;
}
