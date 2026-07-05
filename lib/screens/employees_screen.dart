import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../utils/format.dart';
import '../widgets/app_background.dart';
import '../widgets/wd_kit.dart';

enum _EmployeeStatsMode { today, singleDay, range }

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<Map<String, Object?>> items = [];
  List<_EmployeeWashStats> stats = [];
  _EmployeeStatsMode _mode = _EmployeeStatsMode.today;
  DateTime _selectedDate = DateTime.now();
  DateTime _rangeStart = DateTime.now();
  DateTime _rangeEnd = DateTime.now();
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final rows = await d.query('employees', orderBy: 'name ASC');
    if (!mounted) return;
    setState(() => items = rows);
    await _loadStats();
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

  DateTime get _periodStart {
    switch (_mode) {
      case _EmployeeStatsMode.today:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      case _EmployeeStatsMode.singleDay:
        return DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
        );
      case _EmployeeStatsMode.range:
        final start = _rangeStart.isBefore(_rangeEnd) ? _rangeStart : _rangeEnd;
        return DateTime(start.year, start.month, start.day);
    }
  }

  DateTime get _periodEnd {
    switch (_mode) {
      case _EmployeeStatsMode.today:
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day + 1);
      case _EmployeeStatsMode.singleDay:
        return DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day + 1,
        );
      case _EmployeeStatsMode.range:
        final end = _rangeStart.isAfter(_rangeEnd) ? _rangeStart : _rangeEnd;
        return DateTime(end.year, end.month, end.day + 1);
    }
  }

  String get _periodLabel {
    switch (_mode) {
      case _EmployeeStatsMode.today:
        return 'Today';
      case _EmployeeStatsMode.singleDay:
        return ymd(_selectedDate);
      case _EmployeeStatsMode.range:
        final start = _rangeStart.isBefore(_rangeEnd) ? _rangeStart : _rangeEnd;
        final end = _rangeStart.isAfter(_rangeEnd) ? _rangeStart : _rangeEnd;
        return '${ymd(start)} to ${ymd(end)}';
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final d = await AppDb.instance.db;
    final rows = await d.query(
      'washes',
      columns: ['employee_id', 'employee_name', 'price'],
      where: 'ts >= ? AND ts < ?',
      whereArgs: [
        _periodStart.millisecondsSinceEpoch,
        _periodEnd.millisecondsSinceEpoch,
      ],
      orderBy: 'ts DESC',
    );

    final byKey = <String, _EmployeeWashStats>{};
    final nameToKey = <String, String>{};
    for (final employee in items) {
      final id = employee['id'] as String;
      final name = employee['name'] as String;
      final key = 'id:$id';
      byKey[key] = _EmployeeWashStats(employeeId: id, name: name);
      nameToKey[_normalizeName(name)] = key;
    }

    for (final row in rows) {
      final employeeId = (row['employee_id'] as String?)?.trim();
      final employeeName = (row['employee_name'] as String?)?.trim();
      String key;
      String name;
      if (employeeId != null && employeeId.isNotEmpty) {
        key = 'id:$employeeId';
        name = employeeName == null || employeeName.isEmpty
            ? 'Unknown employee'
            : employeeName;
      } else if (employeeName != null && employeeName.isNotEmpty) {
        key = nameToKey[_normalizeName(employeeName)] ?? 'name:$employeeName';
        name = employeeName;
      } else {
        key = 'unassigned';
        name = 'Unassigned';
      }

      final stat = byKey.putIfAbsent(
        key,
        () => _EmployeeWashStats(employeeId: employeeId, name: name),
      );
      stat.count += 1;
      stat.revenue += ((row['price'] as num?) ?? 0).toDouble();
    }

    final sorted = byKey.values.toList()
      ..sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    if (!mounted) return;
    setState(() {
      stats = sorted;
      _loadingStats = false;
    });
  }

  String _normalizeName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<void> _pickSingleDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _mode = _EmployeeStatsMode.singleDay;
      _selectedDate = picked;
    });
    await _loadStats();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _rangeStart.isBefore(_rangeEnd) ? _rangeStart : _rangeEnd,
        end: _rangeStart.isAfter(_rangeEnd) ? _rangeStart : _rangeEnd,
      ),
    );
    if (picked == null) return;
    setState(() {
      _mode = _EmployeeStatsMode.range;
      _rangeStart = picked.start;
      _rangeEnd = picked.end;
    });
    await _loadStats();
  }

  Future<void> _setToday() async {
    setState(() => _mode = _EmployeeStatsMode.today);
    await _loadStats();
  }

  int get _totalCars => stats.fold(0, (sum, stat) => sum + stat.count);

  double get _totalRevenue => stats.fold(0, (sum, stat) => sum + stat.revenue);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
            children: [
              _StatsHeader(
                mode: _mode,
                periodLabel: _periodLabel,
                totalCars: _totalCars,
                totalRevenue: _totalRevenue,
                loading: _loadingStats,
                onToday: _setToday,
                onPickDate: _pickSingleDate,
                onPickRange: _pickRange,
              ),
              const SizedBox(height: 22),
              Text(
                'Team members',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                const WdEmptyState(
                  icon: Icons.people_alt_rounded,
                  title: 'No team members yet',
                  message:
                      'Add your team to track how many cars each person washes and who handled each booking.',
                )
              else
                ...items.map((m) {
                  final stat = stats.cast<_EmployeeWashStats?>().firstWhere(
                            (item) => item?.employeeId == m['id'],
                            orElse: () => null,
                          ) ??
                      _EmployeeWashStats(
                        employeeId: m['id'] as String,
                        name: m['name'] as String,
                      );
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.badge_rounded),
                      title: Text(m['name'] as String),
                      subtitle: Text((m['phone'] as String?)?.isNotEmpty == true
                          ? m['phone'] as String
                          : 'No phone number'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${stat.count}',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: colorScheme.primary),
                          ),
                          Text(
                            stat.count == 1 ? 'car' : 'cars',
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              if (stats.any((stat) => stat.employeeId == null)) ...[
                const SizedBox(height: 22),
                Text(
                  'Other wash records',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                ...stats
                    .where((stat) => stat.employeeId == null)
                    .map((stat) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.person_search_rounded),
                            title: Text(stat.name),
                            subtitle: Text(money(stat.revenue)),
                            trailing: Text(
                              '${stat.count} ${stat.count == 1 ? 'car' : 'cars'}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        )),
              ],
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add team member'),
      ),
    );
  }
}

class _EmployeeWashStats {
  _EmployeeWashStats({
    required this.employeeId,
    required this.name,
  });

  final String? employeeId;
  final String name;
  int count = 0;
  double revenue = 0;
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({
    required this.mode,
    required this.periodLabel,
    required this.totalCars,
    required this.totalRevenue,
    required this.loading,
    required this.onToday,
    required this.onPickDate,
    required this.onPickRange,
  });

  final _EmployeeStatsMode mode;
  final String periodLabel;
  final int totalCars;
  final double totalRevenue;
  final bool loading;
  final VoidCallback onToday;
  final VoidCallback onPickDate;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_car_wash_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee wash count',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        periodLabel,
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (loading)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: mode == _EmployeeStatsMode.today,
                  onSelected: (_) => onToday(),
                ),
                ChoiceChip(
                  label: const Text('Specific date'),
                  selected: mode == _EmployeeStatsMode.singleDay,
                  onSelected: (_) => onPickDate(),
                ),
                ChoiceChip(
                  label: const Text('Date range'),
                  selected: mode == _EmployeeStatsMode.range,
                  onSelected: (_) => onPickRange(),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _MetricPill(
                    label: 'Cars washed',
                    value: '$totalCars',
                    icon: Icons.directions_car_filled_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricPill(
                    label: 'Wash income',
                    value: money(totalRevenue),
                    icon: Icons.payments_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
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
      title: const Text('Add team member'),
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
