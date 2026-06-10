import 'package:flutter/material.dart';
import '../../data/db.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_nav.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _codeCtrl = TextEditingController();
  Map<String, Object?>? _booking;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arg = ModalRoute.of(context)!.settings.arguments;
    if (arg is String) {
      _codeCtrl.text = arg;
      _search();
    }
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    final d = await AppDb.instance.db;
    final rows = await d.query('bookings',
        where: 'code = ?', whereArgs: [code], limit: 1);
    setState(() => _booking = rows.isEmpty ? null : rows.first);
  }

  String _statusText(String s) {
    switch (s) {
      case 'pending':
        return 'Pending confirmation';
      case 'confirmed':
        return 'Confirmed';
      case 'in_progress':
        return 'In progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Track your Wash')),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
            children: [
              _heroBanner(context),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.2),
                        blurRadius: 16,
                        offset: const Offset(0, 10)),
                  ],
                ),
                child: TextField(
                  controller: _codeCtrl,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter booking code',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    suffixIcon: IconButton(
                      onPressed: _search,
                      icon: const Icon(Icons.search),
                    ),
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(height: 16),
              if (_booking == null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Waiting for a code',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        const Text(
                            'Paste your booking code from the confirmation screen to see live status.'),
                      ],
                    ),
                  ),
                )
              else ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Booking code',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                Text(_booking!['code'] as String,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2)),
                              ],
                            ),
                            _statusBadge(_booking!['status'] as String),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.schedule),
                            const SizedBox(width: 8),
                            Text(DateTime.fromMillisecondsSinceEpoch(
                                    _booking!['appt_ts'] as int)
                                .toString()
                                .substring(0, 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if ((_booking!['vehicle'] as String?) != null)
                          Row(
                            children: [
                              const Icon(Icons.directions_car),
                              const SizedBox(width: 8),
                              Text(_booking!['vehicle'] as String),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 2),
    );
  }

  Widget _heroBanner(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
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
      ),
      child: Row(
        children: [
          Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.local_shipping_rounded,
                  color: cs.primary, size: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Follow your wash',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Drop in a booking code to view status, appointment time, and vehicle details.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(status, cs);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, letterSpacing: 0.3),
      ),
    );
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'pending':
        return cs.tertiary;
      case 'confirmed':
        return cs.primary;
      case 'in_progress':
        return cs.secondary;
      case 'completed':
        return cs.inversePrimary;
      case 'cancelled':
        return cs.error;
      default:
        return cs.onSurface;
    }
  }
}
