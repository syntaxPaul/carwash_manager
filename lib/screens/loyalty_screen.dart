import 'package:flutter/material.dart';

import '../services/loyalty_service.dart';
import '../widgets/bottom_nav.dart';

class LoyaltyScreen extends StatefulWidget {
  const LoyaltyScreen({super.key});

  @override
  State<LoyaltyScreen> createState() => _LoyaltyScreenState();
}

class _LoyaltyScreenState extends State<LoyaltyScreen> {
  bool _loading = true;
  List<Map<String, Object?>> _rows = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await LoyaltyService.instance.managerCarwashBreakdown();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  Future<void> _redeem(Map<String, Object?> row) async {
    final customerId = row['customer_id'] as String;
    final carwashId = row['carwash_id'] as String;
    try {
      await LoyaltyService.instance.redeemFreeWash(
        customerId: customerId,
        carwashId: carwashId,
        notes: 'Manager redeem',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Marked free wash redeemed for ${row['customer_name']}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Loyalty punch cards'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                        'No loyalty punches recorded yet. Complete a booking linked to a customer to start.'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      final punches = (row['punches'] as num).toInt();
                      final redemptions = (row['redemptions'] as num).toInt();
                      final unlocked = punches ~/ 5;
                      final available = unlocked - redemptions < 0
                          ? 0
                          : unlocked - redemptions;
                      final lastTs = row['last_ts'] as int?;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${index + 1}')),
                          title: Text(row['customer_name'] as String? ??
                              'Unknown customer'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(row['customer_phone'] as String? ?? ''),
                              Text('Carwash: ${row['carwash_name'] ?? 'N/A'}'),
                              Text(
                                  'Punches: $punches • Free washes unlocked: ${punches ~/ 5} • Redeemed: $redemptions'),
                              if (lastTs != null)
                                Text(
                                    'Last visit: ${DateTime.fromMillisecondsSinceEpoch(lastTs).toString().substring(0, 16)}'),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (available > 0)
                                FilledButton(
                                  onPressed: () => _redeem(row),
                                  child: Text('Redeem x$available'),
                                )
                              else
                                Text('${punches % 5}/5 to go'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: const BottomNav(currentIndex: 1),
    );
  }
}
