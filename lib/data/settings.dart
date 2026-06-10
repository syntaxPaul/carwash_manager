import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'db.dart';

class AppSettings {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  // Backing fields with sensible defaults for South Africa context
  String businessName = 'My Car Wash';
  String vatReg = '';
  double taxRate = 0.15; // 15%
  bool pricesIncludeVat = true;
  String currencySymbol = 'R';
  bool autoClassifyExpenses = true;
  bool autoPostTransactions = true;
  bool autoMarkOverdue = true;
  bool autoGenerateMonthlyClose = true;

  final _loaded = ValueNotifier<bool>(false);
  ValueListenable<bool> get isLoaded => _loaded;

  Future<void> load() async {
    _resetValues();
    try {
      final d = await AppDb.instance.db;
      final rows = await d.query('settings');
      for (final r in rows) {
        _applyPair(r['key'] as String, r['value'] as String);
      }
    } catch (_) {
      // Table will exist via migration; ignore if first launch before migration runs.
    } finally {
      _loaded.value = true;
    }
  }

  void resetToDefaults() {
    _resetValues();
    _loaded.value = true;
  }

  void _resetValues() {
    businessName = 'My Car Wash';
    vatReg = '';
    taxRate = 0.15;
    pricesIncludeVat = true;
    currencySymbol = 'R';
    autoClassifyExpenses = true;
    autoPostTransactions = true;
    autoMarkOverdue = true;
    autoGenerateMonthlyClose = true;
  }

  void _applyPair(String key, String value) {
    switch (key) {
      case 'business_name':
        businessName = value;
        break;
      case 'vat_reg':
        vatReg = value;
        break;
      case 'tax_rate':
        taxRate = double.tryParse(value) ?? taxRate;
        break;
      case 'prices_include_vat':
        pricesIncludeVat = value == '1' || value.toLowerCase() == 'true';
        break;
      case 'currency_symbol':
        currencySymbol = value;
        break;
      case 'auto_classify_expenses':
        autoClassifyExpenses = value == '1' || value.toLowerCase() == 'true';
        break;
      case 'auto_post_transactions':
        autoPostTransactions = value == '1' || value.toLowerCase() == 'true';
        break;
      case 'auto_mark_overdue':
        autoMarkOverdue = value == '1' || value.toLowerCase() == 'true';
        break;
      case 'auto_generate_monthly_close':
        autoGenerateMonthlyClose =
            value == '1' || value.toLowerCase() == 'true';
        break;
    }
  }

  Future<void> saveAll() async {
    final d = await AppDb.instance.db;
    final batch = d.batch();
    void upsert(String key, String value) {
      batch.insert(
        'settings',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    upsert('business_name', businessName);
    upsert('vat_reg', vatReg);
    upsert('tax_rate', taxRate.toString());
    upsert('prices_include_vat', pricesIncludeVat ? '1' : '0');
    upsert('currency_symbol', currencySymbol);
    upsert('auto_classify_expenses', autoClassifyExpenses ? '1' : '0');
    upsert('auto_post_transactions', autoPostTransactions ? '1' : '0');
    upsert('auto_mark_overdue', autoMarkOverdue ? '1' : '0');
    upsert('auto_generate_monthly_close', autoGenerateMonthlyClose ? '1' : '0');
    await batch.commit(noResult: true);
  }
}
