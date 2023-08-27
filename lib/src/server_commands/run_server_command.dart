import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:database/database.dart';
import 'package:logging/logging.dart';
import 'package:shelf_plus/shelf_plus.dart';

import '../app_config.dart';

/// Start the server running.
class RunServerCommand extends Command {
  /// Create an instance.
  RunServerCommand(this.appConfig) : super() {
    argParser.addOption(
      'profile-id',
      abbr: 'p',
    );
  }

  /// The app configuration to use.
  final AppConfig appConfig;

  /// The name of this command.
  @override
  String get name => 'run';

  /// The description of this command.
  @override
  String get description => 'Run the server.';

  /// Run the server.
  @override
  Future<void> run() async {
    final logger = Logger('Run Server');
    final database = appConfig.getDatabase();
    final serverProfilesDao = database.serverProfilesDao;
    final profileIdString = argResults?['profile-id'] as String?;
    final ServerProfileContext profileContext;
    if (profileIdString == null) {
      final profiles = await serverProfilesDao.getServerProfileContexts();
      if (profiles.isEmpty) {
        usageException(
          'First create server profiles with the `profiles` subcommand.',
        );
      }
      profileContext = profiles.first;
    } else {
      final profileId = int.tryParse(profileIdString);
      if (profileId == null) {
        usageException('Invalid ID: $profileIdString.');
      }
      try {
        profileContext =
            await serverProfilesDao.getServerProfileContext(profileId);
        // ignore: avoid_catching_errors
      } on StateError {
        usageException('Invalid profile ID: $profileId.');
      }
    }
    logger.info('Using server profile $profileContext.');
    final serverSecurity = profileContext.securityContext;
    final SecurityContext? securityContext;
    if (serverSecurity != null) {
      securityContext = SecurityContext()
        ..useCertificateChain(
          serverSecurity.chainFilePath,
          password: serverSecurity.chainPassword,
        )
        ..usePrivateKey(
          serverSecurity.keyFilePath,
          password: serverSecurity.keyPassword,
        );
    } else {
      securityContext = null;
    }
    final profile = profileContext.serverProfile;
    await shelfRun(
      () {
        final router = Router().plus..use(logRequests());
        return router;
      },
      defaultBindAddress: profile.host,
      defaultBindPort: profile.port,
      securityContext: securityContext,
    );
  }
}
