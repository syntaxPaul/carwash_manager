import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
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
    final d = await AppDb.instance.db;
    try {
      List<Map<String, Object?>> washes;
      if (range == null) {
        washes = await d.query('washes', orderBy: 'ts ASC');
      } else {
        final start =
            DateTime(range!.start.year, range!.start.month, range!.start.day)
                .millisecondsSinceEpoch;
        final end = DateTime(
                range!.end.year, range!.end.month, range!.end.day, 23, 59, 59)
            .millisecondsSinceEpoch;
        washes = await d.query('washes',
            where: 'ts BETWEEN ? AND ?',
            whereArgs: [start, end],
            orderBy: 'ts ASC');
      }
      final rows = <List<dynamic>>[
        ['Date', 'Service', 'Price', 'Payment', 'Employee', 'Notes'],
        ...washes.map((w) => [
              ymd(DateTime.fromMillisecondsSinceEpoch(w['ts'] as int)),
              w['service_name'],
              w['price'],
              w['payment_method'],
              w['employee_name'] ?? '',
              w['notes'] ?? '',
            ]),
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final file = await _writeExportFile(
        extension: 'csv',
        bytes: utf8.encode(csv),
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'text/csv',
            name: file.uri.pathSegments.last,
          ),
        ],
        subject: 'WashDesk CSV report',
        text: 'Choose where to save or share this WashDesk CSV report.',
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
    final s = AppSettings.instance;
    try {
      final incomeExVat =
          s.pricesIncludeVat ? income / (1 + s.taxRate) : income;
      final vatPortion =
          s.pricesIncludeVat ? (income - incomeExVat) : (income * s.taxRate);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(s.businessName,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              if (s.vatReg.isNotEmpty) pw.Text('VAT Reg: ${s.vatReg}'),
              pw.SizedBox(height: 8),
              if (range == null)
                pw.Text('Period: All time')
              else
                pw.Text('Period: ${ymd(range!.start)} to ${ymd(range!.end)}'),
              pw.SizedBox(height: 16),
              pw.Text('Income: ${money(income)}'),
              pw.Text(
                  'Tax (${(s.taxRate * 100).toStringAsFixed(2)}%): ${money(vatPortion)}'),
              pw.Text('Income (ex VAT): ${money(incomeExVat)}'),
              pw.Text('Expenses: ${money(expenses)}'),
              pw.Text('Profit: ${money(income - expenses)}'),
            ],
          ),
        ),
      );

      final file = await _writeExportFile(
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
        subject: 'WashDesk PDF report',
        text: 'Choose where to save or share this WashDesk PDF report.',
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
    required String extension,
    required List<int> bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/washdesk_report_$timestamp.$extension');
    return file.writeAsBytes(bytes, flush: true);
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
