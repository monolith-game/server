import 'package:args/command_runner.dart';
import 'package:shelf_plus/shelf_plus.dart';

/// Start the server running.
class RunServerCommand extends Command {
  /// Create an instance.
  RunServerCommand() : super() {
    argParser
      ..addOption(
        'host',
        defaultsTo: '0.0.0.0',
        help: 'The hostname to bind to.',
      )
      ..addOption(
        'port',
        abbr: 'p',
        defaultsTo: '8080',
        help: 'The port to listen on.',
      );
  }

  /// The name of this command.
  @override
  String get name => 'run';

  /// The description of this command.
  @override
  String get description => 'Run the server.';

  /// Run the server.
  @override
  void run() {
    final port = int.tryParse(argResults?['port']);
    final host = argResults?['host'];
    if (port == null) {
      throw UsageException('Invalid port.', 'Port must be a number.');
    }
    shelfRun(
      () {
        final router = Router().plus..use(logRequests());
        return router;
      },
      defaultBindAddress: host,
      defaultBindPort: port,
    );
  }
}
