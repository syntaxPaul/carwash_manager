import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../models/loyalty_summary.dart';

class LoyaltyService {
  LoyaltyService._();
  static final LoyaltyService instance = LoyaltyService._();

  Future<void> recordPunchForBooking(Map<String, Object?> bookingRow) async {
    final customerId = bookingRow['customer_id'] as String?;
    final carwashId = bookingRow['carwash_id'] as String?;
    if (customerId == null || carwashId == null) return;
    final bookingId = bookingRow['id'] as String;
    final db = await AppDb.instance.db;
    final existing = await db.query(
      'loyalty_punches',
      where: 'booking_id = ?',
      whereArgs: [bookingId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert('loyalty_punches', {
      'id': const Uuid().v4(),
      'booking_id': bookingId,
      'customer_id': customerId,
      'carwash_id': carwashId,
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
    final available = punches ~/ 5 - redemptions;
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
    final rows = await db.rawQuery(
      '''
      WITH redeemed AS (
        SELECT customer_id, carwash_id, COUNT(*) AS redemptions
        FROM loyalty_redemptions
        GROUP BY customer_id, carwash_id
      )
      SELECT cu.id AS customer_id,
             cu.name AS customer_name,
             cu.phone AS customer_phone,
             c.id AS carwash_id,
             c.name AS carwash_name,
             COUNT(lp.id) AS punches,
             MAX(lp.ts) AS last_ts,
             COALESCE(redeemed.redemptions, 0) AS redemptions
      FROM loyalty_punches lp
      JOIN customers cu ON cu.id = lp.customer_id
      JOIN carwashes c ON c.id = lp.carwash_id
      LEFT JOIN redeemed ON redeemed.customer_id = cu.id AND redeemed.carwash_id = c.id
      GROUP BY cu.id, customer_name, customer_phone, c.id, carwash_name, redemptions
      ORDER BY last_ts DESC
      ''',
    );
    return rows;
  }
}
