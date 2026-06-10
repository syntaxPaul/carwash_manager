import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/db.dart';
import '../data/settings.dart';
import 'manager_auth.dart';
import 'supabase_backend.dart';

const String cloudBackupSupabaseUrl =
    String.fromEnvironment('WASHDESK_SUPABASE_URL');
const String cloudBackupSupabaseAnonKey =
    String.fromEnvironment('WASHDESK_SUPABASE_ANON_KEY');
const String cloudBackupBucket = String.fromEnvironment(
  'WASHDESK_BACKUP_BUCKET',
  defaultValue: 'washdesk-backups',
);
const String cloudBackupPathPrefix = String.fromEnvironment(
  'WASHDESK_BACKUP_PATH_PREFIX',
  defaultValue: 'manager',
);

class CloudBackupResult {
  final DateTime timestamp;
  final int sizeBytes;
  final String message;

  const CloudBackupResult({
    required this.timestamp,
    required this.sizeBytes,
    required this.message,
  });
}

class CloudBackupService extends ChangeNotifier {
  CloudBackupService._();
  static final CloudBackupService instance = CloudBackupService._();

  static const String _lastBackupKey = 'cloud_backup_last_ts';

  bool _bootstrapped = false;
  bool _busy = false;
  DateTime? _lastBackupAt;

  bool get isConfigured =>
      cloudBackupSupabaseUrl.trim().isNotEmpty &&
      cloudBackupSupabaseAnonKey.trim().isNotEmpty;
  bool get isBusy => _busy;
  DateTime? get lastBackupAt => _lastBackupAt;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    await refreshLocalState();
  }

  Future<void> refreshLocalState() async {
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [_lastBackupKey],
      limit: 1,
    );
    final value =
        rows.isEmpty ? null : int.tryParse(rows.first['value'] as String);
    _lastBackupAt =
        value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
    notifyListeners();
  }

  Future<CloudBackupResult> backupNow(ManagerAccount account) async {
    _ensureConfigured();
    _setBusy(true);
    try {
      final cloudUserId = _requireCloudUserId(account);
      final bytes = await AppDb.instance.exportBytes();
      final now = DateTime.now();
      final bucket = _bucket;
      await bucket.uploadBinary(
        _databasePath(cloudUserId),
        bytes,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'application/octet-stream',
        ),
      );
      await bucket.uploadBinary(
        _metadataPath(cloudUserId),
        Uint8List.fromList(
          _jsonBytes({
            'app': 'WashDesk',
            'supabaseUserId': cloudUserId,
            'accountId': account.id,
            'businessName': account.businessName,
            'email': account.email,
            'generatedAt': now.toUtc().toIso8601String(),
            'sizeBytes': bytes.length,
          }),
        ),
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'application/json; charset=utf-8',
        ),
      );
      await _saveLastBackup(now);
      await SupabaseBackend.instance.recordBackupHealth(
        status: 'ok',
        sizeBytes: bytes.length,
      );
      return CloudBackupResult(
        timestamp: now,
        sizeBytes: bytes.length,
        message: 'Cloud backup saved',
      );
    } catch (error) {
      await SupabaseBackend.instance.recordBackupHealth(
        status: 'failed',
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<CloudBackupResult> restoreLatest(ManagerAccount account) async {
    _ensureConfigured();
    _setBusy(true);
    try {
      final cloudUserId = _requireCloudUserId(account);
      late final Uint8List bytes;
      try {
        bytes = await _bucket.download(_databasePath(cloudUserId));
      } on StorageException catch (e) {
        if (e.statusCode == '404' ||
            e.message.toLowerCase().contains('not found')) {
          throw StateError(
            'No cloud backup exists for this signed-in account yet.',
          );
        }
        throw StateError('Cloud restore failed: ${e.message}');
      }
      await AppDb.instance.replaceWithBytes(bytes);
      await AppSettings.instance.load();
      await ManagerAuth.instance.restoreAccess();
      await refreshLocalState();
      await SupabaseBackend.instance.recordBackupHealth(
        status: 'restored',
        sizeBytes: bytes.length,
        eventKind: 'restore',
      );

      final now = DateTime.now();
      return CloudBackupResult(
        timestamp: now,
        sizeBytes: bytes.length,
        message: 'Cloud backup restored',
      );
    } finally {
      _setBusy(false);
    }
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Cloud backup is not configured. Add WASHDESK_SUPABASE_URL and '
        'WASHDESK_SUPABASE_ANON_KEY at build time.',
      );
    }
  }

  String _requireCloudUserId(ManagerAccount account) {
    final backend = SupabaseBackend.instance;
    final user = backend.currentUser;
    final session = backend.currentSession;
    if (user == null || session == null) {
      throw StateError(
        'Sign in again before using cloud backup. Backups require a secure '
        'Supabase session for ${account.email}.',
      );
    }
    return user.id;
  }

  Future<void> _saveLastBackup(DateTime timestamp) async {
    final db = await AppDb.instance.db;
    await db.insert(
      'settings',
      {
        'key': _lastBackupKey,
        'value': timestamp.millisecondsSinceEpoch.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _lastBackupAt = timestamp;
    notifyListeners();
  }

  StorageFileApi get _bucket {
    final client = SupabaseBackend.instance.client;
    if (client == null) {
      throw StateError('Cloud backup is not configured for this build.');
    }
    return client.storage.from(cloudBackupBucket);
  }

  String _databasePath(String cloudUserId) =>
      '${_prefix(cloudUserId)}/carwash_manager.db';

  String _metadataPath(String cloudUserId) =>
      '${_prefix(cloudUserId)}/metadata.json';

  String _prefix(String cloudUserId) =>
      '${cloudBackupPathPrefix.trim()}/$cloudUserId';

  List<int> _jsonBytes(Map<String, Object?> value) {
    return const JsonEncoder.withIndent('  ').convert(value).codeUnits;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}
