// ignore_for_file: avoid_print
import 'dart:io';

import 'package:args/command_runner.dart';

import '../app_config.dart';

/// The profiles command.
class ProfilesServerCommand extends Command {
  /// Create an instance.
  ProfilesServerCommand(
    this.appConfig,
  ) : super();

  /// The app configuration to use.
  final AppConfig appConfig;

  /// The name of this command.
  @override
  String get name => 'profiles';

  /// The description of this command.
  @override
  String get description => 'Show the available server profiles.';

  /// Run the command.
  @override
  Future<void> run() async {
    final database = appConfig.getDatabase();
    final profiles = await database.select(database.serverProfiles).get();
    final serverSecurityContextsDao = database.serverSecurityContextsDao;
    if (profiles.isEmpty) {
      final serverProfilesDao = database.serverProfilesDao;
      final serverSecurityContext =
          await serverSecurityContextsDao.createServerSecurityContext(
        chainFile: File(
          'fullchain.pem',
        ),
        keyFile: File('privkey.pem'),
      );
      profiles.addAll([
        await serverProfilesDao.createServerProfile(
          name: 'Insecure',
          host: '0.0.0.0',
          port: 8080,
        ),
        await serverProfilesDao.createServerProfile(
          name: 'Secure',
          host: '0.0.0.0',
          port: 8080,
          securityContext: serverSecurityContext,
        ),
      ]);
    }
    print('Server Profiles:');
    for (final profile in profiles) {
      print(profile.name);
      print('Listen on: ${profile.host}:${profile.port}');
      final serverSecurityContextId = profile.securityContextId;
      if (serverSecurityContextId == null) {
        print('Security: None');
      } else {
        final context = await serverSecurityContextsDao
            .getServerSecurityContext(serverSecurityContextId);
        print(
          'Chain file: ${context.chainFilePath} (${context.chainPassword})',
        );
        print('Key file: ${context.keyFilePath} (${context.keyPassword})');
      }
    }
    await database.close();
  }
}
