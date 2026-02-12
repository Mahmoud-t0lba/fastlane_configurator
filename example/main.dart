import 'package:fastlane_cli/fastlane_cli.dart';

Future<void> main() async {
  final cli = FastlaneConfiguratorCli();

  // Prints the top-level help so users can see available commands quickly.
  await cli.run(<String>['--help']);
}
