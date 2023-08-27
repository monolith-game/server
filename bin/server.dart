// ignore_for_file: avoid_print
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:logging/logging.dart';
import 'package:server/src/app_config.dart';
import 'package:server/src/server_commands/profiles_server_command.dart';
import 'package:server/src/server_commands/run_server_command.dart';

Future<void> main(final List<String> arguments) async {
  Logger.root
    ..level = Level.ALL
    ..onRecord.listen(print);
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
      ..addCommand(RunServerCommand(appConfig))
      ..addCommand(ProfilesServerCommand(appConfig));
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e);
    exit(64);
  }
}
