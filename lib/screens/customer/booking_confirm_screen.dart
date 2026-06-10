import 'package:flutter/material.dart';
import '../../widgets/app_background.dart';
import '../../widgets/customer_nav.dart';

class BookingConfirmScreen extends StatelessWidget {
  const BookingConfirmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, Object?>;
    final code = args['code'] as String;
    final appt = args['appt'] as DateTime;
    final carwash = args['carwash'] as Map<String, Object?>;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: const Text('Booking Confirmed')),
      body: Stack(
        children: [
          const AppBackground(),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 24, 18, 150),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context)
                                .colorScheme
                                .primaryContainer
                                .withValues(alpha: 0.9),
                            Theme.of(context)
                                .colorScheme
                                .secondaryContainer
                                .withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                              blurRadius: 26,
                              offset: const Offset(0, 16),
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(Icons.celebration_rounded,
                                color: Theme.of(context).colorScheme.primary,
                                size: 30),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Booking confirmed',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 6),
                                Text(
                                  'Show this code when you arrive. We\'ll keep you updated.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer
                                              .withValues(alpha: 0.8)),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface
                                        .withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    code,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                            letterSpacing: 1.5,
                                            fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(carwash['name'] as String),
                        subtitle: Text(carwash['address'] as String? ?? ''),
                        trailing: Chip(
                          avatar: const Icon(Icons.pin_drop, size: 18),
                          label: Text(carwash['code']?.toString() ?? 'CW'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.schedule),
                        title: const Text('Appointment'),
                        subtitle: Text(appt.toString().substring(0, 16)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.bolt_outlined),
                        title: Text('Next step'),
                        subtitle: Text(
                            'Tap below to track status or share your code with the wash bay.'),
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushReplacementNamed(
                        context,
                        '/customer/track',
                        arguments: code,
                      ),
                      icon: const Icon(Icons.local_shipping),
                      label: const Text('Track your wash'),
                    ),
                  ])),
        ],
      ),
      bottomNavigationBar: const CustomerNav(currentIndex: 1),
    );
  }
}
