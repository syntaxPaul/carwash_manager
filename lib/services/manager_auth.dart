import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../data/settings.dart';
import 'supabase_backend.dart';

const int managerTrialDays = 5;
const String managerSubscriptionPrice = 'R499.99';
const String managerMonthlyProductId = 'washdesk_monthly';

class ManagerAccount {
  final String id;
  final String businessName;
  final String ownerName;
  final String email;
  final int trialStartTs;
  final int trialEndTs;
  final String subscriptionStatus;
  final String subscriptionSource;
  final String? subscriptionProductId;
  final String? subscriptionPurchaseId;
  final int? subscriptionUpdatedTs;
  final int createdTs;
  final int? lastLoginTs;

  const ManagerAccount({
    required this.id,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.trialStartTs,
    required this.trialEndTs,
    required this.subscriptionStatus,
    required this.subscriptionSource,
    required this.subscriptionProductId,
    required this.subscriptionPurchaseId,
    required this.subscriptionUpdatedTs,
    required this.createdTs,
    required this.lastLoginTs,
  });

  factory ManagerAccount.fromMap(Map<String, Object?> map) {
    return ManagerAccount(
      id: map['id'] as String,
      businessName: map['business_name'] as String,
      ownerName: map['owner_name'] as String,
      email: map['email'] as String,
      trialStartTs: map['trial_start_ts'] as int,
      trialEndTs: map['trial_end_ts'] as int,
      subscriptionStatus: map['subscription_status'] as String,
      subscriptionSource:
          (map['subscription_source'] as String?) ?? 'local_trial',
      subscriptionProductId: map['subscription_product_id'] as String?,
      subscriptionPurchaseId: map['subscription_purchase_id'] as String?,
      subscriptionUpdatedTs: map['subscription_updated_ts'] as int?,
      createdTs: map['created_ts'] as int,
      lastLoginTs: map['last_login_ts'] as int?,
    );
  }

  bool get isActive => subscriptionStatus == 'active';
  bool get isTrialing => subscriptionStatus == 'trialing';
  bool get isExpired => !hasAccess;

  bool get hasAccess {
    if (isActive) return true;
    if (!isTrialing) return false;
    return DateTime.now().millisecondsSinceEpoch <= trialEndTs;
  }

  Duration get trialRemaining {
    final end = DateTime.fromMillisecondsSinceEpoch(trialEndTs);
    final diff = end.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  int get trialDaysRemaining {
    final remaining = trialRemaining;
    if (remaining == Duration.zero) return 0;
    return (remaining.inHours / 24).ceil().clamp(1, managerTrialDays).toInt();
  }

  ManagerAccount copyWith({
    String? subscriptionStatus,
    String? subscriptionSource,
    String? subscriptionProductId,
    String? subscriptionPurchaseId,
    int? subscriptionUpdatedTs,
    int? lastLoginTs,
  }) {
    return ManagerAccount(
      id: id,
      businessName: businessName,
      ownerName: ownerName,
      email: email,
      trialStartTs: trialStartTs,
      trialEndTs: trialEndTs,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionSource: subscriptionSource ?? this.subscriptionSource,
      subscriptionProductId:
          subscriptionProductId ?? this.subscriptionProductId,
      subscriptionPurchaseId:
          subscriptionPurchaseId ?? this.subscriptionPurchaseId,
      subscriptionUpdatedTs:
          subscriptionUpdatedTs ?? this.subscriptionUpdatedTs,
      createdTs: createdTs,
      lastLoginTs: lastLoginTs ?? this.lastLoginTs,
    );
  }
}

class ManagerAuth extends ChangeNotifier {
  ManagerAuth._();
  static final ManagerAuth instance = ManagerAuth._();

  static const String _sessionKey = 'manager_session';
  static const String _trialing = 'trialing';
  static const String _active = 'active';
  static const String _expired = 'expired';

  final ValueNotifier<ManagerAccount?> _notifier =
      ValueNotifier<ManagerAccount?>(null);

  ValueListenable<ManagerAccount?> get listenable => _notifier;
  ManagerAccount? get current => _notifier.value;
  bool get isSignedIn => current != null;
  bool get hasCurrentAccess => current?.hasAccess ?? false;

  bool _bootstrapped = false;
  bool get isBootstrapped => _bootstrapped;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    final db = await AppDb.instance.db;
    ManagerAccount? account;
    try {
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [_sessionKey],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final id = rows.first['value'] as String;
        account = await _loadAccountById(db, id);
        if (account == null) {
          await _clearSession(db);
        } else {
          account = await _refreshTrialStatus(db, account);
        }
      }
    } finally {
      _bootstrapped = true;
      _setCurrent(account);
    }
  }

  Future<ManagerAccount> register({
    required String businessName,
    required String ownerName,
    required String email,
    required String password,
  }) async {
    final db = await AppDb.instance.db;
    final normalizedEmail = _normalizeEmail(email);
    final existing = await db.query(
      'manager_accounts',
      where: 'email = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError('An account already exists for that email address.');
    }

    await SupabaseBackend.instance.registerManager(
      email: normalizedEmail,
      password: password,
      businessName: businessName,
      ownerName: ownerName,
    );
    final cloudState = await SupabaseBackend.instance.upsertManagerProfile(
      businessName: businessName,
      ownerName: ownerName,
    );

    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final salt = _newSalt();
    final id = SupabaseBackend.instance.currentUser?.id ?? const Uuid().v4();
    final trialEnd = now.add(const Duration(days: managerTrialDays));
    final row = {
      'id': id,
      'business_name': businessName.trim(),
      'owner_name': ownerName.trim(),
      'email': normalizedEmail,
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
      'trial_start_ts': cloudState?.trialStartTs ?? nowMs,
      'trial_end_ts': cloudState?.trialEndTs ?? trialEnd.millisecondsSinceEpoch,
      'subscription_status': cloudState?.subscriptionStatus ?? _trialing,
      'subscription_source': cloudState == null ? 'local_trial' : 'supabase',
      'subscription_product_id': cloudState?.subscriptionProductId,
      'subscription_purchase_id': cloudState?.subscriptionPurchaseId,
      'subscription_verification_data': null,
      'subscription_updated_ts': cloudState?.subscriptionUpdatedTs,
      'created_ts': nowMs,
      'last_login_ts': nowMs,
    };

    await db.insert('manager_accounts', row);
    final account = ManagerAccount.fromMap(row);
    await _persistSession(db, id);
    _setCurrent(account);
    return account;
  }

  Future<ManagerAccount> login({
    required String email,
    required String password,
  }) async {
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'manager_accounts',
      where: 'email = ?',
      whereArgs: [_normalizeEmail(email)],
      limit: 1,
    );
    if (rows.isEmpty) {
      return _loginWithCloudAccount(
        db: db,
        email: email,
        password: password,
      );
    }
    final row = rows.first;
    final salt = row['password_salt'] as String;
    final storedHash = row['password_hash'] as String;
    if (storedHash != _hashPassword(password, salt)) {
      throw StateError('Incorrect password.');
    }

    await SupabaseBackend.instance.signIn(
      email: _normalizeEmail(email),
      password: password,
    );

    final now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'manager_accounts',
      {'last_login_ts': now},
      where: 'id = ?',
      whereArgs: [row['id']],
    );
    var account = ManagerAccount.fromMap({...row, 'last_login_ts': now});
    account = await _refreshCloudAccessState(db, account);
    account = await _refreshTrialStatus(db, account);
    await _persistSession(db, account.id);
    _setCurrent(account);
    return account;
  }

  Future<ManagerAccount> _loginWithCloudAccount({
    required Database db,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);
    await SupabaseBackend.instance.signIn(
      email: normalizedEmail,
      password: password,
    );

    final user = SupabaseBackend.instance.currentUser;
    final metadata = user?.userMetadata ?? const <String, dynamic>{};
    final profileBusinessName = _metadataText(
      metadata['business_name'],
      fallback: 'WashDesk Review',
    );
    final profileOwnerName = _metadataText(
      metadata['owner_name'],
      fallback: 'App Review',
    );
    final cloudState = await SupabaseBackend.instance.upsertManagerProfile(
      businessName: profileBusinessName,
      ownerName: profileOwnerName,
    );
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final defaultTrialEnd = now.add(const Duration(days: managerTrialDays));
    final trialStartTs = cloudState?.trialStartTs ??
        _metadataInt(metadata['trial_start_ts']) ??
        nowMs;
    final trialEndTs = cloudState?.trialEndTs ??
        _metadataInt(metadata['trial_end_ts']) ??
        defaultTrialEnd.millisecondsSinceEpoch;
    final subscriptionStatus = _metadataSubscriptionStatus(
      cloudState?.subscriptionStatus ?? metadata['subscription_status'],
      trialEndTs: trialEndTs,
      nowTs: nowMs,
    );
    final salt = _newSalt();
    final row = {
      'id': user?.id ?? const Uuid().v4(),
      'business_name': cloudState?.businessName ?? profileBusinessName,
      'owner_name': cloudState?.ownerName ?? profileOwnerName,
      'email': normalizedEmail,
      'password_hash': _hashPassword(password, salt),
      'password_salt': salt,
      'trial_start_ts': trialStartTs,
      'trial_end_ts': trialEndTs,
      'subscription_status': subscriptionStatus,
      'subscription_source': _metadataText(
        metadata['subscription_source'],
        fallback: cloudState == null ? 'cloud_trial' : 'supabase',
      ),
      'subscription_product_id': cloudState?.subscriptionProductId ??
          _optionalMetadataText(metadata['subscription_product_id']),
      'subscription_purchase_id': cloudState?.subscriptionPurchaseId ??
          _optionalMetadataText(metadata['subscription_purchase_id']),
      'subscription_verification_data': null,
      'subscription_updated_ts': cloudState?.subscriptionUpdatedTs ??
          _metadataInt(metadata['subscription_updated_ts']),
      'created_ts': nowMs,
      'last_login_ts': nowMs,
    };

    await db.insert(
      'manager_accounts',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final account = ManagerAccount.fromMap(row);
    await _persistSession(db, account.id);
    _setCurrent(account);
    return account;
  }

  Future<void> logout() async {
    final db = await AppDb.instance.db;
    await _clearSession(db);
    await SupabaseBackend.instance.signOut();
    _setCurrent(null);
  }

  Future<void> deleteCurrentAccount() async {
    final account = current;
    if (account == null) {
      throw StateError('Sign in before deleting your account.');
    }

    await SupabaseBackend.instance.deleteCurrentUserAndBackups();
    await AppDb.instance.deleteLocalDatabase();
    AppSettings.instance.resetToDefaults();
    _setCurrent(null);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final account = current;
    if (account == null) throw StateError('Sign in before changing password.');

    final db = await AppDb.instance.db;
    final rows = await db.query(
      'manager_accounts',
      where: 'id = ?',
      whereArgs: [account.id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Account could not be found.');
    final row = rows.first;
    final currentSalt = row['password_salt'] as String;
    if (row['password_hash'] != _hashPassword(currentPassword, currentSalt)) {
      throw StateError('Current password is incorrect.');
    }
    final nextSalt = _newSalt();
    await SupabaseBackend.instance.changePassword(newPassword);
    await db.update(
      'manager_accounts',
      {
        'password_salt': nextSalt,
        'password_hash': _hashPassword(newPassword, nextSalt),
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<void> resetPassword({
    required String email,
    required String businessName,
    required String newPassword,
  }) async {
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'manager_accounts',
      where: 'email = ?',
      whereArgs: [_normalizeEmail(email)],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('No WashDesk account found for that email.');
    }
    final row = rows.first;
    final savedBusiness = (row['business_name'] as String).trim().toLowerCase();
    if (savedBusiness != businessName.trim().toLowerCase()) {
      throw StateError('Business name does not match this account.');
    }
    final salt = _newSalt();
    await db.update(
      'manager_accounts',
      {
        'password_salt': salt,
        'password_hash': _hashPassword(newPassword, salt),
      },
      where: 'id = ?',
      whereArgs: [row['id']],
    );
  }

  Future<ManagerAccount?> restoreAccess() async {
    final account = current;
    if (account == null) return null;
    final db = await AppDb.instance.db;
    final fresh = await _loadAccountById(db, account.id);
    if (fresh == null) {
      await _clearSession(db);
      _setCurrent(null);
      return null;
    }
    final refreshed = await _refreshTrialStatus(db, fresh);
    _setCurrent(refreshed);
    return refreshed;
  }

  Future<ManagerAccount> activateSubscription({
    required String productId,
    required String verificationSource,
    required String verificationData,
    String? purchaseId,
  }) async {
    final account = current;
    if (account == null) {
      throw StateError('Sign in before activating a subscription.');
    }
    if (productId != managerMonthlyProductId) {
      throw StateError('Purchase does not match the WashDesk monthly plan.');
    }

    final db = await AppDb.instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cloudState = await SupabaseBackend.instance.recordAppStorePurchase(
      productId: productId,
      purchaseId: purchaseId,
      verificationSource: verificationSource,
      verificationData: verificationData,
    );
    await db.transaction((txn) async {
      await txn.update(
        'manager_accounts',
        {
          'subscription_status': _active,
          'subscription_source': cloudState == null
              ? verificationSource
              : 'app_store_pending_server_verification',
          'subscription_product_id':
              cloudState?.subscriptionProductId ?? productId,
          'subscription_purchase_id':
              cloudState?.subscriptionPurchaseId ?? purchaseId,
          'subscription_verification_data': verificationData,
          'subscription_updated_ts': cloudState?.subscriptionUpdatedTs ?? now,
        },
        where: 'id = ?',
        whereArgs: [account.id],
      );
      await txn.insert('subscription_events', {
        'id': const Uuid().v4(),
        'account_id': account.id,
        'product_id': productId,
        'purchase_id': purchaseId,
        'verification_source': verificationSource,
        'verification_data': verificationData,
        'status': _active,
        'event_ts': now,
      });
    });

    final updated = account.copyWith(
      subscriptionStatus: _active,
      subscriptionSource: cloudState == null
          ? verificationSource
          : 'app_store_pending_server_verification',
      subscriptionProductId: cloudState?.subscriptionProductId ?? productId,
      subscriptionPurchaseId: cloudState?.subscriptionPurchaseId ?? purchaseId,
      subscriptionUpdatedTs: cloudState?.subscriptionUpdatedTs ?? now,
    );
    _setCurrent(updated);
    return updated;
  }

  Future<ManagerAccount?> _loadAccountById(
    DatabaseExecutor db,
    String id,
  ) async {
    final rows = await db.query(
      'manager_accounts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ManagerAccount.fromMap(rows.first);
  }

  Future<ManagerAccount> _refreshTrialStatus(
    DatabaseExecutor db,
    ManagerAccount account,
  ) async {
    if (account.subscriptionStatus != _trialing || account.hasAccess) {
      return account;
    }
    await db.update(
      'manager_accounts',
      {'subscription_status': _expired},
      where: 'id = ?',
      whereArgs: [account.id],
    );
    return account.copyWith(subscriptionStatus: _expired);
  }

  Future<ManagerAccount> _refreshCloudAccessState(
    Database db,
    ManagerAccount account,
  ) async {
    final cloudState = await SupabaseBackend.instance.fetchManagerAccessState();
    if (cloudState == null || cloudState.subscriptionStatus == null) {
      return account;
    }

    final updated = account.copyWith(
      subscriptionStatus: cloudState.subscriptionStatus,
      subscriptionSource: 'supabase',
      subscriptionProductId: cloudState.subscriptionProductId,
      subscriptionPurchaseId: cloudState.subscriptionPurchaseId,
      subscriptionUpdatedTs: cloudState.subscriptionUpdatedTs,
    );
    await db.update(
      'manager_accounts',
      {
        'subscription_status': updated.subscriptionStatus,
        'subscription_source': updated.subscriptionSource,
        'subscription_product_id': updated.subscriptionProductId,
        'subscription_purchase_id': updated.subscriptionPurchaseId,
        'subscription_updated_ts': updated.subscriptionUpdatedTs,
      },
      where: 'id = ?',
      whereArgs: [account.id],
    );
    return updated;
  }

  Future<void> _persistSession(DatabaseExecutor db, String accountId) async {
    await db.insert(
      'settings',
      {'key': _sessionKey, 'value': accountId},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _clearSession(DatabaseExecutor db) async {
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: [_sessionKey],
    );
  }

  void _setCurrent(ManagerAccount? account) {
    _notifier.value = account;
    notifyListeners();
  }

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  String _metadataText(Object? value, {required String fallback}) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  String? _optionalMetadataText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  int? _metadataInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  String _metadataSubscriptionStatus(
    Object? value, {
    required int trialEndTs,
    required int nowTs,
  }) {
    final status = value?.toString().trim().toLowerCase();
    if (status == _active || status == _expired || status == _trialing) {
      return status!;
    }
    return trialEndTs <= nowTs ? _expired : _trialing;
  }

  String _newSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final normalized = password.trim();
    final bytes = utf8.encode('$salt:$normalized');
    return sha256.convert(bytes).toString();
  }
}
