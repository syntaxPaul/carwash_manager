import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../utils/format.dart';
import '../utils/vehicle_details.dart';
import '../widgets/app_background.dart';
import '../widgets/bottom_nav.dart';

enum _WashPeriod { day, week, month }

class WashHistoryScreen extends StatefulWidget {
  const WashHistoryScreen({super.key});

  @override
  State<WashHistoryScreen> createState() => _WashHistoryScreenState();
}

class _WashHistoryScreenState extends State<WashHistoryScreen> {
  final _dayLabel = DateFormat('EEE, d MMM yyyy');
  final _shortDay = DateFormat('d MMM');
  final _monthLabel = DateFormat('MMMM yyyy');
  final _timeLabel = DateFormat('HH:mm');
  final _weekdayLabel = DateFormat('EEEE, d MMM');

  _WashPeriod _period = _WashPeriod.day;
  DateTime _anchor = DateTime.now();
  bool _loading = true;
  List<Map<String, Object?>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  _PeriodRange get _range {
    final date = DateTime(_anchor.year, _anchor.month, _anchor.day);
    switch (_period) {
      case _WashPeriod.day:
        return _PeriodRange(
          date,
          date.add(const Duration(days: 1)),
          _dayLabel.format(date),
        );
      case _WashPeriod.week:
        final start = date.subtract(Duration(days: date.weekday - 1));
        final end = start.add(const Duration(days: 7));
        final inclusiveEnd = end.subtract(const Duration(days: 1));
        return _PeriodRange(
          start,
          end,
          '${_shortDay.format(start)} - ${_shortDay.format(inclusiveEnd)}',
        );
      case _WashPeriod.month:
        final start = DateTime(date.year, date.month, 1);
        return _PeriodRange(
          start,
          DateTime(date.year, date.month + 1, 1),
          _monthLabel.format(start),
        );
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = await AppDb.instance.db;
    final range = _range;
    final rows = await db.rawQuery(
      '''
      SELECT w.*, b.vehicle AS booking_vehicle,
             b.license_plate AS booking_license_plate,
             b.employee_name AS booking_employee_name
      FROM washes w
      LEFT JOIN bookings b ON b.id = w.booking_id
      WHERE w.ts >= ? AND w.ts < ?
      ORDER BY w.ts DESC
      ''',
      [range.start.millisecondsSinceEpoch, range.end.millisecondsSinceEpoch],
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  void _setPeriod(_WashPeriod period) {
    setState(() => _period = period);
    _load();
  }

  void _movePeriod(int amount) {
    setState(() {
      switch (_period) {
        case _WashPeriod.day:
          _anchor = _anchor.add(Duration(days: amount));
          break;
        case _WashPeriod.week:
          _anchor = _anchor.add(Duration(days: amount * 7));
          break;
        case _WashPeriod.month:
          _anchor = DateTime(_anchor.year, _anchor.month + amount, 1);
          break;
      }
    });
    _load();
  }

  VehicleDetails _vehicleDetails(Map<String, Object?> row) {
    final storedCar = _text(row['vehicle']);
    final storedPlate = _text(row['license_plate']);
    final bookingPlate = _text(row['booking_license_plate']);
    final bookingDetails = splitVehicleDetails(_text(row['booking_vehicle']));
    return VehicleDetails(
      car: storedCar ?? bookingDetails.car,
      licensePlate: storedPlate ?? bookingPlate ?? bookingDetails.licensePlate,
    );
  }

  String? _text(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  String _employee(Map<String, Object?> row) {
    return _text(row['employee_name']) ??
        _text(row['booking_employee_name']) ??
        'Not assigned';
  }

  double get _totalIncome => _rows.fold<double>(
        0,
        (sum, row) => sum + ((row['price'] as num?)?.toDouble() ?? 0),
      );

  double get _averageSale => _rows.isEmpty ? 0 : _totalIncome / _rows.length;

  Map<String, double> get _paymentTotals {
    final totals = <String, double>{};
    for (final row in _rows) {
      final method = (_text(row['payment_method']) ?? 'uncaptured')
          .toLowerCase()
          .replaceAll('_', ' ');
      final price = (row['price'] as num?)?.toDouble() ?? 0;
      totals.update(method, (value) => value + price, ifAbsent: () => price);
    }
    return Map.fromEntries(
      totals.entries.toList()
        ..sort((a, b) {
          const order = ['cash', 'card', 'eft', 'mobile', 'uncaptured'];
          final aIndex = order.indexOf(a.key);
          final bIndex = order.indexOf(b.key);
          if (aIndex != -1 || bIndex != -1) {
            return (aIndex == -1 ? 99 : aIndex)
                .compareTo(bIndex == -1 ? 99 : bIndex);
          }
          return a.key.compareTo(b.key);
        }),
    );
  }

  String get _periodName {
    switch (_period) {
      case _WashPeriod.day:
        return 'Day';
      case _WashPeriod.week:
        return 'Week';
      case _WashPeriod.month:
        return 'Month';
    }
  }

  bool _showDateHeader(int index) {
    if (index == 0) return true;
    final current =
        DateTime.fromMillisecondsSinceEpoch(_rows[index]['ts'] as int);
    final previous =
        DateTime.fromMillisecondsSinceEpoch(_rows[index - 1]['ts'] as int);
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  @override
  Widget build(BuildContext context) {
    final range = _range;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Wash History')),
      body: Stack(
        children: [
          const AppBackground(),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 154),
              itemCount: _loading || _rows.isEmpty ? 2 : _rows.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HistoryHeader(
                    period: _period,
                    periodName: _periodName,
                    rangeLabel: range.label,
                    washCount: _rows.length,
                    totalIncome: _totalIncome,
                    averageSale: _averageSale,
                    paymentTotals: _paymentTotals,
                    onPeriodChanged: _setPeriod,
                    onMovePeriod: _movePeriod,
                  );
                }

                if (_loading) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 90),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (_rows.isEmpty) {
                  return const _EmptyHistory();
                }

                final row = _rows[index - 1];
                final ts =
                    DateTime.fromMillisecondsSinceEpoch(row['ts'] as int);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_showDateHeader(index - 1))
                      _DateHeader(label: _weekdayLabel.format(ts)),
                    _WashCard(
                      row: row,
                      vehicle: _vehicleDetails(row),
                      timeLabel: _timeLabel,
                      employee: _employee(row),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 4),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final _WashPeriod period;
  final String periodName;
  final String rangeLabel;
  final int washCount;
  final double totalIncome;
  final double averageSale;
  final Map<String, double> paymentTotals;
  final ValueChanged<_WashPeriod> onPeriodChanged;
  final ValueChanged<int> onMovePeriod;

  const _HistoryHeader({
    required this.period,
    required this.periodName,
    required this.rangeLabel,
    required this.washCount,
    required this.totalIncome,
    required this.averageSale,
    required this.paymentTotals,
    required this.onPeriodChanged,
    required this.onMovePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final countText = washCount == 1 ? '1 wash' : '$washCount washes';

    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            blurRadius: 30,
            offset: const Offset(0, 18),
            color: cs.primary.withValues(alpha: 0.08),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop_outlined,
                  color: cs.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wash history',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    Text(
                      '$periodName view • $countText',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _TotalTile(
                label: 'Total income',
                value: money(totalIncome),
                icon: Icons.payments_outlined,
                emphasis: true,
              ),
              _TotalTile(
                label: 'Washes',
                value: '$washCount',
                icon: Icons.local_car_wash_outlined,
              ),
              _TotalTile(
                label: 'Average',
                value: money(averageSale),
                icon: Icons.trending_up_rounded,
              ),
            ],
          ),
          if (paymentTotals.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Payment totals',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: paymentTotals.entries
                  .map((entry) => _PaymentTotalPill(
                        label: entry.key,
                        value: entry.value,
                      ))
                  .toList(growable: false),
            ),
          ],
          const SizedBox(height: 20),
          SegmentedButton<_WashPeriod>(
            segments: const [
              ButtonSegment(value: _WashPeriod.day, label: Text('Day')),
              ButtonSegment(value: _WashPeriod.week, label: Text('Week')),
              ButtonSegment(value: _WashPeriod.month, label: Text('Month')),
            ],
            selected: {period},
            onSelectionChanged: (selection) => onPeriodChanged(selection.first),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Previous period',
                onPressed: () => onMovePeriod(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    rangeLabel,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Next period',
                onPressed: () => onMovePeriod(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool emphasis;

  const _TotalTile({
    required this.label,
    required this.value,
    required this.icon,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final background =
        emphasis ? cs.primaryContainer : cs.surfaceContainerHighest;
    final foreground = emphasis ? cs.onPrimaryContainer : cs.onSurfaceVariant;
    return Container(
      width: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background.withValues(alpha: emphasis ? 0.82 : 0.52),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: emphasis ? cs.onPrimaryContainer : cs.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTotalPill extends StatelessWidget {
  final String label;
  final double value;

  const _PaymentTotalPill({
    required this.label,
    required this.value,
  });

  String get _displayLabel {
    if (label == 'eft') return 'EFT';
    return label
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$_displayLabel ${money(value)}',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _WashCard extends StatelessWidget {
  final Map<String, Object?> row;
  final VehicleDetails vehicle;
  final DateFormat timeLabel;
  final String employee;

  const _WashCard({
    required this.row,
    required this.vehicle,
    required this.timeLabel,
    required this.employee,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ts = DateTime.fromMillisecondsSinceEpoch(row['ts'] as int);
    final service = row['service_name'] as String? ?? 'Service not captured';
    final price = (row['price'] as num?)?.toDouble() ?? 0;
    final payment = row['payment_method'] as String? ?? 'Payment not captured';
    final car = vehicle.car ?? 'Car not added';
    final plate = vehicle.licensePlate;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TimeBubble(label: timeLabel.format(ts)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    if (plate != null)
                      _PlatePill(plate: plate)
                    else
                      Text(
                        'No plate added',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                money(price),
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: cs.outlineVariant.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 16),
          _DetailLine(
            icon: Icons.local_car_wash_outlined,
            label: 'Service',
            value: service,
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.badge_outlined,
            label: 'Washed by',
            value: employee,
          ),
          const SizedBox(height: 12),
          _DetailLine(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Payment',
            value: payment.toUpperCase(),
          ),
        ],
      ),
    );
  }
}

class _PlatePill extends StatelessWidget {
  final String plate;

  const _PlatePill({required this.plate});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        plate.toUpperCase(),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimeBubble extends StatelessWidget {
  final String label;

  const _TimeBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 60,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 12),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Icon(Icons.local_car_wash_outlined, size: 42, color: cs.primary),
          const SizedBox(height: 14),
          Text(
            'No washes in this period',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Completed washes will appear here with the car, plate, service and employee.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PeriodRange {
  final DateTime start;
  final DateTime end;
  final String label;

  const _PeriodRange(this.start, this.end, this.label);
}
