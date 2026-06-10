import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../data/db.dart';
import '../../models/customer.dart';
import '../../services/customer_auth.dart';
import '../../utils/format.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_login_card.dart';
import '../../widgets/customer_nav.dart';

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});

  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  static const int _cancelCutoffMinutes = 60;
  bool _loading = false;
  List<Map<String, Object?>> _rows = const [];
  Customer? _customer;
  late final ValueListenable<Customer?> _authListenable;

  @override
  void initState() {
    super.initState();
    _authListenable = CustomerAuth.instance.listenable;
    _customer = CustomerAuth.instance.current;
    _authListenable.addListener(_handleAuthChange);
    if (_customer != null) {
      _load();
    }
  }

  @override
  void dispose() {
    _authListenable.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    final current = CustomerAuth.instance.current;
    if (current?.id == _customer?.id) return;
    setState(() {
      _customer = current;
      _rows = const [];
    });
    if (current != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final customer = _customer;
    if (customer == null) return;
    setState(() => _loading = true);
    final db = await AppDb.instance.db;
    final rows = await db.rawQuery(
      '''
      SELECT b.*, c.name AS carwash_name, c.address AS carwash_address,
             c.phone AS carwash_phone, c.open_hours AS carwash_open,
             c.services_json AS services_json, c.code AS carwash_code,
             c.lat AS carwash_lat, c.lng AS carwash_lng
      FROM bookings b
      LEFT JOIN carwashes c ON c.id = b.carwash_id
      WHERE b.customer_id = ?
      ORDER BY b.appt_ts DESC
      ''',
      [customer.id],
    );
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('My wash history')),
      body: Stack(
        children: [
          const AppBackground(),
          if (_customer == null)
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
              children: const [
                CustomerLoginCard(
                  title:
                      'Sign in to see your bookings, rewards and free-wash streaks.',
                ),
              ],
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: _rows.isEmpty && !_loading
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                      children: [
                        _profileHeader(context),
                        const SizedBox(height: 24),
                        const Text(
                            'No washes recorded yet. Book your first wash to start building history.'),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                      children: [
                        _profileHeader(context),
                        const SizedBox(height: 16),
                        _visitedSummary(),
                        const SizedBox(height: 16),
                        ..._rows.map(_buildHistoryCard),
                        const SizedBox(height: 120),
                      ],
                    ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 1),
    );
  }

  Widget _profileHeader(BuildContext context) {
    final customer = _customer!;
    final cs = Theme.of(context).colorScheme;
    final completed =
        _rows.where((r) => r['status'] == 'completed').length.toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.9),
            cs.secondaryContainer.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: cs.primary.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 14)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
              radius: 28,
              backgroundColor: cs.surface,
              foregroundColor: cs.primary,
              child: Text(customer.name.isEmpty
                  ? '?'
                  : customer.name[0].toUpperCase())),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customer.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(customer.phone,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.local_car_wash, size: 18),
                      label: Text('${_rows.length} total'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.verified, size: 18),
                      label: Text('$completed completed'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            onPressed: () => CustomerAuth.instance.logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _visitedSummary() {
    final visited = <String>{};
    for (final row in _rows) {
      final name = row['carwash_name'] as String?;
      if (name != null && name.isNotEmpty) {
        visited.add(name);
      }
    }
    if (visited.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Car washes you visited',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visited
              .map(
                (name) => Chip(
                  avatar: const Icon(Icons.local_car_wash, size: 18),
                  label: Text(name),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, Object?> row) {
    final status = row['status'] as String;
    final appt = DateTime.fromMillisecondsSinceEpoch(row['appt_ts'] as int);
    final syncStatus = (row['sync_status'] as String?) ?? 'synced';
    final carwash = row['carwash_name'] as String? ?? 'Unknown carwash';
    final address = row['carwash_address'] as String? ?? '';
    final price = row['price'] as num?;
    final carwashArgs = {
      'id': row['carwash_id'],
      'name': carwash,
      'address': address,
      'phone': row['carwash_phone'],
      'open_hours': row['carwash_open'],
      'services_json': row['services_json'] ?? '[]',
      'code': row['carwash_code'] ?? 'CW',
      'lat': row['carwash_lat'],
      'lng': row['carwash_lng'],
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(carwash,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                _statusChip(status, Theme.of(context).colorScheme),
              ],
            ),
            const SizedBox(height: 6),
            Text(address,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                Text(appt.toString().substring(0, 16)),
              ],
            ),
            if (price != null) ...[
              const SizedBox(height: 6),
              Text('Quoted: ${money(price.toDouble())}'),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/customer/track',
                    arguments: row['code'] as String,
                  ),
                  icon: const Icon(Icons.local_shipping_outlined),
                  label: const Text('Track'),
                ),
                const SizedBox(width: 12),
                if (_canCancel(status, appt))
                  FilledButton.tonalIcon(
                    onPressed: () => _cancelBooking(row['id'] as String),
                    icon: const Icon(Icons.cancel_schedule_send),
                    label: const Text('Cancel'),
                  ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/customer/book',
                      arguments: {
                        ...carwashArgs,
                        'prefill': {
                          'customer_name': row['customer_name'],
                          'phone': row['phone'],
                          'vehicle': row['vehicle'],
                          'service': row['service'],
                          'appt_ts': DateTime.now()
                              .add(const Duration(hours: 2))
                              .millisecondsSinceEpoch,
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Rebook'),
                ),
              ],
            ),
            if (syncStatus != 'synced') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.sync_problem, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Sync pending',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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

  Widget _statusChip(String status, ColorScheme cs) {
    Color color;
    switch (status) {
      case 'pending':
        color = cs.tertiary;
        break;
      case 'confirmed':
        color = cs.primary;
        break;
      case 'in_progress':
        color = cs.secondary;
        break;
      case 'completed':
        color = cs.inversePrimary;
        break;
      case 'cancelled':
        color = cs.error;
        break;
      default:
        color = cs.onSurface;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  bool _canCancel(String status, DateTime appt) {
    final now = DateTime.now();
    final diff = appt.difference(now).inMinutes;
    return (status == 'pending' || status == 'confirmed') &&
        diff > _cancelCutoffMinutes;
  }

  Future<void> _cancelBooking(String id) async {
    final db = await AppDb.instance.db;
    await db.update(
      'bookings',
      {
        'status': 'cancelled',
        'sync_status': 'cancel_pending',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cancellation queued.')),
      );
    }
  }
}
