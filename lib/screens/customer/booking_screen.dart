import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../data/db.dart';
import '../../models/customer.dart';
import '../../models/vehicle.dart';
import '../../services/customer_auth.dart';
import '../../services/vehicle_service.dart';
import '../../utils/booking_code.dart';
import '../../utils/format.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_login_card.dart';
import '../../widgets/customer_nav.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final _form = GlobalKey<FormState>();
  String? _serviceName;
  double? _price;
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 2));
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  List<Vehicle> _vehicles = const [];
  Vehicle? _selectedVehicle;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final customer = CustomerAuth.instance.current;
    if (customer == null) return;
    final list = await VehicleService.instance.forCustomer(customer.id);
    if (!mounted) return;
    setState(() {
      _vehicles = list;
      if (_selectedVehicle == null && list.isNotEmpty) {
        _selectedVehicle = list.first;
        _vehicleCtrl.text =
            _formatVehicleText(list.first); // show in free text too
        if (_serviceName == null && list.first.preferredService != null) {
          _serviceName = list.first.preferredService;
        }
      }
    });
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDate: _dateTime,
    );
    if (d == null) return;
    if (!mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dateTime),
    );
    if (t == null) return;
    setState(
        () => _dateTime = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save(Map<String, Object?> carwash) async {
    if (!_form.currentState!.validate()) return;
    final customer = CustomerAuth.instance.current;
    if (customer == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Sign in to confirm bookings and earn rewards.')),
      );
      return;
    }
    final d = await AppDb.instance.db;
    final carwashId = carwash['id'] as String;
    final carwashCode = carwash['code'] as String;
    final now = DateTime.now();
    late String code;
    await d.transaction((txn) async {
      final id = const Uuid().v4();
      code = await generateBookingCode(
        txn,
        carwashId: carwashId,
        carwashCode: carwashCode,
      );
      await txn.insert('bookings', {
        'id': id,
        'code': code,
        'carwash_id': carwashId,
        'ts_created': now.millisecondsSinceEpoch,
        'appt_ts': _dateTime.millisecondsSinceEpoch,
        'customer_name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'vehicle': _vehicleCtrl.text.trim().isEmpty
            ? _selectedVehicle == null
                ? null
                : _formatVehicleText(_selectedVehicle!)
            : _vehicleCtrl.text.trim(),
        'service': _serviceName,
        'price': _price,
        'status': 'pending',
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'source': 'app',
        'customer_id': customer.id,
        'sync_status': 'pending_sync', // queued for server sync
      });
      // Link vehicle profile to this carwash and preferred service for future quick booking.
      if (_selectedVehicle != null) {
        await VehicleService.instance.upsert(
          id: _selectedVehicle!.id,
          customerId: customer.id,
          make: _selectedVehicle!.make,
          model: _selectedVehicle!.model,
          year: _selectedVehicle!.year,
          licensePlate: _selectedVehicle!.licensePlate,
          color: _selectedVehicle!.color,
          preferredService: _serviceName ?? _selectedVehicle!.preferredService,
          carwashId: carwashId,
        );
      }
    });

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/customer/confirm', arguments: {
      'code': code,
      'appt': _dateTime,
      'name': _nameCtrl.text.trim(),
      'carwash': carwash,
    });
  }

  @override
  Widget build(BuildContext context) {
    final m =
        ModalRoute.of(context)!.settings.arguments as Map<String, Object?>;
    final Map<String, Object?>? prefill = m['prefill'] as Map<String, Object?>?;
    if (prefill != null) {
      _applyPrefill(prefill);
    }
    final services = (json.decode(m['services_json'] as String) as List)
        .cast<Map<String, dynamic>>();
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Pre‑book a Wash')),
      body: Stack(
        children: [
          const AppBackground(),
          ValueListenableBuilder<Customer?>(
            valueListenable: CustomerAuth.instance.listenable,
            builder: (context, customer, _) {
              if (customer == null) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                  children: const [
                    CustomerLoginCard(
                      title:
                          'Please sign in to lock in your booking and loyalty perks.',
                    ),
                  ],
                );
              }
              _prefillCustomer(customer);
              return Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m['name'] as String,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(m['address'] as String? ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.place, size: 18),
                                  label: Text(m['code'] as String? ?? 'CW'),
                                ),
                                Chip(
                                  avatar: const Icon(Icons.schedule, size: 18),
                                  label: Text((m['open_hours'] as String?) ??
                                      'Hours not listed'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Choose service',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              items: services
                                  .map((s) => DropdownMenuItem<String>(
                                        value: s['name'] as String,
                                        child: Text(
                                            '${s['name']} — ${money((s['price'] as num).toDouble())}'),
                                      ))
                                  .toList(),
                              decoration: const InputDecoration(
                                  labelText: 'Select a package'),
                              onChanged: (v) {
                                setState(() {
                                  _serviceName = v;
                                  final sel = services
                                      .firstWhere((e) => e['name'] == v);
                                  _price = (sel['price'] as num).toDouble();
                                });
                              },
                              validator: (v) =>
                                  v == null ? 'Select a service' : null,
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _pickDateTime,
                              icon: const Icon(Icons.schedule),
                              label: Text(
                                  'Appointment: ${_dateTime.toString().substring(0, 16)}'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration:
                                  const InputDecoration(labelText: 'Your name'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your name'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                  labelText: 'Phone number'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter phone'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Vehicle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700)),
                                TextButton.icon(
                                  onPressed: _showAddVehicleSheet,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add vehicle'),
                                ),
                              ],
                            ),
                            DropdownButtonFormField<Vehicle>(
                              isExpanded: true,
                              initialValue: _selectedVehicle,
                              items: _vehicles
                                  .map((v) => DropdownMenuItem<Vehicle>(
                                        value: v,
                                        child: Text(_formatVehicleText(v)),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                setState(() {
                                  _selectedVehicle = v;
                                  if (v != null) {
                                    _vehicleCtrl.text = _formatVehicleText(v);
                                    if (v.preferredService != null) {
                                      _serviceName = v.preferredService;
                                    }
                                  }
                                });
                              },
                              hint: const Text('Select a saved vehicle'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _vehicleCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Vehicle / Plate (optional)'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _notesCtrl,
                              decoration: const InputDecoration(
                                  labelText: 'Notes (optional)'),
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _save(m),
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirm booking'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 0),
    );
  }

  void _prefillCustomer(Customer customer) {
    if (_nameCtrl.text.trim().isEmpty) {
      _nameCtrl.text = customer.name;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      _phoneCtrl.text = customer.phone;
    }
  }

  String _formatVehicleText(Vehicle v) {
    final parts = [
      v.make,
      v.model,
      v.year?.toString(),
      v.licensePlate,
    ].where((e) => e != null && e.toString().trim().isNotEmpty).toList();
    return parts.isEmpty ? 'Vehicle' : parts.join(' • ');
  }

  Future<void> _showAddVehicleSheet() async {
    final customer = CustomerAuth.instance.current;
    if (customer == null) return;
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final colorCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 12),
                Text('Save vehicle',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: makeCtrl,
                        decoration: const InputDecoration(labelText: 'Make'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Enter make' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: modelCtrl,
                        decoration: const InputDecoration(labelText: 'Model'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter model'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: yearCtrl,
                        decoration: const InputDecoration(labelText: 'Year'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: plateCtrl,
                        decoration:
                            const InputDecoration(labelText: 'License plate'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: colorCtrl,
                  decoration: const InputDecoration(labelText: 'Color'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: serviceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Preferred service (optional)'),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final year = int.tryParse(yearCtrl.text.trim());
                      await VehicleService.instance.upsert(
                        customerId: customer.id,
                        make: makeCtrl.text.trim(),
                        model: modelCtrl.text.trim(),
                        year: year,
                        licensePlate: plateCtrl.text.trim(),
                        color: colorCtrl.text.trim(),
                        preferredService: serviceCtrl.text.trim().isEmpty
                            ? null
                            : serviceCtrl.text.trim(),
                        carwashId: (ModalRoute.of(context)?.settings.arguments
                            as Map<String, Object?>)['id'] as String?,
                      );
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                      }
                      if (mounted) {
                        await _loadVehicles();
                      }
                    },
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Save vehicle'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyPrefill(Map<String, Object?> data) {
    if (data['customer_name'] is String && _nameCtrl.text.isEmpty) {
      _nameCtrl.text = data['customer_name'] as String;
    }
    if (data['phone'] is String && _phoneCtrl.text.isEmpty) {
      _phoneCtrl.text = data['phone'] as String;
    }
    if (data['vehicle'] is String && _vehicleCtrl.text.isEmpty) {
      _vehicleCtrl.text = data['vehicle'] as String;
    }
    if (data['service'] is String && _serviceName == null) {
      _serviceName = data['service'] as String;
    }
    if (data['appt_ts'] is int) {
      _dateTime = DateTime.fromMillisecondsSinceEpoch(data['appt_ts'] as int);
    }
  }
}
