import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../data/db.dart';
import '../utils/format.dart';
import '../widgets/app_background.dart';
import '../widgets/bottom_nav.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  double todayIncome = 0;
  double monthIncome = 0;
  double monthExpenses = 0;

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
        'SELECT SUM(price) s FROM washes WHERE ts BETWEEN ? AND ?',
        [startToday, endToday]);
    final mi = await d.rawQuery(
        'SELECT SUM(price) s FROM washes WHERE ts BETWEEN ? AND ?',
        [startMonth, endMonth]);
    final me = await d.rawQuery(
        'SELECT SUM(amount) s FROM expenses WHERE ts BETWEEN ? AND ?',
        [startMonth, endMonth]);

    setState(() {
      todayIncome = (ti.first['s'] as num?)?.toDouble() ?? 0;
      monthIncome = (mi.first['s'] as num?)?.toDouble() ?? 0;
      monthExpenses = (me.first['s'] as num?)?.toDouble() ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 150),
              children: [
                _HeroSummary(
                  today: money(todayIncome),
                  monthIncome: money(monthIncome),
                  monthExpenses: money(monthExpenses),
                  onRecordTap: () =>
                      Navigator.pushNamed(context, '/record-wash')
                          .then((_) => _load()),
                ),
                const SizedBox(height: 18),
                GridView.count(
                  padding: EdgeInsets.zero,
                  primary: false,
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  children: [
                    _StatCard(
                      title: 'Today’s income',
                      value: money(todayIncome),
                      icon: Icons.today_rounded,
                      color: cs.primary,
                      caption: DateFormat.MMMd().format(DateTime.now()),
                    ),
                    _StatCard(
                      title: 'Monthly income',
                      value: money(monthIncome),
                      icon: Icons.trending_up_rounded,
                      color: cs.secondary,
                      caption: DateFormat.MMMM().format(DateTime.now()),
                    ),
                    _StatCard(
                      title: 'Monthly expenses',
                      value: money(monthExpenses),
                      icon: Icons.receipt_long_rounded,
                      color: cs.tertiary,
                      caption: 'All expense logs',
                    ),
                    _StatCard(
                      title: 'Net result',
                      value: money(monthIncome - monthExpenses),
                      icon: Icons.equalizer_rounded,
                      color: cs.primaryContainer,
                      caption: 'Income - expenses',
                      foreground: cs.onPrimaryContainer,
                    ),
                  ],
                ),
                Transform.translate(
                  offset: const Offset(0, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quick actions',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const spacing = 12.0;
                          final tileWidth =
                              (constraints.maxWidth - spacing) / 2;
                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              SizedBox(
                                width: tileWidth,
                                child: _ActionTile(
                                  icon: Icons.calendar_month,
                                  label: 'Bookings',
                                  color: cs.primary,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/bookings'),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _ActionTile(
                                  icon: Icons.people_alt_rounded,
                                  label: 'Team',
                                  color: cs.secondary,
                                  onTap: () => Navigator.pushNamed(
                                      context, '/employees'),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _ActionTile(
                                  icon: Icons.inventory_2_outlined,
                                  label: 'Services',
                                  color: cs.tertiary,
                                  onTap: () =>
                                      Navigator.pushNamed(context, '/services'),
                                ),
                              ),
                              SizedBox(
                                width: tileWidth,
                                child: _ActionTile(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: 'Bookkeeping',
                                  color: cs.primary.darken(0.08),
                                  onTap: () => Navigator.pushNamed(
                                      context, '/bookkeeping'),
                                ),
                              ),
                              SizedBox(
                                width: constraints.maxWidth,
                                child: _ActionTile(
                                  icon: Icons.format_list_bulleted,
                                  label: 'Wash history',
                                  color: cs.primary,
                                  wide: true,
                                  onTap: () => Navigator.pushNamed(
                                      context, '/wash-history'),
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
          ),
        ],
      ),
      bottomNavigationBar: const BottomNav(currentIndex: 0),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  final String today;
  final String monthIncome;
  final String monthExpenses;
  final VoidCallback onRecordTap;

  const _HeroSummary({
    required this.today,
    required this.monthIncome,
    required this.monthExpenses,
    required this.onRecordTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateLabel = DateFormat.MMMd().format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer.withValues(alpha: 0.9),
            cs.secondaryContainer.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 32,
            offset: const Offset(0, 18),
            color: cs.primary.withValues(alpha: 0.18),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArt = constraints.maxWidth > 330;
          return Stack(
            children: [
              if (showArt)
                Positioned(
                  right: -18,
                  top: -18,
                  child: Opacity(
                    opacity: 0.22,
                    child: SvgPicture.asset(
                      'assets/illustrations/hero_detailing.svg',
                      width: 150,
                      height: 150,
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Today',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color:
                                cs.onPrimaryContainer.withValues(alpha: 0.8)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 14,
                                color: cs.onPrimaryContainer
                                    .withValues(alpha: 0.8)),
                            const SizedBox(width: 6),
                            Text(
                              dateLabel,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                      color: cs.onPrimaryContainer
                                          .withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    today,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _HeroChip(
                            label: 'Month in',
                            value: monthIncome,
                            color: cs.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _HeroChip(
                            label: 'Month out',
                            value: monthExpenses,
                            color: cs.secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _RecordWashButton(onTap: onRecordTap),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RecordWashButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RecordWashButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 12),
              color: cs.primary.withValues(alpha: 0.18),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.local_car_wash_rounded,
                  color: cs.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record a wash',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Create today’s walk-in booking',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.arrow_forward_rounded, color: cs.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _HeroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: color.darken(0.1))),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final Color? foreground;

  const _StatCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foreground ?? Colors.white;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 12),
            color: color.withValues(alpha: 0.25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fg),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: fg.withValues(alpha: 0.85)),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: fg.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool wide;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        height: wide ? 76 : 88,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: cs.surface.withValues(alpha: 0.88),
          border: Border.all(color: color.withValues(alpha: 0.16)),
          boxShadow: [
            BoxShadow(
              blurRadius: 18,
              offset: const Offset(0, 10),
              color: color.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 23),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: wide ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}

extension _ColorDarken on Color {
  Color darken(double amount) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}
