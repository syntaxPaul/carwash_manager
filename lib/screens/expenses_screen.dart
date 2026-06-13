import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../services/bookkeeping_service.dart';
import '../utils/format.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/app_background.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final rows = await d.query('expenses', orderBy: 'ts DESC');
    setState(() => items = rows);
  }

  Future<void> _addExpense() async {
    final r = await showDialog<_ExpenseInput>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (r == null) return;
    final d = await AppDb.instance.db;
    await d.transaction((txn) async {
      final row = <String, Object?>{
        'id': const Uuid().v4(),
        'ts': DateTime.now().millisecondsSinceEpoch,
        'category': r.category,
        'amount': r.amount,
        'notes': r.notes,
        'payment_method': r.paymentMethod,
        'payment_status': r.paymentStatus,
        'due_ts': r.dueTs,
        'vendor_name': r.vendorName,
      };
      await txn.insert('expenses', row);
      await BookkeepingService.instance.postExpense(txn, row);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = items[i];
                final dt = DateTime.fromMillisecondsSinceEpoch(m['ts'] as int);
                final dueTs = m['due_ts'] as int?;
                final paymentStatus =
                    (m['payment_status'] as String?) ?? 'paid';
                final paymentMethod =
                    (m['payment_method'] as String?) ?? 'cash';
                final vendor = (m['vendor_name'] as String?)?.trim();
                final statusLabel =
                    paymentStatus == 'due' ? 'Unpaid bill' : 'Paid';
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title: Text(m['category'] as String),
                    subtitle: Text(
                      [
                        ymd(dt),
                        if (vendor != null && vendor.isNotEmpty)
                          'Vendor: $vendor',
                        if (paymentStatus == 'due' && dueTs != null)
                          'Due: ${ymd(DateTime.fromMillisecondsSinceEpoch(dueTs))}',
                        '$statusLabel • ${paymentMethod.toUpperCase()}',
                        if ((m['notes'] as String?)?.trim().isNotEmpty ?? false)
                          m['notes'] as String,
                      ].join('\n'),
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      money((m['amount'] as num).toDouble()),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExpense,
        icon: const Icon(Icons.receipt_long_rounded),
        label: const Text('Add expense'),
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
      title: const Text('Add Expense'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 400,
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
                decoration: const InputDecoration(labelText: 'Amount (R)'),
                keyboardType: TextInputType.number,
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
                  DropdownMenuItem(
                      value: 'due', child: Text('Pay later (A/P)')),
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
