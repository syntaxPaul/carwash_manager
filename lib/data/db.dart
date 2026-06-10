import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'migrations.dart';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<String> get databasePath async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/carwash_manager.db';
  }

  Future<Database> get db async {
    if (_db != null) return _db!;
    final path = await databasePath;
    _db = await openDatabase(
      path,
      version: migrations.length,
      onCreate: (d, v) async {
        for (final m in migrations) {
          await _executeMigrationBatch(d, m);
        }
      },
      onUpgrade: (d, ov, nv) async {
        // Apply only the migrations that haven't been run yet.
        // `ov` reflects how many migrations have already executed, so we start
        // from that index and move forward until we reach the new version.
        for (int version = ov;
            version < nv && version < migrations.length;
            version++) {
          await _executeMigrationBatch(d, migrations[version]);
        }
      },
      onOpen: (d) async {
        // Repair older databases that were upgraded with partial multi-SQL
        // migrations (e.g. missing columns after first statement succeeded).
        await _repairSchema(d);
      },
    );
    return _db!;
  }

  Future<Uint8List> exportBytes() async {
    final database = await db;
    try {
      await database.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } on DatabaseException {
      // Some platforms or journal modes may not support a WAL checkpoint.
    }

    final file = File(await databasePath);
    if (!await file.exists()) {
      throw StateError('The local WashDesk database has not been created yet.');
    }
    return file.readAsBytes();
  }

  Future<void> replaceWithBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      throw StateError('The backup file is empty.');
    }
    if (bytes.length < 16 ||
        String.fromCharCodes(bytes.take(15)) != 'SQLite format 3') {
      throw StateError('The backup file is not a WashDesk database.');
    }

    await close();
    final path = await databasePath;
    await _deleteSidecarFiles(path);
    await File(path).writeAsBytes(bytes, flush: true);
    await _deleteSidecarFiles(path);
    await db;
  }

  Future<void> close() async {
    final database = _db;
    _db = null;
    await database?.close();
  }

  Future<void> deleteLocalDatabase() async {
    await close();
    final path = await databasePath;
    await _deleteSidecarFiles(path);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await _deleteSidecarFiles(path);
  }

  Future<void> _executeMigrationBatch(
      DatabaseExecutor db, String sqlBatch) async {
    final statements = _splitSqlStatements(sqlBatch);
    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  Future<void> _repairSchema(Database db) async {
    for (final migration in migrations) {
      final statements = _splitSqlStatements(migration);
      for (final statement in statements) {
        try {
          await db.execute(statement);
        } on DatabaseException catch (e) {
          if (_isIgnorableSchemaError(e)) continue;
          rethrow;
        }
      }
    }
  }

  List<String> _splitSqlStatements(String sqlBatch) {
    return sqlBatch
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .map((s) => '$s;')
        .toList(growable: false);
  }

  bool _isIgnorableSchemaError(DatabaseException e) {
    final message = e.toString().toLowerCase();
    return message.contains('already exists') ||
        message.contains('duplicate column name');
  }

  Future<void> _deleteSidecarFiles(String path) async {
    for (final suffix in const ['-wal', '-shm']) {
      final file = File('$path$suffix');
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
