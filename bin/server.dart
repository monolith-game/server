import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:server/src/app_config.dart';
import 'package:server/src/server_commands/profiles_server_command.dart';
import 'package:server/src/server_commands/run_server_command.dart';

Future<void> main(final List<String> arguments) async {
  final runner = CommandRunner(
    Platform.executable,
    'The Monolith game server.',
  );
  runner.argParser
    ..addOption(
      'database',
      abbr: 'd',
      defaultsTo: 'db.sqlite3',
      help: 'The file to load the database from',
    )
    ..addFlag('log-sql', help: 'Whether SQL statements should be logged');
  try {
    final argResults = runner.parse(arguments);
    final appConfig = AppConfig.fromArgResults(argResults);
    runner
      ..addCommand(RunServerCommand())
      ..addCommand(ProfilesServerCommand(appConfig));
    await runner.run(arguments);
  } on UsageException catch (e) {
    // ignore: avoid_print
    print(e);
    exit(64);
  }
}
