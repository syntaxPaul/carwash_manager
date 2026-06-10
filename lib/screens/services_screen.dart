import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../utils/format.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/app_background.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<Map<String, Object?>> items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final rows = await d.query('services', orderBy: 'name ASC');
    setState(() => items = rows);
  }

  Future<void> _add() async {
    final r = await showDialog<(String, double)>(
      context: context,
      builder: (_) => const _ServiceDialog(),
    );
    if (r == null) return;
    final (name, price) = r;
    final d = await AppDb.instance.db;
    await d.insert('services', {
      'id': const Uuid().v4(),
      'name': name,
      'price': price,
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Services'),
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
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final m = items[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_car_wash),
                  title: Text(m['name'] as String),
                  trailing: Text(money((m['price'] as num).toDouble())),
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
      bottomNavigationBar: const BottomNav(currentIndex: 3),
    );
  }
}

class _ServiceDialog extends StatefulWidget {
  const _ServiceDialog();
  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Service'),
      content: Form(
        key: _form,
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Service name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Price (R)'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || double.tryParse(v) == null)
                    ? 'Enter valid price'
                    : null,
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
            Navigator.pop<(String, double)>(
              context,
              (
                _nameCtrl.text.trim(),
                double.parse(_priceCtrl.text),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
