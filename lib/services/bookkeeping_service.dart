import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../data/db.dart';
import '../data/settings.dart';

class BookkeepingService {
  BookkeepingService._();
  static final BookkeepingService instance = BookkeepingService._();

  static const String cashAccountCode = '1000';
  static const String bankAccountCode = '1010';
  static const String receivableAccountCode = '1100';
  static const String vatInputAccountCode = '1200';
  static const String payableAccountCode = '2000';
  static const String vatOutputAccountCode = '2100';
  static const String washSalesAccountCode = '4000';
  static const String generalExpenseAccountCode = '5090';

  final Uuid _uuid = const Uuid();
  final DateFormat _ymd = DateFormat('yyyy-MM-dd');
  final DateFormat _compact = DateFormat('yyyyMMdd');
  final DateFormat _yyyMm = DateFormat('yyyy-MM');

  bool _bootstrapped = false;
  bool _automationRunning = false;
  Map<String, int> _lastAutomationSummary = const {};

  Future<void> bootstrap() async {
    if (_bootstrapped) return;
    final db = await AppDb.instance.db;
    await db.transaction((txn) async {
      await _ensureCoreData(txn);
    });
    await runAutomation(force: true);
    _bootstrapped = true;
  }

  Future<void> postWash(
      DatabaseExecutor db, Map<String, Object?> washRow) async {
    await _ensureCoreData(db);
    final washId = washRow['id'] as String?;
    if (washId == null) return;

    final linkedEntryId = (washRow['ledger_entry_id'] as String?)?.trim();
    if (linkedEntryId != null && linkedEntryId.isNotEmpty) return;

    final existing =
        await _entryForSource(db, sourceType: 'wash', sourceId: washId);
    if (existing != null) {
      await db.update(
        'washes',
        {'ledger_entry_id': existing},
        where: 'id = ?',
        whereArgs: [washId],
      );
      return;
    }

    final amount = _round2((washRow['price'] as num?)?.toDouble() ?? 0);
    if (amount <= 0) return;

    final ts = (washRow['ts'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final paymentMethod = (washRow['payment_method'] as String?) ?? 'cash';
    final serviceName = (washRow['service_name'] as String?) ?? 'Wash sale';
    final split = _splitFromGross(amount,
        includeVat: AppSettings.instance.pricesIncludeVat);
    final accountIds = await _accountIdsByCode(db);
    final paymentAccount = accountIds[_paymentAccountCode(paymentMethod)] ??
        accountIds[cashAccountCode]!;

    final lines = <_PostingLine>[
      _PostingLine(
        accountId: paymentAccount,
        debit: split.total,
        credit: 0,
        memo: '$paymentMethod receipt',
      ),
      _PostingLine(
        accountId: accountIds[washSalesAccountCode]!,
        debit: 0,
        credit: split.net,
        memo: serviceName,
      ),
      if (split.tax > 0)
        _PostingLine(
          accountId: accountIds[vatOutputAccountCode]!,
          debit: 0,
          credit: split.tax,
          memo: 'Output VAT',
        ),
    ];

    final entryId = await _createEntry(
      db,
      txnTs: ts,
      description: 'Wash sale: $serviceName',
      sourceType: 'wash',
      sourceId: washId,
      lines: lines,
    );

    await db.update(
      'washes',
      {'ledger_entry_id': entryId},
      where: 'id = ?',
      whereArgs: [washId],
    );

    await _insertCashMovement(
      db,
      ts: ts,
      direction: 'in',
      amount: split.total,
      method: paymentMethod,
      description: 'Wash sale: $serviceName',
      sourceType: 'wash',
      sourceId: washId,
    );
  }

  Future<void> postExpense(
      DatabaseExecutor db, Map<String, Object?> expenseRow) async {
    await _ensureCoreData(db);
    final expenseId = expenseRow['id'] as String?;
    if (expenseId == null) return;

    final linkedEntryId = (expenseRow['ledger_entry_id'] as String?)?.trim();
    if (linkedEntryId != null && linkedEntryId.isNotEmpty) return;

    final existing =
        await _entryForSource(db, sourceType: 'expense', sourceId: expenseId);
    if (existing != null) {
      await db.update(
        'expenses',
        {'ledger_entry_id': existing},
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      return;
    }

    final amount = _round2((expenseRow['amount'] as num?)?.toDouble() ?? 0);
    if (amount <= 0) return;

    final ts =
        (expenseRow['ts'] as int?) ?? DateTime.now().millisecondsSinceEpoch;
    final category = (expenseRow['category'] as String?) ?? 'General expense';
    final paymentMethod = (expenseRow['payment_method'] as String?) ?? 'cash';
    final paymentStatus = (expenseRow['payment_status'] as String?) ?? 'paid';
    final vendor = (expenseRow['vendor_name'] as String?)?.trim();
    final split = _splitFromGross(amount,
        includeVat: AppSettings.instance.pricesIncludeVat);
    final accountIds = await _accountIdsByCode(db);
    final expenseCode = _expenseAccountCodeForCategory(category);
    final expenseAccount =
        accountIds[expenseCode] ?? accountIds[generalExpenseAccountCode]!;
    final offsetAccount = paymentStatus == 'due'
        ? accountIds[payableAccountCode]!
        : accountIds[_paymentAccountCode(paymentMethod)] ??
            accountIds[cashAccountCode]!;

    final lines = <_PostingLine>[
      _PostingLine(
        accountId: expenseAccount,
        debit: split.net,
        credit: 0,
        memo: category,
      ),
      if (split.tax > 0)
        _PostingLine(
          accountId: accountIds[vatInputAccountCode]!,
          debit: split.tax,
          credit: 0,
          memo: 'Input VAT',
        ),
      _PostingLine(
        accountId: offsetAccount,
        debit: 0,
        credit: split.total,
        memo: paymentStatus == 'due' ? 'Accounts payable' : paymentMethod,
      ),
    ];

    final description = vendor == null || vendor.isEmpty
        ? 'Expense: $category'
        : 'Expense: $category ($vendor)';
    final entryId = await _createEntry(
      db,
      txnTs: ts,
      description: description,
      sourceType: 'expense',
      sourceId: expenseId,
      lines: lines,
    );

    await db.update(
      'expenses',
      {'ledger_entry_id': entryId},
      where: 'id = ?',
      whereArgs: [expenseId],
    );

    if (paymentStatus != 'due') {
      await _insertCashMovement(
        db,
        ts: ts,
        direction: 'out',
        amount: split.total,
        method: paymentMethod,
        description: description,
        sourceType: 'expense',
        sourceId: expenseId,
      );
    }
  }

  Future<String> createSalesInvoice({
    required String customerName,
    required String description,
    required double subtotal,
    double? taxRate,
    DateTime? issueDate,
    DateTime? dueDate,
    String? phone,
    String? email,
    String? notes,
  }) async {
    if (customerName.trim().isEmpty) {
      throw StateError('Customer name is required.');
    }
    if (subtotal <= 0) {
      throw StateError('Invoice subtotal must be greater than zero.');
    }

    final db = await AppDb.instance.db;
    final invoiceId = await db.transaction((txn) async {
      await _ensureCoreData(txn);
      final accountIds = await _accountIdsByCode(txn);
      final contactId = await _ensureContact(
        txn,
        name: customerName.trim(),
        type: 'customer',
        phone: phone,
        email: email,
      );

      final net = _round2(subtotal);
      final rate = _validRate(taxRate);
      final tax = _round2(net * rate);
      final total = _round2(net + tax);
      final issueTs = (issueDate ?? DateTime.now()).millisecondsSinceEpoch;
      final dueTs = dueDate?.millisecondsSinceEpoch;
      final invoiceId = _uuid.v4();
      final invoiceNo = _newDocNumber('INV');

      await txn.insert('sales_invoices', {
        'id': invoiceId,
        'invoice_no': invoiceNo,
        'contact_id': contactId,
        'issue_ts': issueTs,
        'due_ts': dueTs,
        'status': 'sent',
        'subtotal': net,
        'tax': tax,
        'total': total,
        'balance': total,
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      });

      await txn.insert('sales_invoice_lines', {
        'id': _uuid.v4(),
        'invoice_id': invoiceId,
        'description': description.trim(),
        'qty': 1.0,
        'unit_price': net,
        'tax_rate': rate,
        'line_total': total,
      });

      final entryId = await _createEntry(
        txn,
        txnTs: issueTs,
        description: 'Invoice $invoiceNo',
        sourceType: 'invoice',
        sourceId: invoiceId,
        lines: [
          _PostingLine(
            accountId: accountIds[receivableAccountCode]!,
            debit: total,
            credit: 0,
            memo: invoiceNo,
          ),
          _PostingLine(
            accountId: accountIds[washSalesAccountCode]!,
            debit: 0,
            credit: net,
            memo: description.trim(),
          ),
          if (tax > 0)
            _PostingLine(
              accountId: accountIds[vatOutputAccountCode]!,
              debit: 0,
              credit: tax,
              memo: 'Output VAT',
            ),
        ],
      );

      await txn.update(
        'sales_invoices',
        {'ledger_entry_id': entryId},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      return invoiceId;
    });
    await runAutomation();
    return invoiceId;
  }

  Future<String> createVendorBill({
    required String vendorName,
    required String description,
    required String category,
    required double subtotal,
    double? taxRate,
    DateTime? issueDate,
    DateTime? dueDate,
    String? phone,
    String? email,
    String? notes,
  }) async {
    if (vendorName.trim().isEmpty) {
      throw StateError('Vendor name is required.');
    }
    if (subtotal <= 0) {
      throw StateError('Bill subtotal must be greater than zero.');
    }

    final db = await AppDb.instance.db;
    final billId = await db.transaction((txn) async {
      await _ensureCoreData(txn);
      final accountIds = await _accountIdsByCode(txn);
      final contactId = await _ensureContact(
        txn,
        name: vendorName.trim(),
        type: 'vendor',
        phone: phone,
        email: email,
      );

      final net = _round2(subtotal);
      final rate = _validRate(taxRate);
      final tax = _round2(net * rate);
      final total = _round2(net + tax);
      final issueTs = (issueDate ?? DateTime.now()).millisecondsSinceEpoch;
      final dueTs = dueDate?.millisecondsSinceEpoch;
      final billId = _uuid.v4();
      final billNo = _newDocNumber('BILL');
      final expenseCode = _expenseAccountCodeForCategory(category);
      final expenseAccount =
          accountIds[expenseCode] ?? accountIds[generalExpenseAccountCode]!;

      await txn.insert('vendor_bills', {
        'id': billId,
        'bill_no': billNo,
        'contact_id': contactId,
        'issue_ts': issueTs,
        'due_ts': dueTs,
        'status': 'open',
        'subtotal': net,
        'tax': tax,
        'total': total,
        'balance': total,
        'notes': notes?.trim().isEmpty ?? true ? null : notes!.trim(),
      });

      await txn.insert('vendor_bill_lines', {
        'id': _uuid.v4(),
        'bill_id': billId,
        'account_id': expenseAccount,
        'description': description.trim(),
        'qty': 1.0,
        'unit_cost': net,
        'tax_rate': rate,
        'line_total': total,
      });

      final entryId = await _createEntry(
        txn,
        txnTs: issueTs,
        description: 'Vendor bill $billNo',
        sourceType: 'bill',
        sourceId: billId,
        lines: [
          _PostingLine(
            accountId: expenseAccount,
            debit: net,
            credit: 0,
            memo: category,
          ),
          if (tax > 0)
            _PostingLine(
              accountId: accountIds[vatInputAccountCode]!,
              debit: tax,
              credit: 0,
              memo: 'Input VAT',
            ),
          _PostingLine(
            accountId: accountIds[payableAccountCode]!,
            debit: 0,
            credit: total,
            memo: billNo,
          ),
        ],
      );

      await txn.update(
        'vendor_bills',
        {'ledger_entry_id': entryId},
        where: 'id = ?',
        whereArgs: [billId],
      );

      return billId;
    });
    await runAutomation();
    return billId;
  }

  Future<String> receiveInvoicePayment({
    required String invoiceId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw StateError('Payment amount must be greater than zero.');
    }

    final db = await AppDb.instance.db;
    final paymentId = await db.transaction((txn) async {
      await _ensureCoreData(txn);
      final rows = await txn.query(
        'sales_invoices',
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Invoice not found.');
      final invoice = rows.first;
      final currentBalance =
          _round2((invoice['balance'] as num?)?.toDouble() ?? 0);
      if (currentBalance <= 0) throw StateError('Invoice is already settled.');

      final applied = _round2(math.min(amount, currentBalance));
      final newBalance = _round2(currentBalance - applied);
      final newStatus = newBalance <= 0 ? 'paid' : 'partially_paid';
      final paymentId = _uuid.v4();
      final paymentNo = _newDocNumber('PAY');
      final ts = DateTime.now().millisecondsSinceEpoch;

      await txn.insert('payments', {
        'id': paymentId,
        'payment_no': paymentNo,
        'ts': ts,
        'contact_id': invoice['contact_id'],
        'direction': 'in',
        'method': method,
        'amount': applied,
        'reference': reference,
        'notes': notes,
        'invoice_id': invoiceId,
      });

      await txn.update(
        'sales_invoices',
        {'balance': newBalance, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [invoiceId],
      );

      final accountIds = await _accountIdsByCode(txn);
      final paymentAccount = accountIds[_paymentAccountCode(method)] ??
          accountIds[cashAccountCode]!;
      final invoiceNo = (invoice['invoice_no'] as String?) ?? invoiceId;
      final entryId = await _createEntry(
        txn,
        txnTs: ts,
        description: 'Payment received: $invoiceNo',
        sourceType: 'payment',
        sourceId: paymentId,
        lines: [
          _PostingLine(
            accountId: paymentAccount,
            debit: applied,
            credit: 0,
            memo: method,
          ),
          _PostingLine(
            accountId: accountIds[receivableAccountCode]!,
            debit: 0,
            credit: applied,
            memo: invoiceNo,
          ),
        ],
      );

      await txn.update(
        'payments',
        {'ledger_entry_id': entryId},
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      await _insertCashMovement(
        txn,
        ts: ts,
        direction: 'in',
        amount: applied,
        method: method,
        description: 'Payment received: $invoiceNo',
        sourceType: 'payment',
        sourceId: paymentId,
      );

      return paymentId;
    });
    await runAutomation();
    return paymentId;
  }

  Future<String> payVendorBill({
    required String billId,
    required double amount,
    required String method,
    String? reference,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw StateError('Payment amount must be greater than zero.');
    }

    final db = await AppDb.instance.db;
    final paymentId = await db.transaction((txn) async {
      await _ensureCoreData(txn);
      final rows = await txn.query(
        'vendor_bills',
        where: 'id = ?',
        whereArgs: [billId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('Vendor bill not found.');
      final bill = rows.first;
      final currentBalance =
          _round2((bill['balance'] as num?)?.toDouble() ?? 0);
      if (currentBalance <= 0) {
        throw StateError('Vendor bill is already settled.');
      }

      final applied = _round2(math.min(amount, currentBalance));
      final newBalance = _round2(currentBalance - applied);
      final newStatus = newBalance <= 0 ? 'paid' : 'partially_paid';
      final paymentId = _uuid.v4();
      final paymentNo = _newDocNumber('PAY');
      final ts = DateTime.now().millisecondsSinceEpoch;

      await txn.insert('payments', {
        'id': paymentId,
        'payment_no': paymentNo,
        'ts': ts,
        'contact_id': bill['contact_id'],
        'direction': 'out',
        'method': method,
        'amount': applied,
        'reference': reference,
        'notes': notes,
        'bill_id': billId,
      });

      await txn.update(
        'vendor_bills',
        {'balance': newBalance, 'status': newStatus},
        where: 'id = ?',
        whereArgs: [billId],
      );

      final accountIds = await _accountIdsByCode(txn);
      final paymentAccount = accountIds[_paymentAccountCode(method)] ??
          accountIds[cashAccountCode]!;
      final billNo = (bill['bill_no'] as String?) ?? billId;
      final entryId = await _createEntry(
        txn,
        txnTs: ts,
        description: 'Bill payment: $billNo',
        sourceType: 'payment',
        sourceId: paymentId,
        lines: [
          _PostingLine(
            accountId: accountIds[payableAccountCode]!,
            debit: applied,
            credit: 0,
            memo: billNo,
          ),
          _PostingLine(
            accountId: paymentAccount,
            debit: 0,
            credit: applied,
            memo: method,
          ),
        ],
      );

      await txn.update(
        'payments',
        {'ledger_entry_id': entryId},
        where: 'id = ?',
        whereArgs: [paymentId],
      );

      await _insertCashMovement(
        txn,
        ts: ts,
        direction: 'out',
        amount: applied,
        method: method,
        description: 'Bill payment: $billNo',
        sourceType: 'payment',
        sourceId: paymentId,
      );

      return paymentId;
    });
    await runAutomation();
    return paymentId;
  }

  Future<String> postManualAdjustment({
    required String debitAccountId,
    required String creditAccountId,
    required double amount,
    required String description,
    DateTime? date,
    String? memo,
  }) async {
    if (amount <= 0) throw StateError('Amount must be greater than zero.');
    if (debitAccountId == creditAccountId) {
      throw StateError('Debit and credit accounts must be different.');
    }

    final db = await AppDb.instance.db;
    final entryId = await db.transaction((txn) async {
      await _ensureCoreData(txn);
      final ts = (date ?? DateTime.now()).millisecondsSinceEpoch;
      return _createEntry(
        txn,
        txnTs: ts,
        description: description.trim(),
        sourceType: 'manual',
        sourceId: _uuid.v4(),
        lines: [
          _PostingLine(
            accountId: debitAccountId,
            debit: _round2(amount),
            credit: 0,
            memo: memo,
          ),
          _PostingLine(
            accountId: creditAccountId,
            debit: 0,
            credit: _round2(amount),
            memo: memo,
          ),
        ],
      );
    });
    await runAutomation();
    return entryId;
  }

  Future<Map<String, double>> financialSnapshot() async {
    final db = await AppDb.instance.db;
    await _ensureCoreData(db);
    final cash = await _balanceForCode(db, cashAccountCode);
    final bank = await _balanceForCode(db, bankAccountCode);
    final receivables = await _balanceForCode(db, receivableAccountCode);
    final payables = await _balanceForCode(db, payableAccountCode);
    final vatOutput = await _balanceForCode(db, vatOutputAccountCode);
    final vatInput = await _balanceForCode(db, vatInputAccountCode);
    final ytdProfit = await _profitYtd(db);
    return {
      'cash': cash,
      'bank': bank,
      'receivables': receivables,
      'payables': payables,
      'vat_due': _round2(vatOutput - vatInput),
      'ytd_profit': ytdProfit,
    };
  }

  Future<List<Map<String, Object?>>> openInvoices() async {
    final db = await AppDb.instance.db;
    return db.rawQuery('''
      SELECT i.*, c.name AS contact_name
      FROM sales_invoices i
      LEFT JOIN accounting_contacts c ON c.id = i.contact_id
      WHERE i.status IN ('sent', 'partially_paid', 'overdue')
      ORDER BY COALESCE(i.due_ts, i.issue_ts) ASC
    ''');
  }

  Future<List<Map<String, Object?>>> openVendorBills() async {
    final db = await AppDb.instance.db;
    return db.rawQuery('''
      SELECT b.*, c.name AS contact_name
      FROM vendor_bills b
      LEFT JOIN accounting_contacts c ON c.id = b.contact_id
      WHERE b.status IN ('open', 'partially_paid', 'overdue')
      ORDER BY COALESCE(b.due_ts, b.issue_ts) ASC
    ''');
  }

  Future<List<Map<String, Object?>>> recentJournalEntries(
      {int limit = 30}) async {
    final db = await AppDb.instance.db;
    return db.rawQuery('''
      SELECT
        j.id,
        j.txn_ts,
        j.txn_date,
        j.description,
        j.source_type,
        j.source_id,
        IFNULL(SUM(l.debit), 0) AS amount
      FROM journal_entries j
      LEFT JOIN journal_lines l ON l.entry_id = j.id
      GROUP BY j.id
      ORDER BY j.txn_ts DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<List<Map<String, Object?>>> trialBalance() async {
    final db = await AppDb.instance.db;
    return db.rawQuery('''
      SELECT
        a.id,
        a.code,
        a.name,
        a.type,
        IFNULL(SUM(l.debit), 0) AS debit,
        IFNULL(SUM(l.credit), 0) AS credit
      FROM ledger_accounts a
      LEFT JOIN journal_lines l ON l.account_id = a.id
      GROUP BY a.id
      ORDER BY a.code ASC
    ''');
  }

  Future<List<Map<String, Object?>>> listLedgerAccounts() async {
    final db = await AppDb.instance.db;
    return db.query(
      'ledger_accounts',
      where: 'is_active = 1',
      orderBy: 'code ASC',
    );
  }

  Future<Map<String, int>> runAutomation({bool force = false}) async {
    if (_automationRunning && !force) return Map.of(_lastAutomationSummary);
    _automationRunning = true;
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    final summary = <String, int>{
      'classified_expenses': 0,
      'posted_transactions': 0,
      'status_updates': 0,
      'monthly_close_updates': 0,
      'ts': nowTs,
    };

    try {
      final db = await AppDb.instance.db;
      await db.transaction((txn) async {
        await _ensureCoreData(txn);
      });

      if (AppSettings.instance.autoClassifyExpenses) {
        summary['classified_expenses'] = await _autoClassifyExpenses(db);
      }
      if (AppSettings.instance.autoPostTransactions) {
        summary['posted_transactions'] =
            await _backfillOperationalDataWithCount(db);
      }
      if (AppSettings.instance.autoMarkOverdue) {
        summary['status_updates'] = await _autoSyncDocumentStatuses(db);
      }
      if (AppSettings.instance.autoGenerateMonthlyClose) {
        summary['monthly_close_updates'] =
            await _upsertMonthlyClosings(db, monthsBack: 12);
      }

      await _recordAutomationRun(db, summary);
      _lastAutomationSummary = Map.unmodifiable(summary);
      return summary;
    } finally {
      _automationRunning = false;
    }
  }

  Future<Map<String, Object?>> latestAutomationRun() async {
    final db = await AppDb.instance.db;
    final rows = await db.query(
      'automation_runs',
      orderBy: 'ts DESC',
      limit: 1,
    );
    if (rows.isEmpty) return const {};
    final row = rows.first;
    final parsed =
        (jsonDecode((row['summary_json'] as String?) ?? '{}') as Map).cast<String, dynamic>();
    return {
      'id': row['id'],
      'ts': row['ts'],
      ...parsed,
    };
  }

  Future<List<Map<String, Object?>>> monthlyCloseSnapshots(
      {int limit = 6}) async {
    final db = await AppDb.instance.db;
    return db.query(
      'monthly_closes',
      orderBy: 'yyyymm DESC',
      limit: limit,
    );
  }

  Future<int> _backfillOperationalDataWithCount(Database db) async {
    int posted = 0;
    final unpostedWashes = await db.query('washes',
        where: 'ledger_entry_id IS NULL', orderBy: 'ts ASC');
    for (final wash in unpostedWashes) {
      await db.transaction((txn) async {
        await postWash(txn, wash);
      });
      posted++;
    }

    final unpostedExpenses = await db.query('expenses',
        where: 'ledger_entry_id IS NULL', orderBy: 'ts ASC');
    for (final expense in unpostedExpenses) {
      await db.transaction((txn) async {
        await postExpense(txn, expense);
      });
      posted++;
    }
    return posted;
  }

  Future<void> _ensureCoreData(DatabaseExecutor db) async {
    await _ensureChartOfAccounts(db);
    await _ensureDefaultBankAccount(db);
    await _ensureAutomationSchema(db);
    await _ensureAutomationRules(db);
  }

  Future<void> _ensureChartOfAccounts(DatabaseExecutor db) async {
    final defaults = <Map<String, String>>[
      {
        'code': '1000',
        'name': 'Cash on Hand',
        'type': 'asset',
        'subtype': 'cash'
      },
      {
        'code': '1010',
        'name': 'Bank Account',
        'type': 'asset',
        'subtype': 'bank'
      },
      {
        'code': '1100',
        'name': 'Accounts Receivable',
        'type': 'asset',
        'subtype': 'receivable'
      },
      {
        'code': '1200',
        'name': 'VAT Input Recoverable',
        'type': 'asset',
        'subtype': 'tax'
      },
      {
        'code': '2000',
        'name': 'Accounts Payable',
        'type': 'liability',
        'subtype': 'payable'
      },
      {
        'code': '2100',
        'name': 'VAT Output Payable',
        'type': 'liability',
        'subtype': 'tax'
      },
      {
        'code': '3000',
        'name': 'Owner Equity',
        'type': 'equity',
        'subtype': 'equity'
      },
      {
        'code': '4000',
        'name': 'Wash Sales',
        'type': 'income',
        'subtype': 'operating'
      },
      {
        'code': '4100',
        'name': 'Other Income',
        'type': 'income',
        'subtype': 'other'
      },
      {
        'code': '5000',
        'name': 'Supplies Expense',
        'type': 'expense',
        'subtype': 'operating'
      },
      {
        'code': '5010',
        'name': 'Utilities Expense',
        'type': 'expense',
        'subtype': 'operating'
      },
      {
        'code': '5020',
        'name': 'Payroll Expense',
        'type': 'expense',
        'subtype': 'operating'
      },
      {
        'code': '5030',
        'name': 'Rent Expense',
        'type': 'expense',
        'subtype': 'operating'
      },
      {
        'code': '5090',
        'name': 'General Expense',
        'type': 'expense',
        'subtype': 'operating'
      },
    ];

    for (final item in defaults) {
      final code = item['code']!;
      final exists = await db.query(
        'ledger_accounts',
        columns: ['id'],
        where: 'code = ?',
        whereArgs: [code],
        limit: 1,
      );
      if (exists.isEmpty) {
        await db.insert('ledger_accounts', {
          'id': _uuid.v4(),
          'code': code,
          'name': item['name'],
          'type': item['type'],
          'subtype': item['subtype'],
          'is_active': 1,
          'is_system': 1,
          'created_ts': DateTime.now().millisecondsSinceEpoch,
        });
      } else {
        await db.update(
          'ledger_accounts',
          {
            'name': item['name'],
            'type': item['type'],
            'subtype': item['subtype'],
            'is_active': 1,
          },
          where: 'code = ?',
          whereArgs: [code],
        );
      }
    }
  }

  Future<void> _ensureDefaultBankAccount(DatabaseExecutor db) async {
    final existing = await db.query(
      'bank_accounts',
      where: 'is_default = 1',
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    await db.insert('bank_accounts', {
      'id': _uuid.v4(),
      'name': 'Main Bank Account',
      'account_no': null,
      'is_default': 1,
      'opening_balance': 0,
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> _ensureAutomationSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS automation_runs (
        id TEXT PRIMARY KEY,
        ts INTEGER NOT NULL,
        summary_json TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_automation_runs_ts ON automation_runs(ts DESC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expense_rules (
        id TEXT PRIMARY KEY,
        keyword TEXT NOT NULL UNIQUE,
        category TEXT NOT NULL,
        payment_method TEXT,
        priority INTEGER NOT NULL DEFAULT 100,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_ts INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_expense_rules_priority ON expense_rules(priority ASC)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS monthly_closes (
        id TEXT PRIMARY KEY,
        yyyymm TEXT NOT NULL UNIQUE,
        period_start_ts INTEGER NOT NULL,
        period_end_ts INTEGER NOT NULL,
        income REAL NOT NULL DEFAULT 0,
        expenses REAL NOT NULL DEFAULT 0,
        profit REAL NOT NULL DEFAULT 0,
        vat_output REAL NOT NULL DEFAULT 0,
        vat_input REAL NOT NULL DEFAULT 0,
        vat_due REAL NOT NULL DEFAULT 0,
        open_ar REAL NOT NULL DEFAULT 0,
        open_ap REAL NOT NULL DEFAULT 0,
        generated_ts INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_monthly_closes_period ON monthly_closes(yyyymm DESC)');
  }

  Future<void> _ensureAutomationRules(DatabaseExecutor db) async {
    final existing = await db.rawQuery(
      'SELECT COUNT(1) AS c FROM expense_rules WHERE is_active = 1',
    );
    final count = (existing.first['c'] as num?)?.toInt() ?? 0;
    if (count > 0) return;

    final defaults = <Map<String, Object?>>[
      {'keyword': 'rent', 'category': 'Rent', 'payment_method': 'bank', 'priority': 10},
      {'keyword': 'lease', 'category': 'Rent', 'payment_method': 'bank', 'priority': 11},
      {'keyword': 'salary', 'category': 'Payroll', 'payment_method': 'bank', 'priority': 20},
      {'keyword': 'wage', 'category': 'Payroll', 'payment_method': 'bank', 'priority': 21},
      {'keyword': 'payroll', 'category': 'Payroll', 'payment_method': 'bank', 'priority': 22},
      {'keyword': 'electric', 'category': 'Utilities', 'payment_method': 'bank', 'priority': 30},
      {'keyword': 'water', 'category': 'Utilities', 'payment_method': 'bank', 'priority': 31},
      {'keyword': 'utility', 'category': 'Utilities', 'payment_method': 'bank', 'priority': 32},
      {'keyword': 'soap', 'category': 'Supplies', 'payment_method': 'bank', 'priority': 40},
      {'keyword': 'chemical', 'category': 'Supplies', 'payment_method': 'bank', 'priority': 41},
      {'keyword': 'detergent', 'category': 'Supplies', 'payment_method': 'bank', 'priority': 42},
      {'keyword': 'supply', 'category': 'Supplies', 'payment_method': 'bank', 'priority': 43},
      {'keyword': 'fuel', 'category': 'General expense', 'payment_method': 'bank', 'priority': 50},
      {'keyword': 'maintenance', 'category': 'General expense', 'payment_method': 'bank', 'priority': 60},
      {'keyword': 'repair', 'category': 'General expense', 'payment_method': 'bank', 'priority': 61},
      {'keyword': 'advert', 'category': 'General expense', 'payment_method': 'bank', 'priority': 70},
      {'keyword': 'marketing', 'category': 'General expense', 'payment_method': 'bank', 'priority': 71},
    ];

    final nowTs = DateTime.now().millisecondsSinceEpoch;
    for (final item in defaults) {
      await db.insert(
        'expense_rules',
        {
          'id': _uuid.v4(),
          'keyword': item['keyword'],
          'category': item['category'],
          'payment_method': item['payment_method'],
          'priority': item['priority'],
          'is_active': 1,
          'created_ts': nowTs,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<String> _ensureContact(
    DatabaseExecutor db, {
    required String name,
    required String type,
    String? phone,
    String? email,
  }) async {
    final rows = await db.query(
      'accounting_contacts',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final existing = rows.first;
      final existingType = (existing['type'] as String?) ?? type;
      final mergedType = _mergeContactType(existingType, type);
      await db.update(
        'accounting_contacts',
        {
          'type': mergedType,
          'phone': (phone?.trim().isEmpty ?? true)
              ? existing['phone']
              : phone!.trim(),
          'email': (email?.trim().isEmpty ?? true)
              ? existing['email']
              : email!.trim(),
        },
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      return existing['id'] as String;
    }
    final id = _uuid.v4();
    await db.insert('accounting_contacts', {
      'id': id,
      'name': name,
      'type': type,
      'phone': phone?.trim().isEmpty ?? true ? null : phone!.trim(),
      'email': email?.trim().isEmpty ?? true ? null : email!.trim(),
      'tax_no': null,
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  String _mergeContactType(String existing, String incoming) {
    if (existing == incoming) return existing;
    return 'both';
  }

  Future<int> _autoClassifyExpenses(Database db) async {
    final rules = await db.query(
      'expense_rules',
      where: 'is_active = 1',
      orderBy: 'priority ASC',
    );
    if (rules.isEmpty) return 0;

    final rows = await db.query(
      'expenses',
      where: 'ledger_entry_id IS NULL',
      orderBy: 'ts ASC',
    );
    int updated = 0;
    for (final row in rows) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final oldCategory = (row['category'] as String?)?.trim() ?? '';
      final vendor = (row['vendor_name'] as String?)?.trim() ?? '';
      final notes = (row['notes'] as String?)?.trim() ?? '';
      final status = (row['payment_status'] as String?)?.trim() ?? '';
      final method = (row['payment_method'] as String?)?.trim() ?? '';
      final dueTs = row['due_ts'] as int?;

      final hasGenericCategory = oldCategory.isEmpty ||
          oldCategory.toLowerCase() == 'general expense' ||
          oldCategory.toLowerCase() == 'other';
      final haystack = '$vendor $notes $oldCategory'.toLowerCase();
      String? inferredCategory;
      String? inferredMethod;

      for (final rule in rules) {
        final keyword = (rule['keyword'] as String?)?.toLowerCase().trim() ?? '';
        if (keyword.isEmpty) continue;
        if (!haystack.contains(keyword)) continue;
        inferredCategory = rule['category'] as String?;
        inferredMethod = rule['payment_method'] as String?;
        break;
      }

      final patch = <String, Object?>{};
      if (hasGenericCategory && inferredCategory != null && inferredCategory.isNotEmpty) {
        patch['category'] = inferredCategory;
      }
      if (status.isEmpty) {
        patch['payment_status'] = dueTs == null ? 'paid' : 'due';
      }
      if (method.isEmpty) {
        patch['payment_method'] = inferredMethod ?? 'cash';
      }

      if (patch.isEmpty) continue;
      await db.update('expenses', patch, where: 'id = ?', whereArgs: [id]);
      updated++;
    }
    return updated;
  }

  Future<int> _autoSyncDocumentStatuses(Database db) async {
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    int updates = 0;

    final invoices = await db.query('sales_invoices');
    for (final invoice in invoices) {
      final id = invoice['id'] as String?;
      if (id == null) continue;
      final current = (invoice['status'] as String?) ?? 'sent';
      if (current == 'void') continue;
      final dueTs = invoice['due_ts'] as int?;
      final total = (invoice['total'] as num?)?.toDouble() ?? 0;
      final balance = _round2((invoice['balance'] as num?)?.toDouble() ?? 0);
      final target = balance <= 0
          ? 'paid'
          : (dueTs != null && dueTs < nowTs
              ? 'overdue'
              : (balance < _round2(total) ? 'partially_paid' : 'sent'));
      if (target == current) continue;
      await db.update(
        'sales_invoices',
        {'status': target},
        where: 'id = ?',
        whereArgs: [id],
      );
      updates++;
    }

    final bills = await db.query('vendor_bills');
    for (final bill in bills) {
      final id = bill['id'] as String?;
      if (id == null) continue;
      final current = (bill['status'] as String?) ?? 'open';
      if (current == 'void') continue;
      final dueTs = bill['due_ts'] as int?;
      final total = (bill['total'] as num?)?.toDouble() ?? 0;
      final balance = _round2((bill['balance'] as num?)?.toDouble() ?? 0);
      final target = balance <= 0
          ? 'paid'
          : (dueTs != null && dueTs < nowTs
              ? 'overdue'
              : (balance < _round2(total) ? 'partially_paid' : 'open'));
      if (target == current) continue;
      await db.update(
        'vendor_bills',
        {'status': target},
        where: 'id = ?',
        whereArgs: [id],
      );
      updates++;
    }

    return updates;
  }

  Future<int> _upsertMonthlyClosings(Database db, {int monthsBack = 12}) async {
    final now = DateTime.now();
    int updates = 0;
    for (int i = monthsBack; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final start = DateTime(month.year, month.month, 1).millisecondsSinceEpoch;
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59)
          .millisecondsSinceEpoch;
      final key = _yyyMm.format(month);

      final incomeRows = await db.rawQuery(
          'SELECT IFNULL(SUM(price), 0) AS s FROM washes WHERE ts BETWEEN ? AND ?',
          [start, end]);
      final expenseRows = await db.rawQuery(
          'SELECT IFNULL(SUM(amount), 0) AS s FROM expenses WHERE ts BETWEEN ? AND ?',
          [start, end]);

      final vatOutputRows = await db.rawQuery('''
        SELECT IFNULL(SUM(l.credit - l.debit), 0) AS s
        FROM journal_lines l
        INNER JOIN journal_entries j ON j.id = l.entry_id
        INNER JOIN ledger_accounts a ON a.id = l.account_id
        WHERE a.code = ? AND j.txn_ts BETWEEN ? AND ?
      ''', [vatOutputAccountCode, start, end]);
      final vatInputRows = await db.rawQuery('''
        SELECT IFNULL(SUM(l.debit - l.credit), 0) AS s
        FROM journal_lines l
        INNER JOIN journal_entries j ON j.id = l.entry_id
        INNER JOIN ledger_accounts a ON a.id = l.account_id
        WHERE a.code = ? AND j.txn_ts BETWEEN ? AND ?
      ''', [vatInputAccountCode, start, end]);

      final arRows = await db.rawQuery('''
        SELECT IFNULL(SUM(balance), 0) AS s
        FROM sales_invoices
        WHERE status IN ('sent', 'partially_paid', 'overdue')
          AND issue_ts <= ?
      ''', [end]);
      final apRows = await db.rawQuery('''
        SELECT IFNULL(SUM(balance), 0) AS s
        FROM vendor_bills
        WHERE status IN ('open', 'partially_paid', 'overdue')
          AND issue_ts <= ?
      ''', [end]);

      final income = _round2((incomeRows.first['s'] as num?)?.toDouble() ?? 0);
      final expenses =
          _round2((expenseRows.first['s'] as num?)?.toDouble() ?? 0);
      final vatOutput =
          _round2((vatOutputRows.first['s'] as num?)?.toDouble() ?? 0);
      final vatInput =
          _round2((vatInputRows.first['s'] as num?)?.toDouble() ?? 0);
      final openAr = _round2((arRows.first['s'] as num?)?.toDouble() ?? 0);
      final openAp = _round2((apRows.first['s'] as num?)?.toDouble() ?? 0);
      final profit = _round2(income - expenses);
      final vatDue = _round2(vatOutput - vatInput);

      final existing = await db.query(
        'monthly_closes',
        where: 'yyyymm = ?',
        whereArgs: [key],
        limit: 1,
      );

      final patch = <String, Object?>{
        'yyyymm': key,
        'period_start_ts': start,
        'period_end_ts': end,
        'income': income,
        'expenses': expenses,
        'profit': profit,
        'vat_output': vatOutput,
        'vat_input': vatInput,
        'vat_due': vatDue,
        'open_ar': openAr,
        'open_ap': openAp,
        'generated_ts': DateTime.now().millisecondsSinceEpoch,
      };

      if (existing.isEmpty) {
        await db.insert('monthly_closes', {
          'id': 'close-$key',
          ...patch,
        });
        updates++;
      } else {
        final row = existing.first;
        final unchanged = _round2((row['income'] as num?)?.toDouble() ?? 0) == income &&
            _round2((row['expenses'] as num?)?.toDouble() ?? 0) == expenses &&
            _round2((row['profit'] as num?)?.toDouble() ?? 0) == profit &&
            _round2((row['vat_output'] as num?)?.toDouble() ?? 0) == vatOutput &&
            _round2((row['vat_input'] as num?)?.toDouble() ?? 0) == vatInput &&
            _round2((row['vat_due'] as num?)?.toDouble() ?? 0) == vatDue &&
            _round2((row['open_ar'] as num?)?.toDouble() ?? 0) == openAr &&
            _round2((row['open_ap'] as num?)?.toDouble() ?? 0) == openAp;
        if (unchanged) continue;
        await db.update(
          'monthly_closes',
          patch,
          where: 'yyyymm = ?',
          whereArgs: [key],
        );
        updates++;
      }
    }
    return updates;
  }

  Future<void> _recordAutomationRun(
      Database db, Map<String, int> summary) async {
    await db.insert('automation_runs', {
      'id': _uuid.v4(),
      'ts': DateTime.now().millisecondsSinceEpoch,
      'summary_json': jsonEncode(summary),
    });
  }

  Future<Map<String, String>> _accountIdsByCode(DatabaseExecutor db) async {
    final rows = await db.query('ledger_accounts', columns: ['id', 'code']);
    final map = <String, String>{};
    for (final row in rows) {
      final id = row['id'] as String?;
      final code = row['code'] as String?;
      if (id == null || code == null) continue;
      map[code] = id;
    }
    final required = <String>[
      cashAccountCode,
      bankAccountCode,
      receivableAccountCode,
      payableAccountCode,
      vatInputAccountCode,
      vatOutputAccountCode,
      washSalesAccountCode,
      generalExpenseAccountCode,
    ];
    final missing = required.where((code) => !map.containsKey(code)).toList();
    if (missing.isNotEmpty) {
      await _ensureChartOfAccounts(db);
      return _accountIdsByCode(db);
    }
    return map;
  }

  Future<String?> _entryForSource(
    DatabaseExecutor db, {
    required String sourceType,
    required String sourceId,
  }) async {
    final rows = await db.query(
      'journal_entries',
      columns: ['id'],
      where: 'source_type = ? AND source_id = ?',
      whereArgs: [sourceType, sourceId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as String?;
  }

  Future<String> _createEntry(
    DatabaseExecutor db, {
    required int txnTs,
    required String description,
    required List<_PostingLine> lines,
    String? sourceType,
    String? sourceId,
  }) async {
    if (sourceType != null && sourceId != null) {
      final existing = await _entryForSource(
        db,
        sourceType: sourceType,
        sourceId: sourceId,
      );
      if (existing != null) return existing;
    }

    final normalized = lines
        .map((line) => _PostingLine(
              accountId: line.accountId,
              debit: _round2(line.debit),
              credit: _round2(line.credit),
              memo: line.memo,
            ))
        .where((line) => line.debit > 0 || line.credit > 0)
        .toList(growable: false);
    if (normalized.length < 2) {
      throw StateError('A journal entry needs at least two non-zero lines.');
    }

    final debitTotal = _round2(
      normalized.fold<double>(0, (sum, line) => sum + line.debit),
    );
    final creditTotal = _round2(
      normalized.fold<double>(0, (sum, line) => sum + line.credit),
    );
    if ((debitTotal - creditTotal).abs() > 0.009) {
      throw StateError(
          'Journal entry is unbalanced (debit=$debitTotal credit=$creditTotal).');
    }

    final entryId = _uuid.v4();
    await db.insert('journal_entries', {
      'id': entryId,
      'txn_ts': txnTs,
      'txn_date': _ymd.format(DateTime.fromMillisecondsSinceEpoch(txnTs)),
      'description': description,
      'source_type': sourceType,
      'source_id': sourceId,
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    });

    for (final line in normalized) {
      await db.insert('journal_lines', {
        'id': _uuid.v4(),
        'entry_id': entryId,
        'account_id': line.accountId,
        'memo': line.memo,
        'debit': line.debit,
        'credit': line.credit,
      });
    }
    return entryId;
  }

  Future<void> _insertCashMovement(
    DatabaseExecutor db, {
    required int ts,
    required String direction,
    required double amount,
    required String method,
    required String description,
    required String sourceType,
    required String sourceId,
  }) async {
    final existing = await db.query(
      'bank_transactions',
      columns: ['id'],
      where:
          'source_type = ? AND source_id = ? AND direction = ? AND method = ?',
      whereArgs: [sourceType, sourceId, direction, method],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    String? bankAccountId;
    if (method != 'cash') {
      final rows = await db.query(
        'bank_accounts',
        columns: ['id'],
        where: 'is_default = 1',
        limit: 1,
      );
      if (rows.isNotEmpty) {
        bankAccountId = rows.first['id'] as String?;
      }
    }
    await db.insert('bank_transactions', {
      'id': _uuid.v4(),
      'bank_account_id': bankAccountId,
      'ts': ts,
      'direction': direction,
      'amount': _round2(amount),
      'method': method,
      'description': description,
      'source_type': sourceType,
      'source_id': sourceId,
      'reconciled': 0,
      'created_ts': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<double> _balanceForCode(DatabaseExecutor db, String code) async {
    final rows = await db.rawQuery('''
      SELECT
        a.type AS account_type,
        IFNULL(SUM(l.debit), 0) AS debits,
        IFNULL(SUM(l.credit), 0) AS credits
      FROM ledger_accounts a
      LEFT JOIN journal_lines l ON l.account_id = a.id
      WHERE a.code = ?
      GROUP BY a.id
    ''', [code]);
    if (rows.isEmpty) return 0;
    final type = rows.first['account_type'] as String? ?? 'asset';
    final debits = (rows.first['debits'] as num?)?.toDouble() ?? 0;
    final credits = (rows.first['credits'] as num?)?.toDouble() ?? 0;
    return _round2(_signedBalance(type, debits, credits));
  }

  Future<double> _profitYtd(DatabaseExecutor db) async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery('''
      SELECT
        a.type AS account_type,
        IFNULL(SUM(l.debit), 0) AS debits,
        IFNULL(SUM(l.credit), 0) AS credits
      FROM journal_lines l
      INNER JOIN journal_entries j ON j.id = l.entry_id
      INNER JOIN ledger_accounts a ON a.id = l.account_id
      WHERE j.txn_ts >= ?
      GROUP BY a.type
    ''', [start]);

    double income = 0;
    double expenses = 0;
    for (final row in rows) {
      final type = row['account_type'] as String? ?? '';
      final debits = (row['debits'] as num?)?.toDouble() ?? 0;
      final credits = (row['credits'] as num?)?.toDouble() ?? 0;
      if (type == 'income') {
        income += (credits - debits);
      } else if (type == 'expense') {
        expenses += (debits - credits);
      }
    }
    return _round2(income - expenses);
  }

  _VatSplit _splitFromGross(double gross, {required bool includeVat}) {
    final total = _round2(gross);
    final rate = _validRate(AppSettings.instance.taxRate);
    if (!includeVat || rate <= 0) {
      return _VatSplit(net: total, tax: 0, total: total);
    }
    final net = _round2(total / (1 + rate));
    final tax = _round2(total - net);
    return _VatSplit(net: net, tax: tax, total: total);
  }

  String _paymentAccountCode(String method) {
    return method == 'cash' ? cashAccountCode : bankAccountCode;
  }

  String _expenseAccountCodeForCategory(String category) {
    final c = category.toLowerCase();
    if (c.contains('rent') || c.contains('lease')) return '5030';
    if (c.contains('salary') || c.contains('wage') || c.contains('payroll')) {
      return '5020';
    }
    if (c.contains('water') ||
        c.contains('electric') ||
        c.contains('utility') ||
        c.contains('power')) {
      return '5010';
    }
    if (c.contains('soap') ||
        c.contains('chemical') ||
        c.contains('detergent') ||
        c.contains('supply')) {
      return '5000';
    }
    return generalExpenseAccountCode;
  }

  String _newDocNumber(String prefix) {
    final token = _uuid.v4().split('-').first.toUpperCase();
    return '$prefix-${_compact.format(DateTime.now())}-$token';
  }

  double _signedBalance(String type, double debits, double credits) {
    if (type == 'asset' || type == 'expense') {
      return debits - credits;
    }
    return credits - debits;
  }

  double _validRate(double? value) {
    final parsed = value ?? 0;
    if (parsed.isNaN || parsed.isInfinite) return 0;
    return parsed.clamp(0.0, 1.0).toDouble();
  }

  double _round2(double value) => (value * 100).roundToDouble() / 100;
}

class _PostingLine {
  final String accountId;
  final double debit;
  final double credit;
  final String? memo;

  _PostingLine({
    required this.accountId,
    required this.debit,
    required this.credit,
    this.memo,
  });
}

class _VatSplit {
  final double net;
  final double tax;
  final double total;

  _VatSplit({
    required this.net,
    required this.tax,
    required this.total,
  });
}
