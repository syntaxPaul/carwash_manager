import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/db.dart';
import '../data/settings.dart';
import '../services/loyalty_service.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/app_background.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/wd_kit.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double todayIncome = 0;
  double monthIncome = 0;
  double monthExpenses = 0;
  int todayWashes = 0;
  int loyaltyReady = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await AppDb.instance.db;
    final now = DateTime.now();
    final startToday =
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final endToday = DateTime(now.year, now.month, now.day, 23, 59, 59)
        .millisecondsSinceEpoch;
    final startMonth = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    final endMonth =
        DateTime(now.year, now.month + 1, 0, 23, 59, 59).millisecondsSinceEpoch;

    final ti = await d.rawQuery(
        'SELECT SUM(price) s, COUNT(*) c FROM washes WHERE ts BETWEEN ? AND ?',
        [startToday, endToday]);
    final mi = await d.rawQuery(
        'SELECT SUM(price) s FROM washes WHERE ts BETWEEN ? AND ?',
        [startMonth, endMonth]);
    final me = await d.rawQuery(
        'SELECT SUM(amount) s FROM expenses WHERE ts BETWEEN ? AND ?',
        [startMonth, endMonth]);

    // Loyalty opportunity: plates holding unlocked, unredeemed free washes.
    int ready = 0;
    try {
      final rows = await LoyaltyService.instance.managerCarwashBreakdown();
      final perReward = AppSettings.instance.loyaltyWashesPerReward;
      if (perReward > 0) {
        for (final row in rows) {
          final punches = (row['punches'] as num?)?.toInt() ?? 0;
          final redemptions = (row['redemptions'] as num?)?.toInt() ?? 0;
          final available = (punches ~/ perReward) - redemptions;
          if (available > 0) ready += available;
        }
      }
    } catch (_) {
      // Loyalty tables may not exist yet on first run — nudge simply hides.
    }

    if (!mounted) return;
    setState(() {
      todayIncome = (ti.first['s'] as num?)?.toDouble() ?? 0;
      todayWashes = (ti.first['c'] as num?)?.toInt() ?? 0;
      monthIncome = (mi.first['s'] as num?)?.toDouble() ?? 0;
      monthExpenses = (me.first['s'] as num?)?.toDouble() ?? 0;
      loyaltyReady = ready;
    });
  }

  void _go(String route) =>
      Navigator.pushNamed(context, route).then((_) => _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Dashboard')),
      body: Stack(
        children: [
          const AppBackground(),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, Wd.s2, 18, 150),
              children: [
                _HeroCard(
                  todayIncome: todayIncome,
                  todayWashes: todayWashes,
                  monthIn: monthIncome,
                  monthOut: monthExpenses,
                  onRecord: () => _go('/record-wash'),
                ),
                if (loyaltyReady > 0) ...[
                  const SizedBox(height: Wd.s3),
                  WdNudgeCard(
                    icon: Icons.card_giftcard_rounded,
                    title: loyaltyReady == 1
                        ? '1 free wash ready to redeem'
                        : '$loyaltyReady free washes ready to redeem',
                    subtitle:
                        'Loyal customers have earned rewards — invite them back.',
                    onTap: () => _go('/loyalty'),
                  ),
                ],
                const SizedBox(height: Wd.s5),
                GridView.count(
                  padding: EdgeInsets.zero,
                  primary: false,
                  crossAxisCount: 2,
                  childAspectRatio: 1.18,
                  mainAxisSpacing: Wd.s3,
                  crossAxisSpacing: Wd.s3,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    WdStatCard(
                      label: 'Today’s income',
                      value: money(todayIncome),
                      icon: Icons.today_rounded,
                      caption: DateFormat.MMMd().format(DateTime.now()),
                    ),
                    WdStatCard(
                      label: 'Monthly income',
                      value: money(monthIncome),
                      icon: Icons.trending_up_rounded,
                      caption: DateFormat.MMMM().format(DateTime.now()),
                    ),
                    WdStatCard(
                      label: 'Monthly expenses',
                      value: money(monthExpenses),
                      icon: Icons.receipt_long_rounded,
                      caption: 'All expense logs',
                    ),
                    WdStatCard(
                      label: 'Net result',
                      value: money(monthIncome - monthExpenses),
                      icon: Icons.equalizer_rounded,
                      caption: 'Income − expenses',
                      emphasis: true,
                    ),
                  ],
                ),
                const SizedBox(height: Wd.s6),
                const WdSectionHeader('Quick actions'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = Wd.s3;
                    final tileWidth = (constraints.maxWidth - spacing) / 2;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        SizedBox(
                          width: tileWidth,
                          child: WdActionTile(
                            icon: Icons.calendar_month_rounded,
                            label: 'Bookings',
                            onTap: () => _go('/bookings'),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: WdActionTile(
                            icon: Icons.people_alt_rounded,
                            label: 'Team',
                            onTap: () => _go('/employees'),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: WdActionTile(
                            icon: Icons.local_car_wash_rounded,
                            label: 'Services',
                            onTap: () => _go('/services'),
                          ),
                        ),
                        SizedBox(
                          width: tileWidth,
                          child: WdActionTile(
                            icon: Icons.account_balance_wallet_rounded,
                            label: 'Bookkeeping',
                            onTap: () => _go('/bookkeeping'),
                          ),
                        ),
                        SizedBox(
                          width: constraints.maxWidth,
                          child: WdActionTile(
                            icon: Icons.format_list_bulleted_rounded,
                            label: 'Wash history',
                            onTap: () => _go('/wash-history'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}

/// Hero: today's figure front and centre, month in/out beneath, and the
/// single most important action — record a wash — as the primary CTA.
class _HeroCard extends StatelessWidget {
  final double todayIncome;
  final int todayWashes;
  final double monthIn;
  final double monthOut;
  final VoidCallback onRecord;

  const _HeroCard({
    required this.todayIncome,
    required this.todayWashes,
    required this.monthIn,
    required this.monthOut,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final quietDay = todayWashes == 0;

    return WdCard(
      padding: const EdgeInsets.all(Wd.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Today',
                    style: t.labelMedium?.copyWith(color: Wd.inkMuted)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Wd.s3, vertical: Wd.s1),
                decoration: BoxDecoration(
                  color: Wd.primarySoft,
                  borderRadius: Wd.chipRadius,
                ),
                child: Text(
                  DateFormat.MMMd().format(DateTime.now()),
                  style: t.labelMedium?.copyWith(color: Wd.primaryDeep),
                ),
              ),
            ],
          ),
          const SizedBox(height: Wd.s2),
          Text(
            money(todayIncome),
            style: t.displaySmall?.copyWith(fontFeatures: Wd.tabularFigures),
          ),
          const SizedBox(height: Wd.s1),
          Text(
            quietDay
                ? 'No washes yet — record the first one below.'
                : todayWashes == 1
                    ? '1 wash so far today'
                    : '$todayWashes washes so far today',
            style: t.bodySmall,
          ),
          const SizedBox(height: Wd.s4),
          Row(
            children: [
              Expanded(
                child: _MiniStat(label: 'Month in', value: money(monthIn)),
              ),
              const SizedBox(width: Wd.s3),
              Expanded(
                child: _MiniStat(label: 'Month out', value: money(monthOut)),
              ),
            ],
          ),
          const SizedBox(height: Wd.s4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRecord,
              icon: const Icon(Icons.local_car_wash_rounded, size: 20),
              label: const Text('Record a wash'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(Wd.s3),
      decoration: BoxDecoration(
        color: Wd.canvas,
        borderRadius: Wd.controlRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.labelSmall),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: t.titleMedium?.copyWith(fontFeatures: Wd.tabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}
