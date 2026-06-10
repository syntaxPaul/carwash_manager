import 'package:flutter/material.dart';

class CustomerNav extends StatelessWidget {
  final int currentIndex;
  const CustomerNav({super.key, required this.currentIndex});

  void _go(BuildContext context, String route) {
    if (ModalRoute.of(context)?.settings.name == route) return;
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const radius = Radius.circular(28);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: radius),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: radius),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) {
              switch (i) {
                case 0:
                  _go(context, '/customer');
                  break;
                case 1:
                  _go(context, '/customer/history');
                  break;
                case 2:
                  _go(context, '/customer/track');
                  break;
                case 3:
                  _go(context, '/customer/rewards');
                  break;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.person_pin_circle_outlined),
                selectedIcon: Icon(Icons.person_pin_circle),
                label: 'Find',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping),
                label: 'Track',
              ),
              NavigationDestination(
                icon: Icon(Icons.card_giftcard_outlined),
                selectedIcon: Icon(Icons.card_giftcard),
                label: 'Rewards',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
