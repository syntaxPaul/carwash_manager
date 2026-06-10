import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../widgets/app_background.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final rows = await d.query('employees', orderBy: 'name ASC');
    setState(() => items = rows);
  }

  Future<void> _add() async {
    final r = await showDialog<(String, String?)>(
      context: context,
      builder: (_) => const _EmployeeDialog(),
    );
    if (r == null) return;
    final (name, phone) = r;
    final d = await AppDb.instance.db;
    await d.insert('employees', {
      'id': const Uuid().v4(),
      'name': name,
      'phone': phone,
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
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
          ListView.separated(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(m['name'] as String),
                  subtitle: Text((m['phone'] as String?) ?? ''),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmployeeDialog extends StatefulWidget {
  const _EmployeeDialog();
  @override
  State<_EmployeeDialog> createState() => _EmployeeDialogState();
}

class _EmployeeDialogState extends State<_EmployeeDialog> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Employee'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration:
                    const InputDecoration(labelText: 'Phone (optional)'),
                keyboardType: TextInputType.phone,
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
            Navigator.pop<(String, String?)>(
              context,
              (
                _nameCtrl.text.trim(),
                _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
