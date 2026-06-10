import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cloud_backup_service.dart';

class CloudAccessState {
  final String? businessId;
  final String? businessName;
  final String? ownerName;
  final String? email;
  final int? trialStartTs;
  final int? trialEndTs;
  final String? subscriptionStatus;
  final String? subscriptionProductId;
  final String? subscriptionPurchaseId;
  final int? subscriptionUpdatedTs;

  const CloudAccessState({
    required this.businessId,
    required this.businessName,
    required this.ownerName,
    required this.email,
    required this.trialStartTs,
    required this.trialEndTs,
    required this.subscriptionStatus,
    required this.subscriptionProductId,
    required this.subscriptionPurchaseId,
    required this.subscriptionUpdatedTs,
  });

  factory CloudAccessState.fromJson(Map<String, dynamic> json) {
    return CloudAccessState(
      businessId: _text(json['business_id']),
      businessName: _text(json['business_name']),
      ownerName: _text(json['owner_name']),
      email: _text(json['email']),
      trialStartTs: _int(json['trial_start_ts']),
      trialEndTs: _int(json['trial_end_ts']),
      subscriptionStatus: _text(json['subscription_status']),
      subscriptionProductId: _text(json['subscription_product_id']),
      subscriptionPurchaseId: _text(json['subscription_purchase_id']),
      subscriptionUpdatedTs: _int(json['subscription_updated_ts']),
    );
  }

  static String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }
}

class SupabaseBackend extends ChangeNotifier {
  SupabaseBackend._();
  static final SupabaseBackend instance = SupabaseBackend._();

  static const Duration _networkTimeout = Duration(seconds: 20);

  bool _bootstrapped = false;
  String? _message;

  bool get isConfigured =>
      cloudBackupSupabaseUrl.trim().isNotEmpty &&
      cloudBackupSupabaseAnonKey.trim().isNotEmpty;
  bool get isBootstrapped => _bootstrapped;
  String? get message => _message;

  SupabaseClient? get client {
    if (!isConfigured || !Supabase.instance.isInitialized) return null;
    return Supabase.instance.client;
  }

  User? get currentUser => client?.auth.currentUser;
  Session? get currentSession => client?.auth.currentSession;
  bool get isSignedIn => currentSession?.accessToken.isNotEmpty ?? false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    _bootstrapped = true;
    if (!isConfigured) return;

    try {
      await Supabase.initialize(
        url: cloudBackupSupabaseUrl.trim(),
        anonKey: cloudBackupSupabaseAnonKey.trim(),
        debug: kDebugMode,
      ).timeout(_networkTimeout);
    } on TimeoutException {
      _bootstrapped = false;
      throw StateError(
          'Connection timed out. Check your internet and try again.');
    }
    _message = null;
    notifyListeners();
  }

  Future<void> registerManager({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
  }) async {
    if (!isConfigured) return;
    await bootstrap();
    final auth = _auth;
    try {
      final response = await auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          'business_name': businessName.trim(),
          'owner_name': ownerName.trim(),
          'role': 'manager',
        },
      ).timeout(_networkTimeout);
      if (response.session == null) {
        await signIn(email: email, password: password);
      }
    } on AuthException catch (e) {
      if (_isAlreadyRegistered(e)) {
        await signIn(email: email, password: password);
        return;
      }
      throw StateError(_authMessage(e));
    } on TimeoutException {
      throw StateError(
          'Connection timed out. Check your internet and try again.');
    }
  }

  Future<CloudAccessState?> upsertManagerProfile({
    required String businessName,
    required String ownerName,
  }) async {
    if (!isConfigured) return null;
    await bootstrap();
    if (_auth.currentSession == null) return null;
    try {
      final response = await client!.rpc(
        'upsert_manager_profile',
        params: {
          'business_name': businessName.trim(),
          'owner_name': ownerName.trim(),
        },
      ).timeout(_networkTimeout);
      return _cloudState(response);
    } on Object {
      return null;
    }
  }

  Future<CloudAccessState?> fetchManagerAccessState() async {
    if (!isConfigured) return null;
    await bootstrap();
    if (_auth.currentSession == null) return null;
    try {
      final response = await client!
          .rpc('get_manager_access_state')
          .timeout(_networkTimeout);
      return _cloudState(response);
    } on Object {
      return null;
    }
  }

  Future<CloudAccessState?> recordAppStorePurchase({
    required String productId,
    required String verificationSource,
    required String verificationData,
    String? purchaseId,
  }) async {
    if (!isConfigured) return null;
    await bootstrap();
    if (_auth.currentSession == null) return null;
    try {
      final response = await client!.rpc(
        'record_app_store_purchase',
        params: {
          'product_id': productId,
          'purchase_id': purchaseId,
          'verification_source': verificationSource,
          'verification_data': verificationData,
        },
      ).timeout(_networkTimeout);
      return _cloudState(response);
    } on Object {
      return null;
    }
  }

  Future<void> recordBackupHealth({
    required String status,
    int? sizeBytes,
    String? errorMessage,
    String eventKind = 'backup',
  }) async {
    if (!isConfigured) return;
    await bootstrap();
    if (_auth.currentSession == null) return;
    try {
      await client!.rpc(
        'record_backup_health',
        params: {
          'status': status,
          'size_bytes': sizeBytes,
          'error_message': errorMessage,
          'event_kind': eventKind,
        },
      ).timeout(_networkTimeout);
    } on Object {
      return;
    }
  }

  Future<void> recordAppError({
    required String severity,
    required String context,
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object?> rawPayload = const {},
  }) async {
    if (!isConfigured) return;
    await bootstrap();
    if (_auth.currentSession == null) return;
    try {
      await client!.rpc(
        'record_app_error',
        params: {
          'severity': severity,
          'context': context,
          'message': error.toString(),
          'stack_trace': stackTrace?.toString(),
          'app_version': null,
          'platform': defaultTargetPlatform.name,
          'raw_payload': rawPayload,
        },
      ).timeout(_networkTimeout);
    } on Object {
      return;
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    if (!isConfigured) return;
    await bootstrap();
    try {
      await _auth
          .signInWithPassword(
            email: email.trim().toLowerCase(),
            password: password,
          )
          .timeout(_networkTimeout);
      _message = null;
      notifyListeners();
    } on AuthException catch (e) {
      throw StateError(_authMessage(e));
    } on TimeoutException {
      throw StateError(
          'Connection timed out. Check your internet and try again.');
    }
  }

  Future<void> signOut() async {
    if (!isConfigured || !Supabase.instance.isInitialized) return;
    await _auth.signOut();
    notifyListeners();
  }

  Future<void> changePassword(String newPassword) async {
    if (!isConfigured) return;
    await bootstrap();
    if (_auth.currentSession == null) {
      throw StateError('Sign in again before changing your cloud password.');
    }
    try {
      await _auth
          .updateUser(UserAttributes(password: newPassword))
          .timeout(_networkTimeout);
    } on AuthException catch (e) {
      throw StateError(_authMessage(e));
    } on TimeoutException {
      throw StateError(
          'Connection timed out. Check your internet and try again.');
    }
  }

  Future<void> deleteCurrentUserAndBackups() async {
    if (!isConfigured) return;
    await bootstrap();
    final supabaseClient = client;
    if (supabaseClient == null || _auth.currentSession == null) return;

    final userId = supabaseClient.auth.currentUser?.id;
    if (userId != null && userId.trim().isNotEmpty) {
      try {
        await supabaseClient.storage.from(cloudBackupBucket).remove([
          '${cloudBackupPathPrefix.trim()}/$userId/carwash_manager.db',
          '${cloudBackupPathPrefix.trim()}/$userId/metadata.json',
        ]);
      } on StorageException {
        // The database RPC below also removes backup objects. Storage cleanup
        // failures here should not block account deletion.
      }
    }

    try {
      await supabaseClient.rpc('delete_current_user').timeout(_networkTimeout);
    } on PostgrestException catch (e) {
      throw StateError(
        e.message.trim().isEmpty ? 'Cloud account deletion failed.' : e.message,
      );
    } on TimeoutException {
      throw StateError(
          'Connection timed out. Check your internet and try again.');
    }
    try {
      await supabaseClient.auth.signOut();
    } on AuthException {
      // The auth user has already been removed; clearing the local app database
      // completes the sign-out state for the user.
    }
    notifyListeners();
  }

  GoTrueClient get _auth {
    final supabaseClient = client;
    if (supabaseClient == null) {
      throw StateError('Supabase is not configured for this build.');
    }
    return supabaseClient.auth;
  }

  bool _isAlreadyRegistered(AuthException e) {
    final text = _authMessage(e).toLowerCase();
    return text.contains('already registered') ||
        text.contains('already exists') ||
        text.contains('user already');
  }

  String _authMessage(AuthException e) {
    return e.message.trim().isEmpty
        ? 'Supabase authentication failed.'
        : e.message;
  }

  CloudAccessState? _cloudState(Object? response) {
    if (response is Map<String, dynamic>) {
      return CloudAccessState.fromJson(response);
    }
    if (response is Map) {
      return CloudAccessState.fromJson(Map<String, dynamic>.from(response));
    }
    return null;
  }
}
