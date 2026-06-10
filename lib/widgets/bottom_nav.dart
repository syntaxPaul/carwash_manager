import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

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
                  _go(context, '/');
                  break;
                case 1:
                  _go(context, '/bookings');
                  break;
                case 2:
                  _go(context, '/bookkeeping');
                  break;
                case 3:
                  _go(context, '/services');
                  break;
                case 4:
                  _go(context, '/reports');
                  break;
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Bookings',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Books',
              ),
              NavigationDestination(
                icon: Icon(Icons.miscellaneous_services_outlined),
                selectedIcon: Icon(Icons.miscellaneous_services),
                label: 'Services',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights),
                label: 'Reports',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
