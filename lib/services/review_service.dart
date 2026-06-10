import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';

class ReviewService {
  ReviewService._();
  static final ReviewService instance = ReviewService._();

  Future<List<Map<String, Object?>>> reviewsForCarwash(
    String carwashId, {
    int limit = 25,
  }) async {
    final db = await AppDb.instance.db;
    return db.query(
      'reviews',
      where: 'carwash_id = ?',
      whereArgs: [carwashId],
      orderBy: 'ts DESC',
      limit: limit,
    );
  }

  Future<Map<String, Object?>> summaryForCarwash(String carwashId) async {
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) AS count, AVG(rating) AS avg
      FROM reviews
      WHERE carwash_id = ?
      ''',
      [carwashId],
    );
    if (rows.isEmpty) return {'count': 0, 'avg': null};
    final row = rows.first;
    return {
      'count': (row['count'] as num?)?.toInt() ?? 0,
      'avg': (row['avg'] as num?)?.toDouble(),
    };
  }

  Future<void> addReview({
    required String carwashId,
    required int rating,
    String? comment,
    String? customerId,
    String? customerName,
  }) async {
    final db = await AppDb.instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final normalizedComment =
        (comment != null && comment.trim().isNotEmpty) ? comment.trim() : null;
    await db.insert(
      'reviews',
      {
        'id': const Uuid().v4(),
        'carwash_id': carwashId,
        'customer_id': customerId,
        'customer_name': customerName,
        'rating': rating.clamp(1, 5),
        'comment': normalizedComment,
        'ts': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
