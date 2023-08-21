import 'dart:io';

import 'package:args/args.dart';
import 'package:database/database.dart';

/// The general application configuration.
class AppConfig {
  /// Create an instance.
  const AppConfig({
    required this.databaseFile,
    required this.logSql,
  });

  /// Create an instance from [argResults].
  AppConfig.fromArgResults(final ArgResults argResults)
      : databaseFile = File(argResults['database'] as String),
        logSql = argResults['log-sql'] as bool;

  /// The database file to load from.
  final File databaseFile;

  /// Whether to log SQL queries or not.
  final bool logSql;

  /// Get a database.
  MonolithDatabase getDatabase() =>
      MonolithDatabase(file: databaseFile, logStatements: logSql);
}
