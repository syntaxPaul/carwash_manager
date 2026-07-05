import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../services/bookkeeping_service.dart';
import '../utils/format.dart';
import '../widgets/app_background.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/wd_kit.dart';

class BookkeepingScreen extends StatefulWidget {
  const BookkeepingScreen({super.key});

  @override
  State<BookkeepingScreen> createState() => _BookkeepingScreenState();
}

class _BookkeepingScreenState extends State<BookkeepingScreen> {
  final Uuid _uuid = const Uuid();

  bool _loading = true;
  Map<String, double> _snapshot = const {};
  List<Map<String, Object?>> _openInvoices = const [];
  List<Map<String, Object?>> _openBills = const [];
  List<Map<String, Object?>> _recentExpenses = const [];
  List<Map<String, Object?>> _entries = const [];
  List<Map<String, Object?>> _trialBalance = const [];
  List<Map<String, Object?>> _accounts = const [];
  Map<String, Object?> _latestAutomationRun = const {};
  Map<String, int> _automationSummary = const {};
  List<Map<String, Object?>> _monthlyCloses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await BookkeepingService.instance.bootstrap();
    final automationSummary = await BookkeepingService.instance.runAutomation();

    final results = await Future.wait([
      BookkeepingService.instance.financialSnapshot(),
      BookkeepingService.instance.openInvoices(),
      BookkeepingService.instance.openVendorBills(),
      BookkeepingService.instance.recentJournalEntries(limit: 12),
      BookkeepingService.instance.trialBalance(),
      BookkeepingService.instance.listLedgerAccounts(),
      BookkeepingService.instance.latestAutomationRun(),
      BookkeepingService.instance.monthlyCloseSnapshots(limit: 6),
      _fetchRecentExpenses(limit: 12),
    ]);

    if (!mounted) return;
    setState(() {
      _snapshot = results[0] as Map<String, double>;
      _openInvoices = results[1] as List<Map<String, Object?>>;
      _openBills = results[2] as List<Map<String, Object?>>;
      _entries = results[3] as List<Map<String, Object?>>;
      _trialBalance = results[4] as List<Map<String, Object?>>;
      _accounts = results[5] as List<Map<String, Object?>>;
      _latestAutomationRun = results[6] as Map<String, Object?>;
      _monthlyCloses = results[7] as List<Map<String, Object?>>;
      _recentExpenses = results[8] as List<Map<String, Object?>>;
      _automationSummary = automationSummary;
      _loading = false;
    });
  }

  Future<List<Map<String, Object?>>> _fetchRecentExpenses({
    int limit = 12,
  }) async {
    final db = await AppDb.instance.db;
    return db.query('expenses', orderBy: 'ts DESC', limit: limit);
  }

  Future<void> _runAutomationNow() async {
    await BookkeepingService.instance.runAutomation(force: true);
    await _load();
  }

  Future<void> _showInvoiceDialog() async {
    final form = GlobalKey<FormState>();
    final customerCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final descCtrl = TextEditingController(text: 'Corporate wash package');
    final amountCtrl = TextEditingController();
    final taxCtrl = TextEditingController(
        text: (AppSettings.instance.taxRate * 100).toStringAsFixed(0));
    DateTime dueDate = DateTime.now().add(const Duration(days: 14));
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> pickDueDate() async {
              final selected = await showDatePicker(
                context: ctx,
                initialDate: dueDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (selected == null) return;
              setStateDialog(() => dueDate = selected);
            }

            return AlertDialog(
              title: const Text('Create sales invoice'),
              content: Form(
                key: form,
                child: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: customerCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Customer'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter customer'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Phone (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Email (optional)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter description'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Subtotal',
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final parsed = double.tryParse(v ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid subtotal';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: taxCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Tax rate (%)',
                            hintText: '15',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final parsed = double.tryParse(v ?? '');
                            if (parsed == null || parsed < 0 || parsed > 100) {
                              return 'Use 0 - 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: pickDueDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Due: ${ymd(dueDate)}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final subtotal = double.parse(amountCtrl.text.trim());
                          final taxRate =
                              (double.parse(taxCtrl.text.trim()) / 100);
                          setStateDialog(() => saving = true);
                          try {
                            await BookkeepingService.instance
                                .createSalesInvoice(
                              customerName: customerCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              subtotal: subtotal,
                              taxRate: taxRate,
                              dueDate: dueDate,
                              phone: phoneCtrl.text.trim().isEmpty
                                  ? null
                                  : phoneCtrl.text.trim(),
                              email: emailCtrl.text.trim().isEmpty
                                  ? null
                                  : emailCtrl.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(SnackBar(content: Text('$e')));
                            setStateDialog(() => saving = false);
                          }
                        },
                  child: const Text('Create invoice'),
                ),
              ],
            );
          },
        );
      },
    );

    await _load();
  }

  Future<void> _showBillDialog() async {
    final form = GlobalKey<FormState>();
    final vendorCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Supplies');
    final descCtrl = TextEditingController(text: 'Vendor bill');
    final amountCtrl = TextEditingController();
    final taxCtrl = TextEditingController(
        text: (AppSettings.instance.taxRate * 100).toStringAsFixed(0));
    DateTime dueDate = DateTime.now().add(const Duration(days: 14));
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> pickDueDate() async {
              final selected = await showDatePicker(
                context: ctx,
                initialDate: dueDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
              );
              if (selected == null) return;
              setStateDialog(() => dueDate = selected);
            }

            return AlertDialog(
              title: const Text('Create vendor bill'),
              content: Form(
                key: form,
                child: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: vendorCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Vendor'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter vendor'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Expense category'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter category'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: descCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter description'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Subtotal',
                            hintText: '0.00',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final parsed = double.tryParse(v ?? '');
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid subtotal';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: taxCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Tax rate (%)'),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) {
                            final parsed = double.tryParse(v ?? '');
                            if (parsed == null || parsed < 0 || parsed > 100) {
                              return 'Use 0 - 100';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: pickDueDate,
                          icon: const Icon(Icons.date_range),
                          label: Text('Due: ${ymd(dueDate)}'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          final subtotal = double.parse(amountCtrl.text.trim());
                          final taxRate =
                              double.parse(taxCtrl.text.trim()) / 100;
                          setStateDialog(() => saving = true);
                          try {
                            await BookkeepingService.instance.createVendorBill(
                              vendorName: vendorCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                              category: categoryCtrl.text.trim(),
                              subtotal: subtotal,
                              taxRate: taxRate,
                              dueDate: dueDate,
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(SnackBar(content: Text('$e')));
                            setStateDialog(() => saving = false);
                          }
                        },
                  child: const Text('Create bill'),
                ),
              ],
            );
          },
        );
      },
    );

    await _load();
  }

  Future<void> _showInvoicePaymentDialog(Map<String, Object?> invoice) async {
    final id = invoice['id'] as String?;
    if (id == null) return;
    final currentBalance = (invoice['balance'] as num?)?.toDouble() ?? 0;
    final amountCtrl =
        TextEditingController(text: currentBalance.toStringAsFixed(2));
    final referenceCtrl = TextEditingController();
    String method = 'eft';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('Receive payment • ${invoice['invoice_no']}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'eft', child: Text('EFT')),
                      DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                      DropdownMenuItem(
                          value: 'bank', child: Text('Bank transfer')),
                    ],
                    onChanged: (v) => setStateDialog(() => method = v ?? 'eft'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Reference (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid amount.')),
                          );
                          return;
                        }
                        setStateDialog(() => saving = true);
                        try {
                          await BookkeepingService.instance
                              .receiveInvoicePayment(
                            invoiceId: id,
                            amount: amount,
                            method: method,
                            reference: referenceCtrl.text.trim().isEmpty
                                ? null
                                : referenceCtrl.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('$e')));
                          setStateDialog(() => saving = false);
                        }
                      },
                child: const Text('Receive'),
              ),
            ],
          );
        });
      },
    );

    await _load();
  }

  Future<void> _showBillPaymentDialog(Map<String, Object?> bill) async {
    final id = bill['id'] as String?;
    if (id == null) return;
    final currentBalance = (bill['balance'] as num?)?.toDouble() ?? 0;
    final amountCtrl =
        TextEditingController(text: currentBalance.toStringAsFixed(2));
    final referenceCtrl = TextEditingController();
    String method = 'eft';
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setStateDialog) {
          return AlertDialog(
            title: Text('Pay bill • ${bill['bill_no']}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                      DropdownMenuItem(value: 'eft', child: Text('EFT')),
                      DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                      DropdownMenuItem(
                          value: 'bank', child: Text('Bank transfer')),
                    ],
                    onChanged: (v) => setStateDialog(() => method = v ?? 'eft'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: referenceCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Reference (optional)'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid amount.')),
                          );
                          return;
                        }
                        setStateDialog(() => saving = true);
                        try {
                          await BookkeepingService.instance.payVendorBill(
                            billId: id,
                            amount: amount,
                            method: method,
                            reference: referenceCtrl.text.trim().isEmpty
                                ? null
                                : referenceCtrl.text.trim(),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx)
                              .showSnackBar(SnackBar(content: Text('$e')));
                          setStateDialog(() => saving = false);
                        }
                      },
                child: const Text('Pay'),
              ),
            ],
          );
        });
      },
    );

    await _load();
  }

  Future<void> _showManualEntryDialog() async {
    if (_accounts.isEmpty) {
      await _load();
      if (!mounted) return;
      if (_accounts.isEmpty) return;
    }
    final form = GlobalKey<FormState>();
    final descriptionCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final memoCtrl = TextEditingController();
    String? debitAccountId;
    String? creditAccountId;
    bool saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: const Text('Manual adjustment journal'),
              content: Form(
                key: form,
                child: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: descriptionCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Enter description'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: debitAccountId,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Debit account'),
                          items: _accounts
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: a['id'] as String,
                                  child: Text('${a['code']} • ${a['name']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => debitAccountId = v),
                          validator: (v) =>
                              v == null ? 'Select debit account' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: creditAccountId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Credit account'),
                          items: _accounts
                              .map(
                                (a) => DropdownMenuItem<String>(
                                  value: a['id'] as String,
                                  child: Text('${a['code']} • ${a['name']}'),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setStateDialog(() => creditAccountId = v),
                          validator: (v) =>
                              v == null ? 'Select credit account' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'Amount'),
                          validator: (v) {
                            final amount = double.tryParse(v ?? '');
                            if (amount == null || amount <= 0) {
                              return 'Enter a valid amount';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: memoCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Memo (optional)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!form.currentState!.validate()) return;
                          if (debitAccountId == creditAccountId) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Debit and credit accounts must differ.'),
                              ),
                            );
                            return;
                          }
                          setStateDialog(() => saving = true);
                          try {
                            await BookkeepingService.instance
                                .postManualAdjustment(
                              debitAccountId: debitAccountId!,
                              creditAccountId: creditAccountId!,
                              amount: double.parse(amountCtrl.text.trim()),
                              description: descriptionCtrl.text.trim(),
                              memo: memoCtrl.text.trim().isEmpty
                                  ? null
                                  : memoCtrl.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                          } catch (e) {
                            if (!ctx.mounted) return;
                            ScaffoldMessenger.of(ctx)
                                .showSnackBar(SnackBar(content: Text('$e')));
                            setStateDialog(() => saving = false);
                          }
                        },
                  child: const Text('Post journal'),
                ),
              ],
            );
          },
        );
      },
    );

    await _load();
  }

  Future<void> _showExpenseDialog() async {
    final input = await showDialog<_ExpenseInput>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (input == null) return;

    final db = await AppDb.instance.db;
    await db.transaction((txn) async {
      final row = <String, Object?>{
        'id': _uuid.v4(),
        'ts': DateTime.now().millisecondsSinceEpoch,
        'category': input.category,
        'amount': input.amount,
        'notes': input.notes,
        'payment_method': input.paymentMethod,
        'payment_status': input.paymentStatus,
        'due_ts': input.dueTs,
        'vendor_name': input.vendorName,
      };
      await txn.insert('expenses', row);
      await BookkeepingService.instance.postExpense(txn, row);
    });

    await BookkeepingService.instance.runAutomation();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final nonZeroTrial = _trialBalance
        .where((row) {
          final d = (row['debit'] as num?)?.toDouble() ?? 0;
          final c = (row['credit'] as num?)?.toDouble() ?? 0;
          return d.abs() > 0.009 || c.abs() > 0.009;
        })
        .take(10)
        .toList();

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Bookkeeping'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                children: [
                  GridView.count(
                    padding: EdgeInsets.zero,
                    primary: false,
                    crossAxisCount: 2,
                    childAspectRatio: 1.35,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    children: [
                      WdStatCard(
                        label: 'Cash on hand',
                        value: money(_snapshot['cash'] ?? 0),
                        icon: Icons.payments_rounded,
                      ),
                      WdStatCard(
                        label: 'Bank',
                        value: money(_snapshot['bank'] ?? 0),
                        icon: Icons.account_balance_rounded,
                      ),
                      WdStatCard(
                        label: 'Accounts receivable',
                        value: money(_snapshot['receivables'] ?? 0),
                        icon: Icons.request_page_rounded,
                      ),
                      WdStatCard(
                        label: 'Accounts payable',
                        value: money(_snapshot['payables'] ?? 0),
                        icon: Icons.receipt_long_rounded,
                      ),
                      WdStatCard(
                        label: 'VAT due',
                        value: money(_snapshot['vat_due'] ?? 0),
                        icon: Icons.percent_rounded,
                      ),
                      WdStatCard(
                        label: 'YTD profit',
                        value: money(_snapshot['ytd_profit'] ?? 0),
                        icon: Icons.trending_up_rounded,
                        emphasis: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showInvoiceDialog,
                          icon: const Icon(Icons.request_quote),
                          label: const Text('New invoice'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _showBillDialog,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('New bill'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _showExpenseDialog,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('New expense (paid now or due)'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('Post manual journal adjustment'),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome),
                      title: const Text('Automation engine'),
                      subtitle: Text(
                        [
                          'Classified: ${_automationSummary['classified_expenses'] ?? 0}',
                          'Posted: ${_automationSummary['posted_transactions'] ?? 0}',
                          'Status updates: ${_automationSummary['status_updates'] ?? 0}',
                          'Monthly closes: ${_automationSummary['monthly_close_updates'] ?? 0}',
                          if ((_latestAutomationRun['ts'] as num?) != null)
                            'Last run: ${ymd(DateTime.fromMillisecondsSinceEpoch((_latestAutomationRun['ts'] as num).toInt()))}',
                        ].join(' • '),
                      ),
                      trailing: TextButton(
                        onPressed: _runAutomationNow,
                        child: const Text('Run now'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Monthly close snapshots'),
                  if (_monthlyCloses.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No monthly close snapshots yet'),
                      ),
                    )
                  else
                    ..._monthlyCloses.map((month) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.calendar_month),
                            title: Text(month['yyyymm'] as String? ?? ''),
                            subtitle: Text(
                                'Income ${money((month['income'] as num?)?.toDouble() ?? 0)} • Expenses ${money((month['expenses'] as num?)?.toDouble() ?? 0)}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  money((month['profit'] as num?)?.toDouble() ??
                                      0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                    'VAT ${money((month['vat_due'] as num?)?.toDouble() ?? 0)}'),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Open invoices'),
                  if (_openInvoices.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No unpaid invoices'),
                      ),
                    )
                  else
                    ..._openInvoices.map((invoice) {
                      final dueTs = invoice['due_ts'] as int?;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.request_quote),
                          title: Text(
                              '${invoice['invoice_no']} • ${invoice['contact_name']}'),
                          subtitle: Text(dueTs == null
                              ? 'No due date'
                              : 'Due: ${ymd(DateTime.fromMillisecondsSinceEpoch(dueTs))}'),
                          isThreeLine: true,
                          trailing: SizedBox(
                            width: 140,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  money((invoice['balance'] as num?)
                                          ?.toDouble() ??
                                      0),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 2),
                                TextButton(
                                  onPressed: () =>
                                      _showInvoicePaymentDialog(invoice),
                                  child: const Text('Receive'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Open vendor bills'),
                  if (_openBills.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No unpaid vendor bills'),
                      ),
                    )
                  else
                    ..._openBills.map((bill) {
                      final dueTs = bill['due_ts'] as int?;
                      final balance =
                          (bill['balance'] as num?)?.toDouble() ?? 0;
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt),
                          title: Text(
                              '${bill['bill_no']} • ${bill['contact_name']}'),
                          subtitle: Text([
                            dueTs == null
                                ? 'No due date'
                                : 'Due: ${ymd(DateTime.fromMillisecondsSinceEpoch(dueTs))}',
                            'Balance: ${money(balance)}',
                          ].join('\n')),
                          isThreeLine: false,
                          trailing: TextButton(
                            onPressed: () => _showBillPaymentDialog(bill),
                            child: const Text('Pay'),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Recent expenses'),
                  if (_recentExpenses.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No expenses recorded yet'),
                      ),
                    )
                  else
                    ..._recentExpenses.map((expense) {
                      final ts = expense['ts'] as int?;
                      final dueTs = expense['due_ts'] as int?;
                      final paymentStatus =
                          (expense['payment_status'] as String?) ?? 'paid';
                      final paymentMethod =
                          (expense['payment_method'] as String?) ?? 'cash';
                      final vendor =
                          (expense['vendor_name'] as String?)?.trim();
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title:
                              Text(expense['category'] as String? ?? 'Expense'),
                          subtitle: Text(
                            [
                              if (ts != null)
                                'Date: ${ymd(DateTime.fromMillisecondsSinceEpoch(ts))}',
                              if (vendor != null && vendor.isNotEmpty)
                                'Vendor: $vendor',
                              if (paymentStatus == 'due' && dueTs != null)
                                'Due: ${ymd(DateTime.fromMillisecondsSinceEpoch(dueTs))}',
                              '${paymentStatus == 'due' ? 'Unpaid bill' : 'Paid'} • ${paymentMethod.toUpperCase()}',
                              if ((expense['notes'] as String?)
                                      ?.trim()
                                      .isNotEmpty ??
                                  false)
                                expense['notes'] as String,
                            ].join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: Text(
                            money((expense['amount'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Recent journal entries'),
                  if (_entries.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No journal entries yet'),
                      ),
                    )
                  else
                    ..._entries.map((entry) {
                      final ts = entry['txn_ts'] as int?;
                      final dt = ts == null
                          ? DateTime.now()
                          : DateTime.fromMillisecondsSinceEpoch(ts);
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.book_outlined),
                          title:
                              Text(entry['description'] as String? ?? 'Entry'),
                          subtitle: Text(
                              '${ymd(dt)} • ${entry['source_type'] ?? 'manual'}'),
                          trailing: Text(
                            money((entry['amount'] as num?)?.toDouble() ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 12),
                  const WdSectionHeader('Trial balance (top accounts)'),
                  if (nonZeroTrial.isEmpty)
                    const Card(
                      child: ListTile(
                        title: Text('No balances to show'),
                      ),
                    )
                  else
                    ...nonZeroTrial.map((row) => Card(
                          child: ListTile(
                            title: Text('${row['code']} • ${row['name']}'),
                            subtitle:
                                Text((row['type'] as String).toUpperCase()),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                    'Dr ${money((row['debit'] as num).toDouble())}'),
                                Text(
                                    'Cr ${money((row['credit'] as num).toDouble())}'),
                              ],
                            ),
                          ),
                        )),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 2),
    );
  }
}


class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _catCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _vendorCtrl = TextEditingController();
  String _paymentStatus = 'paid';
  String _paymentMethod = 'cash';
  DateTime? _dueDate;

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _catCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter category' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _vendorCtrl,
                decoration:
                    const InputDecoration(labelText: 'Vendor (optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? 'Enter amount'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentStatus,
                decoration: const InputDecoration(labelText: 'Payment status'),
                items: const [
                  DropdownMenuItem(value: 'paid', child: Text('Paid now')),
                  DropdownMenuItem(value: 'due', child: Text('Pay later')),
                ],
                onChanged: (v) => setState(() => _paymentStatus = v ?? 'paid'),
              ),
              const SizedBox(height: 12),
              if (_paymentStatus == 'paid') ...[
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration:
                      const InputDecoration(labelText: 'Payment method'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'eft', child: Text('EFT')),
                    DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
                    DropdownMenuItem(
                        value: 'bank', child: Text('Bank transfer')),
                  ],
                  onChanged: (v) =>
                      setState(() => _paymentMethod = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
              ],
              if (_paymentStatus == 'due') ...[
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.date_range),
                  label: Text(_dueDate == null
                      ? 'Set due date (optional)'
                      : 'Due: ${ymd(_dueDate!)}'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            Navigator.pop<_ExpenseInput>(
              context,
              _ExpenseInput(
                category: _catCtrl.text.trim(),
                amount: double.parse(_amountCtrl.text),
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
                vendorName: _vendorCtrl.text.trim().isEmpty
                    ? null
                    : _vendorCtrl.text.trim(),
                paymentStatus: _paymentStatus,
                paymentMethod:
                    _paymentStatus == 'paid' ? _paymentMethod : 'cash',
                dueTs: _paymentStatus == 'due'
                    ? _dueDate?.millisecondsSinceEpoch
                    : null,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _ExpenseInput {
  final String category;
  final double amount;
  final String? notes;
  final String? vendorName;
  final String paymentStatus;
  final String paymentMethod;
  final int? dueTs;

  const _ExpenseInput({
    required this.category,
    required this.amount,
    this.notes,
    this.vendorName,
    required this.paymentStatus,
    required this.paymentMethod,
    this.dueTs,
  });
}
