import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../widgets/app_background.dart';

class RoleScreen extends StatelessWidget {
  const RoleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          cs.primary,
                          cs.primary.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WashDesk',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: cs.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'A clean, minimal workspace for teams and customers.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color:
                                          cs.onPrimary.withValues(alpha: 0.9),
                                      height: 1.3,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              const Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeroChip(
                                      icon: Icons.insights, label: 'Stats'),
                                  _HeroChip(
                                      icon: Icons.calendar_today,
                                      label: 'Bookings'),
                                  _HeroChip(
                                      icon: Icons.local_florist,
                                      label: 'Loyalty'),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SvgPicture.asset(
                            'assets/illustrations/hero_detailing.svg',
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Choose your experience',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _RoleCard(
                    color: cs.primaryContainer,
                    iconColor: cs.onPrimaryContainer,
                    title: 'I manage a car wash',
                    subtitle:
                        'Record washes, manage staff, and keep an eye on cash flow.',
                    icon: Icons.storefront_rounded,
                    onTap: () => Navigator.pushNamed(context, '/'),
                  ),
                  const SizedBox(height: 14),
                  _RoleCard(
                    color: cs.secondaryContainer,
                    iconColor: cs.onSecondaryContainer,
                    title: 'I am a customer',
                    subtitle:
                        'Find trusted spots, pre-book slots, and collect rewards.',
                    icon: Icons.navigation_rounded,
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/customer',
                    ),
                  ),
                  const Spacer(),
                  Center(
                    child: Icon(
                      Icons.spa_rounded,
                      color: cs.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final Color color;
  final Color iconColor;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.color,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 10),
              color: Colors.black.withValues(alpha: 0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar:
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      label: Text(label),
      backgroundColor:
          Theme.of(context).colorScheme.surface.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }
}
