import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../data/db.dart';
import '../utils/format.dart';
import '../widgets/bottom_nav.dart';
import '../data/settings.dart';
import '../widgets/app_background.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _RangeBounds {
  final int startTs;
  final int endTs;

  const _RangeBounds(this.startTs, this.endTs);
}

class _BookkeepingPack {
  final AppSettings settings;
  final DateTimeRange? range;
  final DateTime generatedAt;
  final List<Map<String, Object?>> washes;
  final List<Map<String, Object?>> expenses;
  final List<Map<String, Object?>> paymentMethods;
  final List<Map<String, Object?>> expenseCategories;

  const _BookkeepingPack({
    required this.settings,
    required this.range,
    required this.generatedAt,
    required this.washes,
    required this.expenses,
    required this.paymentMethods,
    required this.expenseCategories,
  });

  String get periodLabel {
    if (range == null) return 'All time';
    return '${ymd(range!.start)} to ${ymd(range!.end)}';
  }

  double get income => washes.fold(
        0,
        (sum, row) => sum + _asDouble(row['price']),
      );

  double get expensesTotal => expenses.fold(
        0,
        (sum, row) => sum + _asDouble(row['amount']),
      );

  double get incomeExVat {
    if (!settings.pricesIncludeVat) return income;
    return income / (1 + settings.taxRate);
  }

  double get vatOutput {
    if (settings.pricesIncludeVat) return income - incomeExVat;
    return income * settings.taxRate;
  }

  double get expenseExVat {
    if (!settings.pricesIncludeVat) return expensesTotal;
    return expensesTotal / (1 + settings.taxRate);
  }

  double get vatInput {
    if (settings.pricesIncludeVat) return expensesTotal - expenseExVat;
    return expensesTotal * settings.taxRate;
  }

  double get netVat => vatOutput - vatInput;

  double get profit => income - expensesTotal;

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? range;
  double income = 0;
  double expenses = 0;
  List<Map<String, Object?>> methods = const [];
  bool _exportingCsv = false;
  bool _exportingPdf = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
    );
    if (r != null) {
      setState(() => range = r);
      _load();
    }
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    List<Map<String, Object?>> inc, exp, byM;
    if (range == null) {
      inc = await d.rawQuery('SELECT SUM(price) s FROM washes');
      exp = await d.rawQuery('SELECT SUM(amount) s FROM expenses');
      byM = await d.rawQuery(
          'SELECT payment_method, COUNT(*) c, SUM(price) s FROM washes GROUP BY payment_method');
    } else {
      final start =
          DateTime(range!.start.year, range!.start.month, range!.start.day)
              .millisecondsSinceEpoch;
      final end = DateTime(
              range!.end.year, range!.end.month, range!.end.day, 23, 59, 59)
          .millisecondsSinceEpoch;
      inc = await d.rawQuery(
          'SELECT SUM(price) s FROM washes WHERE ts BETWEEN ? AND ?',
          [start, end]);
      exp = await d.rawQuery(
          'SELECT SUM(amount) s FROM expenses WHERE ts BETWEEN ? AND ?',
          [start, end]);
      byM = await d.rawQuery(
          'SELECT payment_method, COUNT(*) c, SUM(price) s FROM washes WHERE ts BETWEEN ? AND ? GROUP BY payment_method',
          [start, end]);
    }

    setState(() {
      income = (inc.first['s'] as num?)?.toDouble() ?? 0;
      expenses = (exp.first['s'] as num?)?.toDouble() ?? 0;
      methods = byM;
    });
  }

  Future<void> _exportCsv() async {
    if (_exportingCsv) return;
    setState(() => _exportingCsv = true);
    try {
      final pack = await _loadBookkeepingPack();
      final file = await _writeExportFile(
        basename: 'washdesk_bookkeeping_pack',
        extension: 'csv',
        bytes: utf8.encode(_buildBookkeepingCsv(pack)),
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'text/csv',
            name: file.uri.pathSegments.last,
          ),
        ],
        subject: 'WashDesk bookkeeping CSV pack',
        text: 'Choose where to save or share this WashDesk bookkeeping CSV.',
        sharePositionOrigin: _shareOrigin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the CSV report.')),
      );
    } finally {
      if (mounted) setState(() => _exportingCsv = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exportingPdf) return;
    setState(() => _exportingPdf = true);
    try {
      final pack = await _loadBookkeepingPack();
      final pdf = _buildBookkeepingPdf(pack);

      final file = await _writeExportFile(
        basename: 'washdesk_bookkeeping_pack',
        extension: 'pdf',
        bytes: await pdf.save(),
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/pdf',
            name: file.uri.pathSegments.last,
          ),
        ],
        subject: 'WashDesk bookkeeping PDF pack',
        text: 'Choose where to save or share this WashDesk bookkeeping PDF.',
        sharePositionOrigin: _shareOrigin,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not export the PDF report.')),
      );
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<File> _writeExportFile({
    String basename = 'washdesk_report',
    required String extension,
    required List<int> bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/${basename}_$timestamp.$extension');
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<_BookkeepingPack> _loadBookkeepingPack() async {
    final d = await AppDb.instance.db;
    final bounds = _selectedRangeBounds();
    final where = bounds == null ? null : 'ts BETWEEN ? AND ?';
    final whereArgs = bounds == null ? null : [bounds.startTs, bounds.endTs];

    final washes = await d.query(
      'washes',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'ts ASC',
    );
    final expenseRows = await d.query(
      'expenses',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'ts ASC',
    );
    final paymentMethods = bounds == null
        ? await d.rawQuery(
            'SELECT payment_method, COUNT(*) c, SUM(price) s FROM washes GROUP BY payment_method ORDER BY payment_method')
        : await d.rawQuery(
            'SELECT payment_method, COUNT(*) c, SUM(price) s FROM washes WHERE ts BETWEEN ? AND ? GROUP BY payment_method ORDER BY payment_method',
            [bounds.startTs, bounds.endTs],
          );
    final expenseCategories = bounds == null
        ? await d.rawQuery(
            'SELECT category, COUNT(*) c, SUM(amount) s FROM expenses GROUP BY category ORDER BY category')
        : await d.rawQuery(
            'SELECT category, COUNT(*) c, SUM(amount) s FROM expenses WHERE ts BETWEEN ? AND ? GROUP BY category ORDER BY category',
            [bounds.startTs, bounds.endTs],
          );

    return _BookkeepingPack(
      settings: AppSettings.instance,
      range: range,
      generatedAt: DateTime.now(),
      washes: washes,
      expenses: expenseRows,
      paymentMethods: paymentMethods,
      expenseCategories: expenseCategories,
    );
  }

  _RangeBounds? _selectedRangeBounds() {
    if (range == null) return null;
    final start =
        DateTime(range!.start.year, range!.start.month, range!.start.day)
            .millisecondsSinceEpoch;
    final end =
        DateTime(range!.end.year, range!.end.month, range!.end.day, 23, 59, 59)
            .millisecondsSinceEpoch;
    return _RangeBounds(start, end);
  }

  String _buildBookkeepingCsv(_BookkeepingPack pack) {
    final rows = <List<dynamic>>[
      ['WashDesk bookkeeping pack'],
      ['Business', pack.settings.businessName],
      ['VAT registration', pack.settings.vatReg],
      ['Period', pack.periodLabel],
      ['Generated', ymd(pack.generatedAt)],
      [],
      ['Summary'],
      ['Income', pack.income],
      ['Income ex VAT', pack.incomeExVat],
      ['VAT output estimate', pack.vatOutput],
      ['Expenses', pack.expensesTotal],
      ['VAT input estimate', pack.vatInput],
      ['Net VAT estimate', pack.netVat],
      ['Profit before tax', pack.profit],
      [],
      ['Income by payment method'],
      ['Payment method', 'Count', 'Total'],
      ...pack.paymentMethods.map((m) => [
            m['payment_method'] ?? 'unknown',
            m['c'] ?? 0,
            _num(m['s']),
          ]),
      [],
      ['Expenses by category'],
      ['Category', 'Count', 'Total'],
      ...pack.expenseCategories.map((e) => [
            e['category'] ?? 'Uncategorised',
            e['c'] ?? 0,
            _num(e['s']),
          ]),
      [],
      ['Income transactions'],
      [
        'Date',
        'Service',
        'Vehicle',
        'Number plate',
        'Price',
        'Payment',
        'Employee',
        'Notes'
      ],
      ...pack.washes.map((w) => [
            _dateFromTs(w['ts']),
            w['service_name'] ?? '',
            w['vehicle'] ?? '',
            w['license_plate'] ?? '',
            _num(w['price']),
            w['payment_method'] ?? '',
            w['employee_name'] ?? '',
            w['notes'] ?? '',
          ]),
      [],
      ['Expense transactions'],
      [
        'Date',
        'Category',
        'Supplier/vendor',
        'Amount',
        'Payment',
        'Status',
        'Due date',
        'Notes'
      ],
      ...pack.expenses.map((e) => [
            _dateFromTs(e['ts']),
            e['category'] ?? '',
            e['vendor_name'] ?? '',
            _num(e['amount']),
            e['payment_method'] ?? '',
            e['payment_status'] ?? '',
            _dateFromTs(e['due_ts']),
            e['notes'] ?? '',
          ]),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  pw.Document _buildBookkeepingPdf(_BookkeepingPack pack) {
    final pdf = pw.Document();
    final titleStyle =
        pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold);
    final sectionStyle =
        pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
    const smallStyle = pw.TextStyle(fontSize: 8);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('WashDesk bookkeeping pack', style: smallStyle),
            pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                style: smallStyle),
          ],
        ),
        build: (context) => [
          pw.Text(pack.settings.businessName, style: titleStyle),
          pw.SizedBox(height: 4),
          pw.Text('Bookkeeping pack',
              style: const pw.TextStyle(
                  fontSize: 16, color: PdfColors.blueGrey700)),
          pw.SizedBox(height: 10),
          _pdfInfoTable([
            ['Period', pack.periodLabel],
            ['Generated', ymd(pack.generatedAt)],
            [
              'VAT registration',
              pack.settings.vatReg.isEmpty ? '-' : pack.settings.vatReg
            ],
            [
              'VAT setting',
              pack.settings.pricesIncludeVat
                  ? 'Prices include VAT'
                  : 'VAT calculated on top of income'
            ],
            [
              'VAT rate',
              '${(pack.settings.taxRate * 100).toStringAsFixed(2)}%'
            ],
          ]),
          pw.SizedBox(height: 14),
          pw.Text('Financial summary', style: sectionStyle),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: ['Metric', 'Amount'],
            rows: [
              ['Income', money(pack.income)],
              ['Income excluding VAT', money(pack.incomeExVat)],
              ['VAT output estimate', money(pack.vatOutput)],
              ['Expenses', money(pack.expensesTotal)],
              ['VAT input estimate', money(pack.vatInput)],
              ['Net VAT estimate', money(pack.netVat)],
              ['Profit before tax', money(pack.profit)],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Income by payment method', style: sectionStyle),
                    pw.SizedBox(height: 6),
                    _pdfTable(
                      headers: ['Payment method', 'Count', 'Total'],
                      rows: pack.paymentMethods
                          .map((m) => [
                                '${m['payment_method'] ?? 'unknown'}',
                                '${m['c'] ?? 0}',
                                money(_num(m['s'])),
                              ])
                          .toList(),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Expenses by category', style: sectionStyle),
                    pw.SizedBox(height: 6),
                    _pdfTable(
                      headers: ['Category', 'Count', 'Total'],
                      rows: pack.expenseCategories
                          .map((e) => [
                                '${e['category'] ?? 'Uncategorised'}',
                                '${e['c'] ?? 0}',
                                money(_num(e['s'])),
                              ])
                          .toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text('Income transactions', style: sectionStyle),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: [
              'Date',
              'Service',
              'Vehicle',
              'Plate',
              'Price',
              'Payment',
              'Employee'
            ],
            rows: pack.washes
                .map((w) => [
                      _dateFromTs(w['ts']),
                      '${w['service_name'] ?? ''}',
                      '${w['vehicle'] ?? ''}',
                      '${w['license_plate'] ?? ''}',
                      money(_num(w['price'])),
                      '${w['payment_method'] ?? ''}',
                      '${w['employee_name'] ?? ''}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Expense transactions', style: sectionStyle),
          pw.SizedBox(height: 6),
          _pdfTable(
            headers: [
              'Date',
              'Category',
              'Supplier',
              'Amount',
              'Payment',
              'Status',
              'Notes'
            ],
            rows: pack.expenses
                .map((e) => [
                      _dateFromTs(e['ts']),
                      '${e['category'] ?? ''}',
                      '${e['vendor_name'] ?? ''}',
                      money(_num(e['amount'])),
                      '${e['payment_method'] ?? ''}',
                      '${e['payment_status'] ?? ''}',
                      '${e['notes'] ?? ''}',
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text('Accountant notes', style: sectionStyle),
          pw.SizedBox(height: 4),
          pw.Text(
            'This pack is generated from records captured in WashDesk. It is intended for bookkeeping review and tax preparation support. Verify source records, bank deposits, receipts, invoices, VAT treatment and SARS filing requirements before submission.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
    return pdf;
  }

  pw.Widget _pdfInfoTable(List<List<String>> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey100),
      columnWidths: const {
        0: pw.FixedColumnWidth(120),
        1: pw.FlexColumnWidth(),
      },
      children: rows
          .map(
            (row) => pw.TableRow(
              children: [
                _pdfCell(row[0], bold: true),
                _pdfCell(row[1]),
              ],
            ),
          )
          .toList(),
    );
  }

  pw.Widget _pdfTable({
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    final dataRows = rows.isEmpty
        ? [
            List<String>.generate(
                headers.length, (index) => index == 0 ? 'No records' : '')
          ]
        : rows;
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: dataRows,
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 7),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey100),
      border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    );
  }

  pw.Widget _pdfCell(String text, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  double _num(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _dateFromTs(Object? value) {
    if (value is! int) return '';
    return ymd(DateTime.fromMillisecondsSinceEpoch(value));
  }

  Rect get _shareOrigin {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return const Rect.fromLTWH(0, 0, 1, 1);
    }
    final origin = box.localToGlobal(Offset.zero);
    return origin & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;
    final incomeExVat = s.pricesIncludeVat ? income / (1 + s.taxRate) : income;
    final vatPortion =
        s.pricesIncludeVat ? (income - incomeExVat) : (income * s.taxRate);
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          )
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const Icon(Icons.date_range),
                      label: Text(range == null
                          ? 'All time — tap to filter'
                          : '${ymd(range!.start)} → ${ymd(range!.end)}'),
                    ),
                  ),
                  if (range != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Clear filter',
                      onPressed: () {
                        setState(() => range = null);
                        _load();
                      },
                      icon: const Icon(Icons.clear),
                    ),
                  ]
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/wash-history'),
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('View wash history'),
              ),
              const SizedBox(height: 16),
              if (methods.isNotEmpty) ...[
                const Text('By payment method',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...methods.map((m) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.account_balance_wallet),
                        title: Text('${m['payment_method']}'),
                        subtitle: Text('Count: ${m['c']}'),
                        trailing: Text(
                          money((m['s'] as num?)?.toDouble() ?? 0),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
                const SizedBox(height: 16),
              ],
              Card(
                child: ListTile(
                  leading: const Icon(Icons.payments),
                  title: const Text('Income'),
                  trailing: Text(money(income),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text('Tax (${(s.taxRate * 100).toStringAsFixed(2)}%)'),
                  subtitle: Text(s.pricesIncludeVat
                      ? 'Included in income'
                      : 'Calculated on income'),
                  trailing: Text(money(vatPortion),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.price_change),
                  title: const Text('Income (ex VAT)'),
                  trailing: Text(money(incomeExVat),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_down),
                  title: const Text('Expenses'),
                  trailing: Text(money(expenses),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.trending_up),
                  title: const Text('Profit'),
                  trailing: Text(money(income - expenses),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _exportCsv,
                      icon: _exportingCsv
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.table_view),
                      label:
                          Text(_exportingCsv ? 'Preparing...' : 'Export CSV'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _exportPdf,
                      icon: _exportingPdf
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.picture_as_pdf),
                      label:
                          Text(_exportingPdf ? 'Preparing...' : 'Export PDF'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }
}
