import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../models/loyalty_summary.dart';
import '../../services/customer_auth.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_login_card.dart';
import '../../widgets/customer_nav.dart';

class CustomerRewardsScreen extends StatefulWidget {
  const CustomerRewardsScreen({super.key});

  @override
  State<CustomerRewardsScreen> createState() => _CustomerRewardsScreenState();
}

class _CustomerRewardsScreenState extends State<CustomerRewardsScreen> {
  bool _loading = false;
  List<LoyaltySummary> _cards = const [];
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
      _cards = const [];
    });
    if (current != null) {
      _load();
    }
  }

  Future<void> _load() async {
    final customer = _customer;
    if (customer == null) return;
    setState(() => _loading = true);
    final cards =
        await LoyaltyService.instance.summariesForCustomer(customer.id);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _loading = false;
    });
  }

  Future<void> _redeem(LoyaltySummary summary) async {
    final customer = _customer;
    if (customer == null) return;
    try {
      await LoyaltyService.instance.redeemFreeWash(
        customerId: customer.id,
        carwashId: summary.carwashId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Free wash reserved at ${summary.carwashName}!')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Rewards & punch cards')),
      body: Stack(
        children: [
          const AppBackground(),
          if (_customer == null)
            ListView(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
              children: const [
                CustomerLoginCard(
                    title: 'Log in to collect punches and unlock free washes.'),
              ],
            )
          else
            RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
                children: [
                  _heroCard(context),
                  const SizedBox(height: 16),
                  if (_cards.isEmpty && !_loading)
                    const Text(
                        'Finish a wash at any partner to start filling your punch card!')
                  else
                    ..._cards.map(_buildPunchCard),
                  const SizedBox(height: 120),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 3),
    );
  }

  Widget _heroCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.9),
            cs.secondaryContainer.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
              blurRadius: 24,
              offset: const Offset(0, 14),
              color: cs.primary.withValues(alpha: 0.14)),
        ],
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
            child: Icon(Icons.card_giftcard, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wash 5 times • Get 1 free',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Every completed wash stamps your digital punch card. Earn five and we drop a free wash voucher.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                const Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      avatar: Icon(Icons.flash_on, size: 18),
                      label: Text('Auto‑applied'),
                    ),
                    Chip(
                      avatar: Icon(Icons.lock_open, size: 18),
                      label: Text('No stamps lost'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchCard(LoyaltySummary summary) {
    final filled = summary.punchSlotsFilled;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(summary.carwashName,
                    style: Theme.of(context).textTheme.titleMedium),
                if (summary.availableRewards > 0)
                  Chip(
                    avatar: const Icon(Icons.card_giftcard, size: 18),
                    label: Text('${summary.availableRewards} free'),
                  )
                else
                  Chip(
                    avatar: const Icon(Icons.loyalty, size: 18),
                    label: Text('${summary.punches} punches'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(summary.washesPerReward, (index) {
                final earned = index < filled;
                return CircleAvatar(
                  radius: 18,
                  backgroundColor:
                      earned ? scheme.primary : scheme.surfaceContainerHighest,
                  child: Icon(
                    earned
                        ? Icons.local_car_wash
                        : Icons.local_car_wash_outlined,
                    color: earned ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: summary.progressPercent,
                minHeight: 8,
                backgroundColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    '${summary.punchesTowardReward}/${summary.washesPerReward} punches towards next free wash'),
                if (summary.availableRewards > 0)
                  FilledButton.icon(
                    onPressed: () => _redeem(summary),
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text('Redeem'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => Navigator.pushNamed(context, '/customer'),
                    child: const Text('Book wash'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
