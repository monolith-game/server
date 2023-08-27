// ignore_for_file: avoid_print
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:database/database.dart';

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
    final serverProfilesDao = database.serverProfilesDao;
    final profiles =
        (await serverProfilesDao.getServerProfileContexts()).toList();
    final serverSecurityContextsDao = database.serverSecurityContextsDao;
    if (profiles.isEmpty) {
      final serverSecurityContext =
          await serverSecurityContextsDao.createServerSecurityContext(
        chainFile: File(
          'fullchain.pem',
        ),
        keyFile: File('privkey.pem'),
      );
      profiles.addAll([
        ServerProfileContext(
          serverProfile: await serverProfilesDao.createServerProfile(
            name: 'Insecure',
            host: '0.0.0.0',
            port: 8080,
          ),
        ),
        ServerProfileContext(
          serverProfile: await serverProfilesDao.createServerProfile(
            name: 'Secure',
            host: '0.0.0.0',
            port: 8080,
            securityContext: serverSecurityContext,
          ),
          securityContext: serverSecurityContext,
        ),
      ]);
    }
    print('Server Profiles:');
    for (final context in profiles) {
      final profile = context.serverProfile;
      print('#${profile.id}: ${profile.name}');
      print('Listen on: ${profile.host}:${profile.port}');
      final security = context.securityContext;
      if (security == null) {
        print('Security: None');
      } else {
        print(
          'Chain file: ${security.chainFilePath} (${security.chainPassword})',
        );
        print('Key file: ${security.keyFilePath} (${security.keyPassword})');
      }
    }
    await database.close();
  }
}
