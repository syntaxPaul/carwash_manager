import 'package:sqflite/sqflite.dart';

/// Generates a human-friendly booking code that stays unique per carwash.
Future<String> generateBookingCode(
  DatabaseExecutor db, {
  required String carwashId,
  required String carwashCode,
}) async {
  final key = 'booking_seq_$carwashId';
  final rows = await db.query(
    'settings',
    columns: ['value'],
    where: 'key = ?',
    whereArgs: [key],
    limit: 1,
  );
  final current = rows.isEmpty
      ? 0
      : int.tryParse((rows.first['value'] as String?) ?? '') ?? 0;
  final next = current + 1;
  await db.insert(
    'settings',
    {'key': key, 'value': next.toString()},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  return '$carwashCode-${next.toString().padLeft(4, '0')}';
}
