import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../models/customer.dart';

class CustomerAuth extends ChangeNotifier {
  static const String _demoPhone = '0659071466';
  static const String _demoPin = '1234';
  static const String _demoCustomerId = 'cw_demo_customer';
  static const String _demoCustomerName = 'Demo Customer';

  CustomerAuth._();
  static final CustomerAuth instance = CustomerAuth._();

  final ValueNotifier<Customer?> _notifier = ValueNotifier<Customer?>(null);
  ValueListenable<Customer?> get listenable => _notifier;

  Customer? get current => _notifier.value;
  bool _bootstrapped = false;

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    final db = await AppDb.instance.db;
    await _ensureDemoCustomer(db);
    Customer? customer;
    try {
      final rows = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: ['customer_session'],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final id = rows.first['value'] as String;
        customer = await _loadCustomerById(db, id);
      }
    } finally {
      _bootstrapped = true;
      _setCurrent(customer);
      if (customer == null) {
        await _clearSession(db);
      }
    }
  }

  Future<Customer?> _loadCustomerById(DatabaseExecutor db, String id) async {
    final rows = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  Future<Customer> register({
    required String name,
    required String phone,
    String? email,
    required String pin,
  }) async {
    final db = await AppDb.instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleanedPhone = phone.trim();
    final existing = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [cleanedPhone],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw StateError('Phone number already registered.');
    }
    final id = const Uuid().v4();
    final pinHash = _hashPin(pin);
    final normalizedEmail =
        email == null || email.trim().isEmpty ? null : email.trim();
    final row = {
      'id': id,
      'name': name.trim(),
      'phone': cleanedPhone,
      'email': normalizedEmail,
      'pin_hash': pinHash,
      'created_ts': now,
    };
    await db.insert('customers', row);
    final customer = Customer.fromMap(row);
    await _persistSession(db, id);
    _setCurrent(customer);
    return customer;
  }

  Future<Customer> login({
    required String phone,
    required String pin,
  }) async {
    final db = await AppDb.instance.db;
    await _ensureDemoCustomer(db);
    final rows = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [phone.trim()],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Account not found for that phone number.');
    }
    final row = rows.first;
    final storedHash = row['pin_hash'] as String;
    if (storedHash != _hashPin(pin)) {
      throw StateError('Incorrect PIN.');
    }
    final customer = Customer.fromMap(row);
    await _persistSession(db, customer.id);
    _setCurrent(customer);
    return customer;
  }

  Future<void> logout() async {
    final db = await AppDb.instance.db;
    await _clearSession(db);
    _setCurrent(null);
  }

  Future<void> _persistSession(DatabaseExecutor db, String id) async {
    await db.insert(
      'settings',
      {'key': 'customer_session', 'value': id},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> _clearSession(DatabaseExecutor db) async {
    await db.delete(
      'settings',
      where: 'key = ?',
      whereArgs: ['customer_session'],
    );
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    return sha256.convert(bytes).toString();
  }

  Future<void> _ensureDemoCustomer(DatabaseExecutor db) async {
    final rows = await db.query(
      'customers',
      where: 'phone = ?',
      whereArgs: [_demoPhone],
      limit: 1,
    );
    if (rows.isNotEmpty) return;
    final row = {
      'id': _demoCustomerId,
      'name': _demoCustomerName,
      'phone': _demoPhone,
      'email': null,
      'pin_hash': _hashPin(_demoPin),
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    };
    await db.insert(
      'customers',
      row,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  void _setCurrent(Customer? customer) {
    _notifier.value = customer;
    notifyListeners();
  }
}
