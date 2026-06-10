import 'package:flutter/material.dart';

import '../widgets/app_background.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      updated: '11 May 2026',
      sections: [
        _LegalSection(
          heading: 'What WashDesk collects',
          body:
              'WashDesk stores the information needed to run a car wash: business details, owner name, email address, services, prices, bookings, wash history, vehicle details, number plates, employee names, expenses, reports and subscription status.',
        ),
        _LegalSection(
          heading: 'How the information is used',
          body:
              'This information is used to record washes, manage bookings, calculate daily totals, keep team records, support subscriptions and restore business data from backups.',
        ),
        _LegalSection(
          heading: 'Local storage and backups',
          body:
              'WashDesk is offline-first. Business records are stored on the device in a local database. If cloud backup is enabled, an encrypted connection is used to send a copy of the local database to the configured Supabase Storage bucket.',
        ),
        _LegalSection(
          heading: 'Payments',
          body:
              'Subscriptions are handled by the relevant app store payment system. WashDesk receives purchase status and product identifiers, but does not collect or store card numbers.',
        ),
        _LegalSection(
          heading: 'Sharing',
          body:
              'WashDesk does not sell personal information. Data may be processed by service providers used to operate the app, including app store billing and cloud backup infrastructure.',
        ),
        _LegalSection(
          heading: 'Your responsibility',
          body:
              'The car wash business is responsible for getting any required permission before recording customer vehicle details, employee names or business records in the app.',
        ),
        _LegalSection(
          heading: 'Retention and deletion',
          body:
              'Records remain on the device until they are deleted by the business or the app data is removed. Cloud backups remain until replaced or deleted from the configured cloud storage.',
        ),
        _LegalSection(
          heading: 'Contact',
          body:
              'For privacy requests, use the support contact listed on the App Store or Google Play listing for WashDesk.',
        ),
      ],
    );
  }
}

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms of Service',
      updated: '11 May 2026',
      sections: [
        _LegalSection(
          heading: 'Service',
          body:
              'WashDesk is a car wash management app for recording bookings, walk-ins, wash history, employees, services, expenses, reports and daily totals.',
        ),
        _LegalSection(
          heading: 'Trial and subscription',
          body:
              'New manager accounts include a 5-day free trial. Continued access requires the monthly WashDesk subscription, currently R499.99 per month, unless a different price is shown by the app store at checkout.',
        ),
        _LegalSection(
          heading: 'Billing and cancellation',
          body:
              'Billing, renewals, cancellations and refunds are handled by the app store account used to subscribe. Access may end if the subscription expires, is cancelled or cannot be renewed.',
        ),
        _LegalSection(
          heading: 'Business data',
          body:
              'The business is responsible for the accuracy of the information entered into WashDesk and for keeping suitable backups of important records.',
        ),
        _LegalSection(
          heading: 'Acceptable use',
          body:
              'Do not use WashDesk to store unlawful, misleading or harmful information. Do not attempt to interfere with the app, payment system or cloud backup service.',
        ),
        _LegalSection(
          heading: 'Reports and bookkeeping',
          body:
              'WashDesk reports are operational summaries. They are not legal, tax or accounting advice. The business should verify records before filing tax returns or making financial decisions.',
        ),
        _LegalSection(
          heading: 'Availability',
          body:
              'WashDesk is designed to work offline, but cloud backup, app store billing and some platform services depend on network access and third-party availability.',
        ),
        _LegalSection(
          heading: 'Changes',
          body:
              'These terms may be updated as WashDesk changes. Continued use of the app after an update means the business accepts the updated terms.',
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String updated;
  final List<_LegalSection> sections;

  const _LegalDocumentScreen({
    required this.title,
    required this.updated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Stack(
        children: [
          const AppBackground(),
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 38),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.42),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                      color: cs.primary.withValues(alpha: 0.08),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Last updated $updated',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 18),
                    for (final section in sections) ...[
                      Text(
                        section.heading,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        section.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              height: 1.45,
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 18),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;

  const _LegalSection({
    required this.heading,
    required this.body,
  });
}
