import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../services/bookkeeping_service.dart';

class RecordWashScreen extends StatefulWidget {
  const RecordWashScreen({super.key});
  @override
  State<RecordWashScreen> createState() => _RecordWashScreenState();
}

class _RecordWashScreenState extends State<RecordWashScreen> {
  final _form = GlobalKey<FormState>();
  String? _serviceId;
  String? _serviceName;
  double? _price;
  String _paymentMethod = 'cash';
  String? _employeeId;
  String? _employeeName;
  final _carCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _employeeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, Object?>> services = [];
  List<Map<String, Object?>> employees = [];

  @override
  void initState() {
    super.initState();
    _loadMasterData();
  }

  Future<void> _loadMasterData() async {
    final d = await AppDb.instance.db;
    final s = await d.query('services', orderBy: 'name ASC');
    final e = await d.query('employees', orderBy: 'name ASC');
    setState(() {
      services = s;
      employees = e;
    });
  }

  @override
  void dispose() {
    _carCtrl.dispose();
    _plateCtrl.dispose();
    _employeeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _optionalText(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    _form.currentState!.save();
    final d = await AppDb.instance.db;
    await d.transaction((txn) async {
      final typedEmployee = _employeeCtrl.text.trim();
      final row = <String, Object?>{
        'id': const Uuid().v4(),
        'ts': DateTime.now().millisecondsSinceEpoch,
        'service_id': _serviceId,
        'service_name': _serviceName ?? 'Custom',
        'price': _price ?? 0.0,
        'payment_method': _paymentMethod,
        'employee_id': _employeeId,
        'employee_name':
            _employeeName ?? (typedEmployee.isEmpty ? null : typedEmployee),
        'vehicle': _optionalText(_carCtrl),
        'license_plate': _optionalText(_plateCtrl),
        'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      };
      await txn.insert('washes', row);
      await BookkeepingService.instance.postWash(txn, row);
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wash recorded')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record a Wash')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 48),
          children: [
            DropdownButtonFormField<String>(
              items: [
                ...services.map((s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        '${s['name']} (R${(s['price'] as num).toStringAsFixed(2)})',
                      ),
                    )),
                const DropdownMenuItem(
                  value: 'custom',
                  child: Text('Custom amount'),
                ),
              ],
              decoration: const InputDecoration(labelText: 'Service'),
              onChanged: (v) {
                setState(() {
                  _serviceId = v == 'custom' ? null : v;
                  if (v != null && v != 'custom') {
                    final sel = services.firstWhere((e) => e['id'] == v);
                    _serviceName = sel['name'] as String;
                    _price = (sel['price'] as num).toDouble();
                  } else {
                    _serviceName = null;
                    _price = null;
                  }
                });
              },
              validator: (v) => v == null ? 'Select a service' : null,
            ),
            const SizedBox(height: 12),
            if (_serviceId == null) ...[
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Service name',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the service name'
                    : null,
                onSaved: (v) => _serviceName = v!.trim(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Price (R)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final value = double.tryParse(v ?? '');
                  return value == null || value <= 0 ? 'Enter price' : null;
                },
                onSaved: (v) => _price = double.parse(v!.trim()),
              ),
              const SizedBox(height: 12),
            ],
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('Cash')),
                DropdownMenuItem(value: 'card', child: Text('Card')),
                DropdownMenuItem(value: 'eft', child: Text('EFT')),
                DropdownMenuItem(value: 'mobile', child: Text('Mobile')),
              ],
              decoration: const InputDecoration(labelText: 'Payment method'),
              onChanged: (v) => setState(() => _paymentMethod = v ?? 'cash'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _carCtrl,
              decoration: const InputDecoration(labelText: 'Car'),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter the car' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plateCtrl,
              decoration: const InputDecoration(labelText: 'Number plate'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter the number plate'
                  : null,
            ),
            const SizedBox(height: 12),
            if (employees.isEmpty)
              TextFormField(
                controller: _employeeCtrl,
                decoration: const InputDecoration(labelText: 'Employee'),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter the employee name'
                    : null,
              )
            else
              DropdownButtonFormField<String>(
                items: [
                  const DropdownMenuItem(
                    value: 'select',
                    child: Text('Select employee'),
                  ),
                  ...employees.map((e) => DropdownMenuItem(
                        value: e['id'] as String,
                        child: Text(e['name'] as String),
                      )),
                ],
                decoration: const InputDecoration(labelText: 'Employee'),
                validator: (v) =>
                    v == null || v == 'select' ? 'Select an employee' : null,
                onChanged: (v) {
                  setState(() {
                    if (v == null || v == 'select') {
                      _employeeId = null;
                      _employeeName = null;
                    } else {
                      _employeeId = v;
                      final sel = employees.firstWhere((e) => e['id'] == v);
                      _employeeName = sel['name'] as String;
                    }
                  });
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
