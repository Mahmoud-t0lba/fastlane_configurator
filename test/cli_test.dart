import 'dart:convert';
import 'dart:io';

import 'package:fastlane_configurator/fastlane_configurator.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FastlaneConfiguratorCli', () {
    late List<String> logs;
    late List<String> errors;
    late FastlaneConfiguratorCli cli;

    setUp(() {
      logs = <String>[];
      errors = <String>[];
      cli = FastlaneConfiguratorCli(out: logs.add, err: errors.add);
    });

    test('setup generates fastlane and workflow files', () async {
      final tempDir = await Directory.systemTemp.createTemp('fl_config_setup_');
      addTearDown(() async => tempDir.delete(recursive: true));

      _writeFile(
        p.join(tempDir.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.toolbox;\n',
      );
      _writeFile(
        p.join(tempDir.path, 'android', 'app', 'build.gradle.kts'),
        'android { defaultConfig { applicationId = "com.example.toolbox" } }\n',
      );

      final code = await cli.run(<String>[
        'setup',
        '--project-root',
        tempDir.path,
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(
        File(p.join(tempDir.path, 'fastlane', 'Fastfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'fastlane', 'Appfile')).existsSync(),
        isTrue,
      );
      expect(
        File(
          p.join(tempDir.path, '.github', 'workflows', 'mobile_delivery.yml'),
        ).existsSync(),
        isTrue,
      );

      final fastfileContent = File(
        p.join(tempDir.path, 'fastlane', 'Fastfile'),
      ).readAsStringSync();
      expect(fastfileContent, contains('lane :ci_android'));
      expect(fastfileContent, contains('lane :ci_ios'));
      expect(logs.join('\n'), contains('Setup complete'));
    });

    test('fetch-data writes JSON metadata without GitHub calls', () async {
      final tempDir = await Directory.systemTemp.createTemp('fl_config_fetch_');
      addTearDown(() async => tempDir.delete(recursive: true));

      _writeFile(
        p.join(tempDir.path, 'pubspec.yaml'),
        'name: demo_app\nversion: 2.1.0+13\n',
      );
      _writeFile(
        p.join(tempDir.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.demo;\n',
      );
      _writeFile(
        p.join(tempDir.path, 'android', 'app', 'build.gradle.kts'),
        'android { defaultConfig { applicationId = "com.example.demo" } }\n',
      );

      final code = await cli.run(<String>[
        'fetch-data',
        '--project-root',
        tempDir.path,
        '--output-path',
        'fastlane/build_data.json',
        '--no-include-github',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);

      final outputFile = File(
        p.join(tempDir.path, 'fastlane', 'build_data.json'),
      );
      expect(outputFile.existsSync(), isTrue);

      final payload =
          jsonDecode(outputFile.readAsStringSync()) as Map<String, dynamic>;
      final app = payload['app'] as Map<String, dynamic>;
      final identifiers = payload['identifiers'] as Map<String, dynamic>;

      expect(app['name'], 'demo_app');
      expect(app['version_name'], '2.1.0');
      expect(app['version_code'], '13');
      expect(identifiers['ios_bundle_id'], 'com.example.demo');
      expect(identifiers['android_package_name'], 'com.example.demo');
      expect(payload.containsKey('github'), isFalse);
      expect(logs.join('\n'), contains('Metadata written'));
    });

    test(
        'firebase-sync fetches firebase metadata and updates env automatically',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('fl_config_fb_');
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunner(),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--firebase-project',
        'demo-project',
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);

      final firebaseJson = File(
        p.join(tempDir.path, 'fastlane', 'firebase_data.json'),
      );
      final envFile = File(p.join(tempDir.path, 'fastlane', '.env.default'));

      expect(firebaseJson.existsSync(), isTrue);
      expect(envFile.existsSync(), isTrue);

      final payload =
          jsonDecode(firebaseJson.readAsStringSync()) as Map<String, dynamic>;
      expect(payload['firebase_project_id'], 'demo-project');
      expect(payload['android_app_id'], '1:123:android:abc');
      expect(payload['ios_app_id'], '1:123:ios:def');

      final envContent = envFile.readAsStringSync();
      expect(envContent, contains('FIREBASE_PROJECT_ID=demo-project'));
      expect(envContent, contains('FIREBASE_APP_ID_ANDROID=1:123:android:abc'));
      expect(envContent, contains('FIREBASE_APP_ID_IOS=1:123:ios:def'));
      expect(envContent,
          contains('FASTLANE_ANDROID_PACKAGE_NAME=com.example.demo'));
      expect(envContent, contains('FASTLANE_APP_IDENTIFIER=com.example.demo'));
    });

    test('init runs setup + firebase-sync + fetch-data in one command',
        () async {
      final tempDir = await Directory.systemTemp.createTemp('fl_config_init_');
      addTearDown(() async => tempDir.delete(recursive: true));

      _writeFile(
        p.join(tempDir.path, 'pubspec.yaml'),
        'name: demo_app\nversion: 2.1.0+13\n',
      );
      _writeFile(
        p.join(tempDir.path, 'ios', 'Runner.xcodeproj', 'project.pbxproj'),
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.demo;\n',
      );
      _writeFile(
        p.join(tempDir.path, 'android', 'app', 'build.gradle.kts'),
        'android { defaultConfig { applicationId = "com.example.demo" } }\n',
      );

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunner(),
      );

      final code = await cli.run(<String>[
        'init',
        '--project-root',
        tempDir.path,
        '--firebase-project',
        'demo-project',
        '--overwrite',
        '--no-include-github',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);

      expect(
        File(p.join(tempDir.path, 'fastlane', 'Fastfile')).existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'fastlane', 'firebase_data.json'))
            .existsSync(),
        isTrue,
      );
      expect(
        File(p.join(tempDir.path, 'fastlane', 'build_data.json')).existsSync(),
        isTrue,
      );

      final envContent = File(p.join(tempDir.path, 'fastlane', '.env.default'))
          .readAsStringSync();
      expect(envContent, contains('FIREBASE_PROJECT_ID=demo-project'));
      final pubspecContent =
          File(p.join(tempDir.path, 'pubspec.yaml')).readAsStringSync();
      expect(pubspecContent, contains('firebase_core:'));
      expect(logs.join('\n'), contains('Init complete'));
    });

    test('firebase-sync retries after auto-connect when first apps:list fails',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('fl_config_fb_reconnect_');
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunnerReconnectFirstFailure(),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--firebase-project',
        'demo-project',
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(
        logs.join('\n'),
        contains('trying to connect Firebase project and retry'),
      );
      expect(
        File(p.join(tempDir.path, '.firebaserc')).readAsStringSync(),
        contains('"default": "demo-project"'),
      );
      expect(
        File(p.join(tempDir.path, 'fastlane', 'firebase_data.json'))
            .existsSync(),
        isTrue,
      );
    });

    test('firebase-sync asks permission and creates project when missing',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('fl_config_fb_create_');
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunnerCreateProject(),
        promptReader: _mockPromptReader(<String>[
          'yes',
          'created-firebase-project',
          'Created Firebase Project',
        ]),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(
        logs.join('\n'),
        contains('Creating Firebase project "created-firebase-project"'),
      );
      expect(
        File(p.join(tempDir.path, '.firebaserc')).readAsStringSync(),
        contains('"default": "created-firebase-project"'),
      );

      final envContent = File(p.join(tempDir.path, 'fastlane', '.env.default'))
          .readAsStringSync();
      expect(
          envContent, contains('FIREBASE_PROJECT_ID=created-firebase-project'));
    });

    test(
        'firebase-sync ignores placeholder project id and falls back to create flow',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('fl_config_fb_placeholder_');
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunnerCreateProject(),
        promptReader: _mockPromptReader(<String>[
          'yes',
          'created-firebase-project',
          'Created Firebase Project',
        ]),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--firebase-project',
        'your-firebase-project-id',
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(
        logs.join('\n'),
        contains('looks like a placeholder. Trying auto-detection instead'),
      );
      expect(logs.join('\n'),
          contains('Firebase project created: created-firebase-project'));
    });

    test('firebase-sync selects an existing Firebase project when unlinked',
        () async {
      final tempDir =
          await Directory.systemTemp.createTemp('fl_config_fb_select_');
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunnerSelectExistingProject(),
        promptReader: _mockPromptReader(<String>['2']),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(logs.join('\n'), contains('Select Firebase project to use:'));
      expect(
        File(p.join(tempDir.path, '.firebaserc')).readAsStringSync(),
        contains('"default": "second-project"'),
      );

      final envContent = File(p.join(tempDir.path, 'fastlane', '.env.default'))
          .readAsStringSync();
      expect(envContent, contains('FIREBASE_PROJECT_ID=second-project'));
    });

    test('firebase-sync supports create-new option from project selection menu',
        () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'fl_config_fb_select_create_',
      );
      addTearDown(() async => tempDir.delete(recursive: true));

      cli = FastlaneConfiguratorCli(
        out: logs.add,
        err: errors.add,
        processRunner: _mockProcessRunnerSelectCreateProject(),
        promptReader: _mockPromptReader(<String>[
          '0',
          'menu-created-project',
          'Menu Created Project',
        ]),
      );

      final code = await cli.run(<String>[
        'firebase-sync',
        '--project-root',
        tempDir.path,
        '--overwrite',
      ]);

      expect(code, 0);
      expect(errors, isEmpty);
      expect(logs.join('\n'), contains('0) Create new Firebase project'));
      expect(
        logs.join('\n'),
        contains('Creating Firebase project "menu-created-project"'),
      );
      expect(
        File(p.join(tempDir.path, '.firebaserc')).readAsStringSync(),
        contains('"default": "menu-created-project"'),
      );
    });
  });
}

void _writeFile(String path, String content) {
  final file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
}

ProcessRunner _mockProcessRunner() {
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (executable == 'firebase') {
      if (arguments.length >= 2 &&
          arguments.first == 'login:list' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{'user': 'tester@example.com'},
            ],
          }),
          '',
        );
      }

      if (arguments.isNotEmpty && arguments.first == 'login') {
        return ProcessResult(1, 0, 'Login complete', '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == 'demo-project') {
        return ProcessResult(1, 0, 'Now using project demo-project', '');
      }

      if (arguments.isNotEmpty && arguments.first == 'apps:list') {
        return ProcessResult(
            1,
            0,
            jsonEncode(<String, Object?>{
              'status': 'success',
              'result': <Map<String, String>>[
                <String, String>{
                  'appId': '1:123:android:abc',
                  'platform': 'ANDROID',
                  'displayName': 'Android App',
                  'packageName': 'com.example.demo',
                },
                <String, String>{
                  'appId': '1:123:ios:def',
                  'platform': 'IOS',
                  'displayName': 'iOS App',
                  'bundleId': 'com.example.demo',
                },
              ],
            }),
            '');
      }

      if (arguments.isNotEmpty && arguments.first == 'projects:list') {
        return ProcessResult(
            1,
            0,
            jsonEncode(<String, Object?>{
              'status': 'success',
              'result': <Map<String, String>>[
                <String, String>{
                  'projectId': 'demo-project',
                  'projectNumber': '1234567890',
                },
              ],
            }),
            '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(
              <String, String>{'status': 'success', 'result': 'demo-project'}),
          '',
        );
      }
    }

    if (executable == 'flutterfire' &&
        arguments.length >= 4 &&
        arguments.first == 'configure') {
      return ProcessResult(1, 0, 'flutterfire configured', '');
    }

    if (executable == 'git') {
      return ProcessResult(1, 1, '', 'not a git repository');
    }

    return ProcessResult(1, 1, '', 'command not mocked');
  };
}

ProcessRunner _mockProcessRunnerReconnectFirstFailure() {
  var appsListCalls = 0;

  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (executable == 'firebase') {
      if (arguments.length >= 2 &&
          arguments.first == 'login:list' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{'user': 'tester@example.com'},
            ],
          }),
          '',
        );
      }

      if (arguments.isNotEmpty && arguments.first == 'login') {
        return ProcessResult(1, 0, 'Login complete', '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == 'demo-project') {
        return ProcessResult(1, 0, 'Now using project demo-project', '');
      }

      if (arguments.isNotEmpty && arguments.first == 'apps:list') {
        appsListCalls++;
        if (appsListCalls == 1) {
          return ProcessResult(
            1,
            1,
            '',
            '- Preparing the list of your Firebase apps\n'
                '✖ Preparing the list of your Firebase apps',
          );
        }
        return ProcessResult(
            1,
            0,
            jsonEncode(<String, Object?>{
              'status': 'success',
              'result': <Map<String, String>>[
                <String, String>{
                  'appId': '1:123:android:abc',
                  'platform': 'ANDROID',
                  'displayName': 'Android App',
                  'packageName': 'com.example.demo',
                },
                <String, String>{
                  'appId': '1:123:ios:def',
                  'platform': 'IOS',
                  'displayName': 'iOS App',
                  'bundleId': 'com.example.demo',
                },
              ],
            }),
            '');
      }

      if (arguments.isNotEmpty && arguments.first == 'projects:list') {
        return ProcessResult(
            1,
            0,
            jsonEncode(<String, Object?>{
              'status': 'success',
              'result': <Map<String, String>>[
                <String, String>{
                  'projectId': 'demo-project',
                  'projectNumber': '1234567890',
                },
              ],
            }),
            '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(
            <String, String>{'status': 'success', 'result': 'demo-project'},
          ),
          '',
        );
      }
    }

    if (executable == 'flutterfire' &&
        arguments.length >= 4 &&
        arguments.first == 'configure') {
      return ProcessResult(1, 0, 'flutterfire configured', '');
    }

    if (executable == 'git') {
      return ProcessResult(1, 1, '', 'not a git repository');
    }

    return ProcessResult(1, 1, '', 'command not mocked');
  };
}

ProcessRunner _mockProcessRunnerCreateProject() {
  var projectCreated = false;

  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (executable == 'firebase') {
      if (arguments.length >= 2 &&
          arguments.first == 'login:list' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{'user': 'tester@example.com'},
            ],
          }),
          '',
        );
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == '--json') {
        return ProcessResult(1, 1, '', 'No active Firebase project');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'projects:create' &&
          arguments[1] == 'created-firebase-project') {
        projectCreated = true;
        return ProcessResult(1, 0, 'Project created', '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == 'created-firebase-project') {
        return ProcessResult(
            1, 0, 'Now using project created-firebase-project', '');
      }

      if (arguments.isNotEmpty && arguments.first == 'apps:list') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{
                'appId': '1:999:android:xyz',
                'platform': 'ANDROID',
                'displayName': 'Android App',
                'packageName': 'com.example.created',
              },
              <String, String>{
                'appId': '1:999:ios:uvw',
                'platform': 'IOS',
                'displayName': 'iOS App',
                'bundleId': 'com.example.created',
              },
            ],
          }),
          '',
        );
      }

      if (arguments.isNotEmpty && arguments.first == 'projects:list') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': projectCreated
                ? <Map<String, String>>[
                    <String, String>{
                      'projectId': 'created-firebase-project',
                      'projectNumber': '999999999',
                    },
                  ]
                : <Map<String, String>>[],
          }),
          '',
        );
      }
    }

    if (executable == 'flutterfire' &&
        arguments.length >= 4 &&
        arguments.first == 'configure') {
      return ProcessResult(1, 0, 'flutterfire configured', '');
    }

    if (executable == 'git') {
      return ProcessResult(1, 1, '', 'not a git repository');
    }

    return ProcessResult(1, 1, '', 'command not mocked');
  };
}

ProcessRunner _mockProcessRunnerSelectExistingProject() {
  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (executable == 'firebase') {
      if (arguments.length >= 2 &&
          arguments.first == 'login:list' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{'user': 'tester@example.com'},
            ],
          }),
          '',
        );
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == '--json') {
        return ProcessResult(1, 1, '', 'No active Firebase project');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == 'second-project') {
        return ProcessResult(1, 0, 'Now using project second-project', '');
      }

      if (arguments.isNotEmpty && arguments.first == 'projects:list') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{
                'projectId': 'first-project',
                'projectNumber': '111111111',
                'displayName': 'First Project',
              },
              <String, String>{
                'projectId': 'second-project',
                'projectNumber': '222222222',
                'displayName': 'Second Project',
              },
            ],
          }),
          '',
        );
      }

      if (arguments.isNotEmpty && arguments.first == 'apps:list') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{
                'appId': '1:222:android:sel',
                'platform': 'ANDROID',
                'displayName': 'Android Selected',
                'packageName': 'com.example.selected',
              },
              <String, String>{
                'appId': '1:222:ios:sel',
                'platform': 'IOS',
                'displayName': 'iOS Selected',
                'bundleId': 'com.example.selected',
              },
            ],
          }),
          '',
        );
      }
    }

    if (executable == 'flutterfire' &&
        arguments.length >= 4 &&
        arguments.first == 'configure') {
      return ProcessResult(1, 0, 'flutterfire configured', '');
    }

    if (executable == 'git') {
      return ProcessResult(1, 1, '', 'not a git repository');
    }

    return ProcessResult(1, 1, '', 'command not mocked');
  };
}

ProcessRunner _mockProcessRunnerSelectCreateProject() {
  var projectCreated = false;

  return (
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    if (executable == 'firebase') {
      if (arguments.length >= 2 &&
          arguments.first == 'login:list' &&
          arguments[1] == '--json') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{'user': 'tester@example.com'},
            ],
          }),
          '',
        );
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == '--json') {
        return ProcessResult(1, 1, '', 'No active Firebase project');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'projects:create' &&
          arguments[1] == 'menu-created-project') {
        projectCreated = true;
        return ProcessResult(1, 0, 'Project created', '');
      }

      if (arguments.length >= 2 &&
          arguments.first == 'use' &&
          arguments[1] == 'menu-created-project') {
        return ProcessResult(
            1, 0, 'Now using project menu-created-project', '');
      }

      if (arguments.isNotEmpty && arguments.first == 'projects:list') {
        final projects = <Map<String, String>>[
          <String, String>{
            'projectId': 'existing-project',
            'projectNumber': '333333333',
            'displayName': 'Existing Project',
          },
          <String, String>{
            'projectId': 'existing-project-2',
            'projectNumber': '333333334',
            'displayName': 'Existing Project 2',
          },
        ];
        if (projectCreated) {
          projects.add(<String, String>{
            'projectId': 'menu-created-project',
            'projectNumber': '444444444',
            'displayName': 'Menu Created Project',
          });
        }
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': projects,
          }),
          '',
        );
      }

      if (arguments.isNotEmpty && arguments.first == 'apps:list') {
        return ProcessResult(
          1,
          0,
          jsonEncode(<String, Object?>{
            'status': 'success',
            'result': <Map<String, String>>[
              <String, String>{
                'appId': '1:444:android:menu',
                'platform': 'ANDROID',
                'displayName': 'Android Menu',
                'packageName': 'com.example.menu',
              },
              <String, String>{
                'appId': '1:444:ios:menu',
                'platform': 'IOS',
                'displayName': 'iOS Menu',
                'bundleId': 'com.example.menu',
              },
            ],
          }),
          '',
        );
      }
    }

    if (executable == 'flutterfire' &&
        arguments.length >= 4 &&
        arguments.first == 'configure') {
      return ProcessResult(1, 0, 'flutterfire configured', '');
    }

    if (executable == 'git') {
      return ProcessResult(1, 1, '', 'not a git repository');
    }

    return ProcessResult(1, 1, '', 'command not mocked');
  };
}

PromptReader _mockPromptReader(List<String> answers) {
  var index = 0;
  return (String prompt) {
    if (index >= answers.length) {
      return null;
    }
    final value = answers[index];
    index++;
    return value;
  };
}
