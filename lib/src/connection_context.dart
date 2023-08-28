import 'package:logging/logging.dart';

/// A class to hold information about connected clients.
class ConnectionContext {
  /// Create an instance.
  ConnectionContext({
    required this.uuid,
    required this.host,
    required this.port,
  }) : logger = Logger('$host:$port');

  /// The UUID which identifies this connection.
  final String uuid;

  /// The host which has been connected from.
  final String host;

  /// The port which was connected.
  final int port;

  /// The logger to use.
  Logger logger;
}
