import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../models/vehicle.dart';

class VehicleService {
  VehicleService._();
  static final VehicleService instance = VehicleService._();

  Future<List<Vehicle>> forCustomer(String customerId) async {
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'vehicles',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_ts DESC',
    );
    return rows
        .map(
          (r) => Vehicle(
            id: r['id'] as String,
            customerId: r['customer_id'] as String,
            make: r['make'] as String?,
            model: r['model'] as String?,
            year: r['year'] as int?,
            licensePlate: r['license_plate'] as String?,
            color: r['color'] as String?,
            preferredService: r['preferred_service'] as String?,
            carwashId: r['carwash_id'] as String?,
          ),
        )
        .toList();
  }

  Future<Vehicle> upsert({
    String? id,
    required String customerId,
    String? make,
    String? model,
    int? year,
    String? licensePlate,
    String? color,
    String? preferredService,
    String? carwashId,
  }) async {
    final db = await AppDb.instance.db;
    final vehicleId = id ?? const Uuid().v4();
    await db.insert(
      'vehicles',
      {
        'id': vehicleId,
        'customer_id': customerId,
        'make': make,
        'model': model,
        'year': year,
        'license_plate': licensePlate,
        'color': color,
        'preferred_service': preferredService,
        'carwash_id': carwashId,
        'created_ts': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return Vehicle(
      id: vehicleId,
      customerId: customerId,
      make: make,
      model: model,
      year: year,
      licensePlate: licensePlate,
      color: color,
      preferredService: preferredService,
      carwashId: carwashId,
    );
  }

  Future<void> remove(String id) async {
    final db = await AppDb.instance.db;
    await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }
}
