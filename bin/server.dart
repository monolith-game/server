import 'dart:io';

import 'package:args/args.dart';
import 'package:database/constants.dart';
import 'package:database/database.dart';
import 'package:logging/logging.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:server/src/connection_context.dart';
import 'package:shelf_plus/shelf_plus.dart';

Future<void> main(final List<String> arguments) async {
  Logger.root.level = Level.ALL;
  final argParser = ArgParser(allowTrailingOptions: false)
    ..addSeparator('Database')
    ..addOption(
      'database',
      abbr: 'd',
      defaultsTo: 'db.sqlite3',
      help: 'The filename to load the database from.',
    )
    ..addFlag('log-sql', help: 'Log SQL statements.')
    ..addSeparator('Server Profiles')
    ..addOption(
      'profile-name',
      abbr: 'p',
      defaultsTo: '',
      help: 'The name of the profile to load.',
    )
    ..addSeparator('Logging')
    ..addOption(
      'log-file',
      abbr: 'l',
      defaultsTo: '-',
      help: 'The log file to use.',
      allowedHelp: {
        '-': 'Log to stdout.',
        '<filename>': 'Use <filename> as the log file.',
      },
    )
    ..addSeparator('Getting Help')
    ..addFlag('help', abbr: 'h', help: 'Show help.');
  final ArgResults argResults;
  try {
    argResults = argParser.parse(arguments);
  } on ArgParserException catch (e) {
    stderr.writeln(e);
    exit(127);
  }
  if (argResults['help'] as bool) {
    stdout
      ..writeln('Monolith game server')
      ..writeln(argParser.usage);
    exit(0);
  }
  final databaseFile = argResults['database'] as String;
  final logSql = argResults['log-sql'] as bool;
  final profileName = argResults['profile-name'] as String;
  final database = MonolithDatabase(
    file: File(databaseFile),
    logStatements: logSql,
  );
  RotatingFileAppender? fileAppender;
  try {
    final logFilename = argResults['log-file'] as String;
    if (logFilename == '-') {
      PrintAppender.setupLogging();
    } else {
      fileAppender = RotatingFileAppender(baseFilePath: logFilename)
        ..attachToLogger(Logger.root);
    }
    final serverLogger = Logger('Server');
    final serverProfilesDao = database.serverProfilesDao;
    final profiles =
        (await serverProfilesDao.getServerProfileContexts()).toList();
    if (profiles.isEmpty) {
      final serverSecurityContextsDao = database.serverSecurityContextsDao;
      final serverSecurityContext =
          await serverSecurityContextsDao.createServerSecurityContext(
        chainFile: File('fullchain.pem'),
        keyFile: File('privkey.pem'),
      );
      final insecure = await serverProfilesDao.createServerProfile(
        name: 'Insecure',
        host: '0.0.0.0',
        port: 8080,
      );
      final secure = await serverProfilesDao.createServerProfile(
        name: 'Secure',
        host: '0.0.0.0',
        port: 8080,
        securityContext: serverSecurityContext,
      );
      profiles.addAll([
        ServerProfileContext(serverProfile: insecure),
        ServerProfileContext(serverProfile: secure),
      ]);
    }
    final ServerProfileContext profileContext;
    if (profileName.isEmpty) {
      profileContext = profiles.first;
    } else {
      try {
        profileContext = profiles.firstWhere(
          (final element) => element.serverProfile.name
              .toLowerCase()
              .startsWith(profileName.toLowerCase()),
        );
        // ignore: avoid_catching_errors
      } on StateError {
        stderr
          ..writeln('No server profile found matching $profileName.')
          ..writeln('Profiles:');
        for (final profile in profiles) {
          stderr.writeln(profile.serverProfile.name);
        }
        exit(126);
      }
    }
    final serverProfile = profileContext.serverProfile;
    final host = serverProfile.host;
    final port = serverProfile.port;
    final serverSecurity = profileContext.securityContext;
    final SecurityContext? securityContext;
    if (serverSecurity == null) {
      securityContext = null;
    } else {
      securityContext = SecurityContext()
        ..useCertificateChain(
          serverSecurity.chainFilePath,
          password: serverSecurity.chainPassword,
        )
        ..usePrivateKey(
          serverSecurity.keyFilePath,
          password: serverSecurity.keyPassword,
        );
    }
    final protocol = securityContext == null ? 'http' : 'https';
    final connections = <ConnectionContext>[];
    await shelfRun(
      () {
        final router = Router().plus
          ..use(logRequests())
          ..get('/', () => 'Welcome to Monolith.')
          // ignore: avoid_types_on_closure_parameters
          ..get('/ws/', (final Request request) {
            final connectionInfo = request.context['shelf.io.connection_info']
                as HttpConnectionInfo;
            final uuid = uuidGenerator.v4();
            final connection = ConnectionContext(
              uuid: uuid,
              host: connectionInfo.remoteAddress.host,
              port: connectionInfo.remotePort,
            );
            return WebSocketSession(
              onOpen: (final session) {
                connection.logger.info('Connection established.');
                connections.add(connection);
              },
              onClose: (final session) {
                connection.logger.info('Connection closed.');
                connections.remove(connection);
              },
              onMessage: (final session, final data) => connection.logger.info(
                data,
              ),
              onError: (final session, final error) =>
                  connection.logger.warning(
                error,
              ),
            );
          });
        return router;
      },
      defaultBindAddress: host,
      defaultBindPort: port,
      defaultEnableHotReload: false,
      onClosed: () => serverLogger.fine('Server done.'),
      onStarted: (final address, final port) => serverLogger.fine(
        'Listening on $protocol://$address:$port.',
      ),
      securityContext: securityContext,
    );
  } finally {
    await database.close();
    await fileAppender?.dispose();
  }
}
