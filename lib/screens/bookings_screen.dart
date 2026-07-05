import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../data/settings.dart';
import '../services/bookkeeping_service.dart';
import '../services/loyalty_service.dart';
import '../utils/booking_code.dart';
import '../utils/format.dart';
import '../utils/vehicle_details.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/wd_kit.dart';

class BookingsScreen extends StatefulWidget {
  final bool openWalkInOnStart;

  const BookingsScreen({super.key, this.openWalkInOnStart = false});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _PlateLoyaltyNotice extends StatelessWidget {
  final PlateLoyaltyStatus status;

  const _PlateLoyaltyNotice({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasReward = status.availableRewards > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: hasReward
            ? scheme.primaryContainer
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasReward ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Icon(
            hasReward
                ? Icons.card_giftcard_rounded
                : Icons.local_car_wash_rounded,
            color:
                hasReward ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(
                color: hasReward
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingsScreenState extends State<BookingsScreen> {
  final _dateFmt = DateFormat('EEE, d MMM • HH:mm');
  bool _loading = true;
  List<Map<String, Object?>> _rows = const [];
  String _filter = 'active';
  bool _openedInitialWalkIn = false;

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.openWalkInOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _openedInitialWalkIn) return;
        _openedInitialWalkIn = true;
        _showWalkInForm();
      });
    }
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final now = DateTime.now();
    final startToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endToday =
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch;
    final rows = await d.rawQuery('''
      SELECT b.*, c.name AS carwash_name, c.code AS carwash_code
      FROM bookings b
      LEFT JOIN carwashes c ON c.id = b.carwash_id
      WHERE b.appt_ts >= ? AND b.appt_ts < ?
      ORDER BY b.appt_ts ASC, b.ts_created ASC
    ''', [startToday, endToday]);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  List<Map<String, Object?>> get _filteredRows {
    const active = {'pending', 'confirmed', 'in_progress'};
    return _rows.where((row) {
      final status = row['status'] as String;
      switch (_filter) {
        case 'active':
          return active.contains(status);
        case 'completed':
          return status == 'completed';
        case 'cancelled':
          return status == 'cancelled';
        default:
          return true;
      }
    }).toList(growable: false);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color? _statusColor(String status, BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'pending':
        return scheme.secondaryContainer;
      case 'confirmed':
        return scheme.primaryContainer;
      case 'in_progress':
        return scheme.tertiaryContainer;
      case 'completed':
        return scheme.surfaceContainerHighest;
      case 'cancelled':
        return scheme.errorContainer;
      default:
        return null;
    }
  }

  String _sourceLabel(String source) {
    return source == 'walk_in' ? 'Walk-in' : 'App';
  }

  void _backToPreviousOrDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacementNamed(context, '/');
  }

  Map<String, String> _statusActions(String status) {
    return <String, String>{
      if (status != 'confirmed') 'confirmed': 'Mark confirmed',
      if (status != 'in_progress') 'in_progress': 'Start wash',
      if (status != 'completed') 'completed': 'Complete',
      if (status != 'cancelled') 'cancelled': 'Cancel',
    };
  }

  Future<void> _updateStatus(String id, String status) async {
    final d = await AppDb.instance.db;
    Map<String, Object?>? updatedRow;
    bool shouldRecordCompletion = false;

    await d.transaction((txn) async {
      await _ensureWashBookingSchema(txn);
      await _ensureWashVehicleSchema(txn);
      await _ensureBookingEmployeeSchema(txn);
      await _ensureBookingVehicleSchema(txn);
      final rows = await txn.query(
        'bookings',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final row = rows.first;
      final previousStatus = row['status'] as String;
      shouldRecordCompletion =
          status == 'completed' && previousStatus != 'completed';

      await txn.update(
        'bookings',
        {'status': status},
        where: 'id = ?',
        whereArgs: [id],
      );

      updatedRow = Map<String, Object?>.from(row)..['status'] = status;
      if (shouldRecordCompletion) {
        await _recordCompletedWash(txn, updatedRow!);
      }
    });

    if (updatedRow != null && shouldRecordCompletion) {
      await LoyaltyService.instance.recordPunchForBooking(updatedRow!);
    }
    await _load();
  }

  Future<void> _ensureWashBookingSchema(DatabaseExecutor db) async {
    try {
      await db.execute('ALTER TABLE washes ADD COLUMN booking_id TEXT;');
    } on DatabaseException catch (e) {
      if (!e.toString().toLowerCase().contains('duplicate column name')) {
        rethrow;
      }
    }
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_washes_booking ON washes(booking_id);',
    );
  }

  Future<void> _ensureWashVehicleSchema(DatabaseExecutor db) async {
    for (final column in ['vehicle', 'license_plate']) {
      try {
        await db.execute('ALTER TABLE washes ADD COLUMN $column TEXT;');
      } on DatabaseException catch (e) {
        if (!e.toString().toLowerCase().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
  }

  Future<void> _ensureBookingPaymentMethodSchema(DatabaseExecutor db) async {
    try {
      await db.execute(
        "ALTER TABLE bookings ADD COLUMN payment_method TEXT NOT NULL DEFAULT 'cash';",
      );
    } on DatabaseException catch (e) {
      if (!e.toString().toLowerCase().contains('duplicate column name')) {
        rethrow;
      }
    }
  }

  Future<void> _ensureBookingEmployeeSchema(DatabaseExecutor db) async {
    for (final column in ['employee_id', 'employee_name']) {
      try {
        await db.execute('ALTER TABLE bookings ADD COLUMN $column TEXT;');
      } on DatabaseException catch (e) {
        if (!e.toString().toLowerCase().contains('duplicate column name')) {
          rethrow;
        }
      }
    }
  }

  Future<void> _ensureBookingVehicleSchema(DatabaseExecutor db) async {
    try {
      await db.execute('ALTER TABLE bookings ADD COLUMN license_plate TEXT;');
    } on DatabaseException catch (e) {
      if (!e.toString().toLowerCase().contains('duplicate column name')) {
        rethrow;
      }
    }
  }

  Future<double> _resolveBookingPrice(
      DatabaseExecutor db, Map<String, Object?> bookingRow) async {
    final quoted = (bookingRow['price'] as num?)?.toDouble() ?? 0;
    if (quoted > 0) return quoted;

    final serviceName = (bookingRow['service'] as String?)?.trim();
    if (serviceName == null || serviceName.isEmpty) return 0;

    final serviceRows = await db.query(
      'services',
      columns: ['price'],
      where: 'name = ?',
      whereArgs: [serviceName],
      limit: 1,
    );
    if (serviceRows.isEmpty) return 0;
    return (serviceRows.first['price'] as num?)?.toDouble() ?? 0;
  }

  Future<void> _recordCompletedWash(
      DatabaseExecutor db, Map<String, Object?> bookingRow) async {
    final bookingId = bookingRow['id'] as String?;
    if (bookingId == null) return;

    final existing = await db.query(
      'washes',
      columns: ['id'],
      where: 'booking_id = ?',
      whereArgs: [bookingId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final price = await _resolveBookingPrice(db, bookingRow);
    if (price <= 0) return;

    final serviceName =
        (bookingRow['service'] as String?)?.trim().isNotEmpty ?? false
            ? (bookingRow['service'] as String).trim()
            : 'Walk-in wash';
    final apptTs =
        bookingRow['appt_ts'] as int? ?? DateTime.now().millisecondsSinceEpoch;
    final code = bookingRow['code'] as String?;
    final source = bookingRow['source'] as String? ?? 'app';
    final paymentMethod = (bookingRow['payment_method'] as String?) ?? 'cash';
    final bookingVehicle = (bookingRow['vehicle'] as String?)?.trim();
    final bookingPlate = (bookingRow['license_plate'] as String?)?.trim();
    final vehicleDetails =
        splitVehicleDetails(bookingRow['vehicle'] as String?);
    final hasSeparatePlate = bookingPlate != null && bookingPlate.isNotEmpty;
    final resolvedPlate = hasSeparatePlate
        ? bookingPlate.toUpperCase()
        : vehicleDetails.licensePlate;
    final resolvedVehicle =
        !hasSeparatePlate && vehicleDetails.licensePlate != null
            ? vehicleDetails.car
            : bookingVehicle;

    final washRow = <String, Object?>{
      'id': const Uuid().v4(),
      'booking_id': bookingId,
      'ts': apptTs,
      'service_id': null,
      'service_name': serviceName,
      'price': price,
      'payment_method': paymentMethod,
      'employee_id': bookingRow['employee_id'] as String?,
      'employee_name': bookingRow['employee_name'] as String?,
      'vehicle': resolvedVehicle?.isEmpty ?? true
          ? vehicleDetails.car
          : resolvedVehicle,
      'license_plate': resolvedPlate,
      'notes': 'Auto-completed booking'
          '${code == null ? '' : ' $code'}'
          ' • ${_sourceLabel(source)}',
    };
    await db.insert('washes', washRow);
    await BookkeepingService.instance.postWash(db, washRow);
  }

  Future<void> _showWalkInForm() async {
    final db = await AppDb.instance.db;
    final carwashes = await _carwashesForWalkIn(db);
    final services = await db.query('services', orderBy: 'name');
    final employees = await db.query('employees', orderBy: 'name');
    if (carwashes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not initialize a carwash location.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final phoneCtrl = TextEditingController();
    final vehicleCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final serviceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final employeeCtrl = TextEditingController();
    DateTime appt = DateTime.now();
    String carwashId = carwashes.first['id'] as String;
    String carwashCode = carwashes.first['code'] as String;
    String? serviceName;
    String paymentMethod = 'select';
    String? paymentError;
    String? employeeId;
    String? employeeName;
    PlateLoyaltyStatus? plateLoyaltyStatus;
    int plateLookupVersion = 0;

    // Speed up repeat entry: prefill payment method and employee from the
    // most recent walk-in, and auto-select the service when there's only one.
    try {
      final last = await db.query(
        'bookings',
        columns: ['payment_method', 'employee_id', 'employee_name'],
        where: "source = 'walk_in'",
        orderBy: 'ts_created DESC',
        limit: 1,
      );
      if (last.isNotEmpty) {
        final lastMethod = last.first['payment_method'] as String?;
        if (lastMethod == 'cash' || lastMethod == 'card') {
          paymentMethod = lastMethod!;
        }
        final lastEmployeeId = last.first['employee_id'] as String?;
        if (lastEmployeeId != null &&
            employees.any((e) => e['id'] == lastEmployeeId)) {
          employeeId = lastEmployeeId;
          employeeName = employees
              .firstWhere((e) => e['id'] == lastEmployeeId)['name'] as String?;
        }
      }
    } catch (_) {
      // Older databases may not have these columns yet; defaults are fine.
    }
    if (services.length == 1) {
      serviceName = services.first['name'] as String?;
      final price = (services.first['price'] as num?)?.toDouble();
      if (price != null) priceCtrl.text = price.toStringAsFixed(2);
    }

    Future<void> pickAppt() async {
      final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 30)),
        initialDate: appt,
      );
      if (date == null) return;
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(appt),
      );
      if (time == null) return;
      appt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    }

    Future<void> refreshPlateLoyalty(
      void Function(void Function()) setSheetState,
    ) async {
      final lookupId = ++plateLookupVersion;
      final status = await LoyaltyService.instance.plateStatus(
        plate: plateCtrl.text,
        carwashId: carwashId,
      );
      if (!mounted || lookupId != plateLookupVersion) return;
      setSheetState(() => plateLoyaltyStatus = status);
    }

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Form(
                key: formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: () => Navigator.of(ctx).pop(false),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Add walk-in booking',
                            style: Theme.of(ctx).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: carwashId,
                      decoration:
                          const InputDecoration(labelText: 'Carwash location'),
                      items: carwashes
                          .map(
                            (c) => DropdownMenuItem<String>(
                              value: c['id'] as String,
                              child: Text(c['name'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        final selected =
                            carwashes.firstWhere((c) => c['id'] == value);
                        setSheetState(() {
                          carwashId = value;
                          carwashCode = selected['code'] as String;
                        });
                        unawaited(refreshPlateLoyalty(setSheetState));
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Phone number'),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter phone'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: vehicleCtrl,
                      decoration: const InputDecoration(labelText: 'Car'),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the car'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: plateCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Number plate'),
                      textCapitalization: TextCapitalization.characters,
                      onChanged: (_) =>
                          unawaited(refreshPlateLoyalty(setSheetState)),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter the number plate'
                          : null,
                    ),
                    if (plateLoyaltyStatus != null) ...[
                      const SizedBox(height: 8),
                      _PlateLoyaltyNotice(status: plateLoyaltyStatus!),
                    ],
                    const SizedBox(height: 12),
                    if (services.isEmpty)
                      TextFormField(
                        controller: serviceCtrl,
                        decoration: const InputDecoration(labelText: 'Service'),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the service'
                            : null,
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: serviceName,
                        decoration: const InputDecoration(labelText: 'Service'),
                        items: services
                            .map(
                              (s) => DropdownMenuItem<String>(
                                value: s['name'] as String,
                                child: Text(
                                    '${s['name']} — ${money((s['price'] as num).toDouble())}'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setSheetState(() {
                            serviceName = value;
                            if (value != null) {
                              final svc = services
                                  .firstWhere((s) => s['name'] == value);
                              priceCtrl.text =
                                  ((svc['price'] as num).toDouble())
                                      .toStringAsFixed(2);
                            }
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Select a service' : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final value = double.tryParse(v?.trim() ?? '');
                        if (value == null || value <= 0) {
                          return 'Enter the price';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: paymentMethod,
                      decoration: InputDecoration(
                        labelText: 'Payment method',
                        errorText: paymentError,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'select',
                          child: Text('Select payment method'),
                        ),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'card', child: Text('Card')),
                      ],
                      onChanged: (value) {
                        setSheetState(() {
                          paymentMethod = value ?? 'select';
                          paymentError = null;
                        });
                      },
                      validator: (value) => value == null || value == 'select'
                          ? 'Select a payment method'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (employees.isEmpty)
                      TextFormField(
                        controller: employeeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Employee name',
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the employee name'
                            : null,
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: employeeId ?? 'none',
                        decoration:
                            const InputDecoration(labelText: 'Employee name'),
                        items: [
                          const DropdownMenuItem(
                            value: 'none',
                            child: Text('Select employee'),
                          ),
                          ...employees.map(
                            (employee) => DropdownMenuItem<String>(
                              value: employee['id'] as String,
                              child: Text(employee['name'] as String),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setSheetState(() {
                            if (value == null || value == 'none') {
                              employeeId = null;
                              employeeName = null;
                            } else {
                              employeeId = value;
                              final selected = employees.firstWhere(
                                (employee) => employee['id'] == value,
                              );
                              employeeName = selected['name'] as String;
                            }
                          });
                        },
                        validator: (value) => value == null || value == 'none'
                            ? 'Select an employee'
                            : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await pickAppt();
                        setSheetState(() {});
                      },
                      icon: const Icon(Icons.schedule),
                      label: Text('Appointment: ${_dateFmt.format(appt)}'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final price = double.tryParse(priceCtrl.text.trim());
                        if (price == null || price <= 0) return;
                        await _createWalkIn(
                          db,
                          carwashId: carwashId,
                          carwashCode: carwashCode,
                          phone: phoneCtrl.text.trim(),
                          vehicle: vehicleCtrl.text.trim().isEmpty
                              ? null
                              : vehicleCtrl.text.trim(),
                          licensePlate: plateCtrl.text.trim().isEmpty
                              ? null
                              : plateCtrl.text.trim().toUpperCase(),
                          service: serviceName ?? serviceCtrl.text.trim(),
                          price: price,
                          paymentMethod: paymentMethod,
                          employeeId: employeeId,
                          employeeName: employeeName ??
                              (employeeCtrl.text.trim().isEmpty
                                  ? null
                                  : employeeCtrl.text.trim()),
                          appt: appt,
                          notes: notesCtrl.text.trim().isEmpty
                              ? null
                              : notesCtrl.text.trim(),
                        );
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop(true);
                      },
                      icon: const Icon(Icons.add_circle),
                      label: const Text('Save walk-in booking'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Walk-in booking added.')),
      );
    }
  }

  Future<List<Map<String, Object?>>> _carwashesForWalkIn(Database db) async {
    var carwashes = await db.query('carwashes', orderBy: 'name');
    if (carwashes.isNotEmpty) return carwashes;

    final fallbackName = AppSettings.instance.businessName.trim().isEmpty
        ? 'Main Carwash'
        : AppSettings.instance.businessName.trim();
    final fallbackId = const Uuid().v4();
    await db.insert('carwashes', {
      'id': fallbackId,
      'code': 'MAIN',
      'name': fallbackName,
      'lat': 0.0,
      'lng': 0.0,
      'address': 'Default location',
      'phone': '',
      'open_hours': '',
      'services_json': '[]',
    });

    carwashes = await db.query('carwashes', orderBy: 'name');
    return carwashes;
  }

  Future<void> _createWalkIn(
    Database db, {
    required String carwashId,
    required String carwashCode,
    required String phone,
    required String paymentMethod,
    required DateTime appt,
    String? vehicle,
    String? licensePlate,
    String? service,
    double? price,
    String? employeeId,
    String? employeeName,
    String? notes,
  }) async {
    await db.transaction((txn) async {
      await _ensureBookingPaymentMethodSchema(txn);
      await _ensureBookingEmployeeSchema(txn);
      await _ensureBookingVehicleSchema(txn);
      final normalizedPaymentMethod = paymentMethod == 'card' ? 'card' : 'cash';
      final id = const Uuid().v4();
      final now = DateTime.now();
      final code = await generateBookingCode(
        txn,
        carwashId: carwashId,
        carwashCode: carwashCode,
      );
      final customerId = await _customerIdForPhone(txn, phone);
      await txn.insert('bookings', {
        'id': id,
        'code': code,
        'carwash_id': carwashId,
        'ts_created': now.millisecondsSinceEpoch,
        'appt_ts': appt.millisecondsSinceEpoch,
        'customer_name': 'Walk-in customer',
        'phone': phone,
        'vehicle': vehicle,
        'license_plate': licensePlate,
        'service': service,
        'price': price,
        'payment_method': normalizedPaymentMethod,
        'employee_id': employeeId,
        'employee_name': employeeName,
        'status': 'pending',
        'notes': notes,
        'source': 'walk_in',
        'customer_id': customerId,
      });
    });
  }

  Future<String?> _customerIdForPhone(DatabaseExecutor db, String phone) async {
    final rows = await db.query(
      'customers',
      columns: ['id'],
      where: 'phone = ?',
      whereArgs: [phone.trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as String;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        leading: widget.openWalkInOnStart
            ? IconButton(
                tooltip: 'Back',
                onPressed: _backToPreviousOrDashboard,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: const Text('Today’s Bookings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'Loyalty rewards',
            onPressed: () => Navigator.pushNamed(context, '/loyalty'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Reload',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today’s queue is ordered by appointment time. Attend customers first-come-first-serve within the day.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Active'),
                      selected: _filter == 'active',
                      onSelected: (_) => setState(() => _filter = 'active'),
                    ),
                    ChoiceChip(
                      label: const Text('Completed'),
                      selected: _filter == 'completed',
                      onSelected: (_) => setState(() => _filter = 'completed'),
                    ),
                    ChoiceChip(
                      label: const Text('Cancelled'),
                      selected: _filter == 'cancelled',
                      onSelected: (_) => setState(() => _filter = 'cancelled'),
                    ),
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: filtered.isEmpty
                        ? ListView(
                            padding: const EdgeInsets.fromLTRB(16, 32, 16, 150),
                            children: [
                              const SizedBox(height: 40),
                              WdEmptyState(
                                icon: Icons.local_car_wash_rounded,
                                title: 'No bookings here yet',
                                message:
                                    'Walk-ins and customer bookings for today will show up in this list.',
                                actionLabel: 'Record a walk-in',
                                onAction: _showWalkInForm,
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 150),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              final id = row['id'] as String;
                              final status = row['status'] as String;
                              final actions = _statusActions(status);
                              final source = row['source'] as String? ?? 'app';
                              final appt = DateTime.fromMillisecondsSinceEpoch(
                                  row['appt_ts'] as int);
                              final created =
                                  DateTime.fromMillisecondsSinceEpoch(
                                      row['ts_created'] as int);
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(
                                    row['customer_name'] as String,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Chip(
                                            label: Text(_statusLabel(status)),
                                            backgroundColor:
                                                _statusColor(status, context),
                                            visualDensity:
                                                VisualDensity.compact,
                                          ),
                                          Text(
                                            'Source: ${_sourceLabel(source)}',
                                          ),
                                        ],
                                      ),
                                      if (row['service'] != null)
                                        Text(row['service'] as String),
                                      Text('Appt: ${_dateFmt.format(appt)}'),
                                      Text(
                                          'Received: ${_dateFmt.format(created)}'),
                                      if (row['price'] != null)
                                        Text(
                                            'Quoted: ${money((row['price'] as num).toDouble())}'),
                                    ],
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    tooltip: 'Update status',
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (value) =>
                                        _updateStatus(id, value),
                                    itemBuilder: (ctx) => actions.entries
                                        .map(
                                          (entry) => PopupMenuItem<String>(
                                            value: entry.key,
                                            child: Text(entry.value),
                                          ),
                                        )
                                        .toList(growable: false),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showWalkInForm,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Walk-in booking'),
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
