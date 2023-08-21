// ignore_for_file: avoid_print
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:server/src/server_commands/run_server_command.dart';

Future<void> main(final List<String> arguments) async {
  final runner = CommandRunner(
    Platform.executable,
    'The Monolith game server.',
  )..addCommand(RunServerCommand());
  try {
    await runner.run(arguments);
  } on UsageException catch (e) {
    print(e.message);
    print(e.usage);
  }
}
