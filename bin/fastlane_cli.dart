import 'dart:io';

import 'package:fastlane_cli/fastlane_cli.dart';

Future<void> main(List<String> args) async {
  final cli = FastlaneConfiguratorCli();
  final code = await cli.run(args);
  exit(code);
}
