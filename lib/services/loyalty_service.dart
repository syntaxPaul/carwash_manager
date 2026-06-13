import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../data/settings.dart';
import '../models/loyalty_summary.dart';

class PlateLoyaltyStatus {
  final String plateKey;
  final String displayPlate;
  final int punches;
  final int redemptions;
  final int washesPerReward;

  const PlateLoyaltyStatus({
    required this.plateKey,
    required this.displayPlate,
    required this.punches,
    required this.redemptions,
    required this.washesPerReward,
  });

  int get unlockedRewards => punches ~/ washesPerReward;
  int get availableRewards {
    final value = unlockedRewards - redemptions;
    return value < 0 ? 0 : value;
  }

  int get punchesTowardReward => punches % washesPerReward;

  String get label {
    if (availableRewards == 1) return '1 free wash available';
    if (availableRewards > 1) return '$availableRewards free washes available';
    return '$punchesTowardReward/$washesPerReward washes';
  }
}

class LoyaltyService {
  LoyaltyService._();
  static final LoyaltyService instance = LoyaltyService._();

  Future<void> recordPunchForBooking(Map<String, Object?> bookingRow) async {
    final carwashId = bookingRow['carwash_id'] as String?;
    final displayPlate = _displayPlate(bookingRow['license_plate']);
    final plateKey = _plateKey(displayPlate);
    if (plateKey == null || carwashId == null) return;
    final bookingId = bookingRow['id'] as String;
    final db = await AppDb.instance.db;
    await _ensurePlateSchema(db);
    final existing = await db.query(
      'loyalty_punches',
      where: 'booking_id = ?',
      whereArgs: [bookingId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final customerId = await _plateCustomerId(db, plateKey, displayPlate);
    await db.insert('loyalty_punches', {
      'id': const Uuid().v4(),
      'booking_id': bookingId,
      'customer_id': customerId,
      'carwash_id': carwashId,
      'plate_key': plateKey,
      'display_plate': displayPlate,
      'ts': bookingRow['appt_ts'] as int? ??
          DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<LoyaltySummary>> summariesForCustomer(String customerId) async {
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
      SELECT c.id AS carwash_id,
             c.name AS carwash_name,
             COUNT(lp.id) AS punches,
             MAX(lp.ts) AS last_ts,
             COALESCE(red.redeemed, 0) AS redeemed
      FROM loyalty_punches lp
      JOIN carwashes c ON c.id = lp.carwash_id
      LEFT JOIN (
        SELECT carwash_id, COUNT(*) AS redeemed
        FROM loyalty_redemptions
        WHERE customer_id = ?
        GROUP BY carwash_id
      ) red ON red.carwash_id = c.id
      WHERE lp.customer_id = ?
      GROUP BY c.id, c.name, red.redeemed
      ORDER BY last_ts DESC
      ''',
      [customerId, customerId],
    );
    return rows
        .map(
          (row) => LoyaltySummary(
            carwashId: row['carwash_id'] as String,
            carwashName: row['carwash_name'] as String,
            punches: (row['punches'] as num).toInt(),
            redemptions: (row['redeemed'] as num).toInt(),
            lastTs: (row['last_ts'] as int?) ?? 0,
          ),
        )
        .toList(growable: false);
  }

  Future<void> redeemFreeWash({
    required String customerId,
    required String carwashId,
    String? notes,
  }) async {
    final db = await AppDb.instance.db;
    final punches = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_punches WHERE customer_id = ? AND carwash_id = ?',
          [customerId, carwashId],
        )) ??
        0;
    final redemptions = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_redemptions WHERE customer_id = ? AND carwash_id = ?',
          [customerId, carwashId],
        )) ??
        0;
    final available = punches ~/ _washesPerReward - redemptions;
    if (available <= 0) {
      throw StateError('No free washes available to redeem.');
    }
    await db.insert('loyalty_redemptions', {
      'id': const Uuid().v4(),
      'customer_id': customerId,
      'carwash_id': carwashId,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'notes': notes,
    });
  }

  Future<void> redeemFreeWashForPlate({
    required String plateKey,
    required String displayPlate,
    required String carwashId,
    String? notes,
  }) async {
    final db = await AppDb.instance.db;
    await _ensurePlateSchema(db);
    final normalizedPlateKey = _plateKey(plateKey);
    if (normalizedPlateKey == null) {
      throw StateError('No number plate supplied.');
    }

    final punches = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_punches WHERE plate_key = ? AND carwash_id = ?',
          [normalizedPlateKey, carwashId],
        )) ??
        0;
    final redemptions = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_redemptions WHERE plate_key = ? AND carwash_id = ?',
          [normalizedPlateKey, carwashId],
        )) ??
        0;
    final available = punches ~/ _washesPerReward - redemptions;
    if (available <= 0) {
      throw StateError('No free washes available to redeem.');
    }

    final customerId = await _plateCustomerId(
      db,
      normalizedPlateKey,
      displayPlate.trim().isEmpty ? normalizedPlateKey : displayPlate,
    );
    await db.insert('loyalty_redemptions', {
      'id': const Uuid().v4(),
      'customer_id': customerId,
      'carwash_id': carwashId,
      'plate_key': normalizedPlateKey,
      'display_plate': displayPlate.trim().isEmpty
          ? normalizedPlateKey
          : displayPlate.trim().toUpperCase(),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'notes': notes,
    });
  }

  Future<PlateLoyaltyStatus?> plateStatus({
    required String plate,
    required String carwashId,
  }) async {
    final plateKey = _plateKey(plate);
    if (plateKey == null) return null;
    final db = await AppDb.instance.db;
    await _ensurePlateSchema(db);

    final punches = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_punches WHERE plate_key = ? AND carwash_id = ?',
          [plateKey, carwashId],
        )) ??
        0;
    final redemptions = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM loyalty_redemptions WHERE plate_key = ? AND carwash_id = ?',
          [plateKey, carwashId],
        )) ??
        0;
    return PlateLoyaltyStatus(
      plateKey: plateKey,
      displayPlate: _displayPlate(plate),
      punches: punches,
      redemptions: redemptions,
      washesPerReward: _washesPerReward,
    );
  }

  Future<List<Map<String, Object?>>> managerLeaderboard() async {
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
      WITH redeemed AS (
        SELECT customer_id, COUNT(*) AS redemptions
        FROM loyalty_redemptions
        GROUP BY customer_id
      )
      SELECT cu.id AS customer_id,
             cu.name,
             cu.phone,
             COUNT(lp.id) AS punches,
             MAX(lp.ts) AS last_ts,
             COALESCE(redeemed.redemptions, 0) AS redemptions
      FROM loyalty_punches lp
      JOIN customers cu ON cu.id = lp.customer_id
      LEFT JOIN redeemed ON redeemed.customer_id = cu.id
      GROUP BY cu.id, cu.name, cu.phone, redeemed.redemptions
      ORDER BY punches DESC, last_ts DESC
      ''',
    );
    return rows;
  }

  Future<List<Map<String, Object?>>> managerCarwashBreakdown() async {
    final db = await AppDb.instance.db;
    await _ensurePlateSchema(db);
    final rows = await db.rawQuery(
      '''
      WITH redeemed AS (
        SELECT plate_key, carwash_id, COUNT(*) AS redemptions
        FROM loyalty_redemptions
        WHERE plate_key IS NOT NULL AND plate_key <> ''
        GROUP BY plate_key, carwash_id
      )
      SELECT lp.plate_key,
             COALESCE(MAX(lp.display_plate), lp.plate_key) AS display_plate,
             c.id AS carwash_id,
             c.name AS carwash_name,
             COUNT(lp.id) AS punches,
             MAX(lp.ts) AS last_ts,
             COALESCE(redeemed.redemptions, 0) AS redemptions
      FROM loyalty_punches lp
      JOIN carwashes c ON c.id = lp.carwash_id
      LEFT JOIN redeemed ON redeemed.plate_key = lp.plate_key AND redeemed.carwash_id = c.id
      WHERE lp.plate_key IS NOT NULL AND lp.plate_key <> ''
      GROUP BY lp.plate_key, c.id, carwash_name, redemptions
      ORDER BY last_ts DESC
      ''',
    );
    return rows;
  }

  Future<void> _ensurePlateSchema(DatabaseExecutor db) async {
    for (final table in const ['loyalty_punches', 'loyalty_redemptions']) {
      for (final column in const ['plate_key', 'display_plate']) {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN $column TEXT;');
        } on DatabaseException catch (e) {
          if (!e.toString().toLowerCase().contains('duplicate column name')) {
            rethrow;
          }
        }
      }
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_plate ON loyalty_punches(plate_key, carwash_id);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_loyalty_redemptions_plate ON loyalty_redemptions(plate_key, carwash_id);',
    );
  }

  Future<String> _plateCustomerId(
    DatabaseExecutor db,
    String plateKey,
    String displayPlate,
  ) async {
    final syntheticPhone = 'plate:$plateKey';
    final rows = await db.query(
      'customers',
      columns: ['id'],
      where: 'phone = ?',
      whereArgs: [syntheticPhone],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;

    final id = const Uuid().v4();
    await db.insert('customers', {
      'id': id,
      'name': displayPlate.trim().isEmpty
          ? 'Vehicle $plateKey'
          : displayPlate.trim().toUpperCase(),
      'phone': syntheticPhone,
      'email': null,
      'pin_hash': 'plate-loyalty',
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  String _displayPlate(Object? value) =>
      (value?.toString() ?? '').trim().toUpperCase();

  String? _plateKey(Object? value) {
    final normalized = (value?.toString() ?? '')
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return normalized.isEmpty ? null : normalized;
  }

  int get _washesPerReward => AppSettings.instance.loyaltyWashesPerReward;
}
