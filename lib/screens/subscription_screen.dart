import 'package:flutter/material.dart';

import '../services/billing_service.dart';
import '../services/manager_auth.dart';
import '../widgets/app_background.dart';

const String washDeskSubscriptionTitle = 'WashDesk Monthly Subscription';
const String washDeskSubscriptionPeriod = '1 month';
const String washDeskSubscriptionRenewal =
    'Auto-renewable subscription, billed every 1 month after the 1-week free trial unless cancelled.';
const String washDeskIncludedService =
    'Includes one car wash business workspace with bookings, walk-ins, wash '
    'history, employees, services, expenses, reports, daily totals and cloud '
    'backup when enabled.';
const String washDeskTermsUrl =
    'https://roim4ads.com/washdesk-terms-of-service';
const String washDeskPrivacyUrl =
    'https://roim4ads.com/washdesk-privacy-policy';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    BillingService.instance.start();
  }

  Future<void> _buyMonthly() async {
    try {
      await BillingService.instance.buyMonthly();
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  Future<void> _restorePurchases() async {
    await BillingService.instance.restorePurchases();
    if (!mounted) return;
    final account = ManagerAuth.instance.current;
    if (account?.hasAccess ?? false) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  Future<void> _signOut() async {
    await ManagerAuth.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription')),
      body: Stack(
        children: [
          const AppBackground(),
          ValueListenableBuilder<ManagerAccount?>(
            valueListenable: ManagerAuth.instance.listenable,
            builder: (context, account, _) {
              final title = account == null
                  ? 'Sign in to continue'
                  : washDeskSubscriptionTitle;
              final subtitle = account == null
                  ? 'Use your WashDesk account to manage subscription access.'
                  : account.hasAccess
                      ? 'Your WashDesk subscription is active.'
                      : 'Start the App Store subscription to unlock WashDesk. Eligible new accounts receive a 1-week free trial, then Apple bills the monthly price automatically unless cancelled.';

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 36),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.45),
                      ),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 30,
                          offset: const Offset(0, 16),
                          color: cs.primary.withValues(alpha: 0.1),
                        ),
                      ],
                    ),
                    child: AnimatedBuilder(
                      animation: BillingService.instance,
                      builder: (context, _) {
                        final billing = BillingService.instance;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              subtitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                            const SizedBox(height: 24),
                            const _RequiredSubscriptionSummary(),
                            const SizedBox(height: 14),
                            _PlanCard(account: account),
                            const SizedBox(height: 18),
                            if (account?.isActive ?? false)
                              FilledButton.icon(
                                onPressed: () =>
                                    Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  '/',
                                  (_) => false,
                                ),
                                icon: const Icon(Icons.dashboard_rounded),
                                label: const Text('Continue to dashboard'),
                              )
                            else
                              FilledButton.icon(
                                onPressed: account == null ||
                                        !billing.canPurchase ||
                                        billing.loading
                                    ? null
                                    : _buyMonthly,
                                icon: billing.purchasePending
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.lock_open_rounded),
                                label: Text(
                                  billing.purchasePending
                                      ? 'Waiting for store'
                                      : _subscribeLabel(billing),
                                ),
                              ),
                            if (account != null &&
                                !billing.purchasePending &&
                                !billing.loading &&
                                !billing.canPurchase) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: BillingService.instance.loadProducts,
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Load monthly plan'),
                              ),
                            ],
                            if (billing.loading) ...[
                              const SizedBox(height: 10),
                              const LinearProgressIndicator(),
                            ],
                            if (billing.message != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                billing.message!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed:
                                  account == null || billing.purchasePending
                                      ? null
                                      : _restorePurchases,
                              icon: const Icon(Icons.restore_rounded),
                              label: const Text('Restore purchase'),
                            ),
                            const SizedBox(height: 10),
                            const _SubscriptionLegalLinks(),
                            const SizedBox(height: 8),
                            Text(
                              'Subscriptions renew automatically every month '
                              'until cancelled in your Apple account settings.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (account != null) ...[
                    const SizedBox(height: 14),
                    TextButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  String _subscribeLabel(BillingService billing) {
    final price = billing.monthlyProduct?.price;
    if (price == null || price.trim().isEmpty) {
      return 'Start 1-week free trial';
    }
    return 'Start 1-week free trial, then $price / month';
  }
}

class _SubscriptionLegalLinks extends StatelessWidget {
  const _SubscriptionLegalLinks();

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Legal links',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Terms of Use (EULA): $washDeskTermsUrl',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.35,
              ),
        ),
        Text(
          'Privacy Policy: $washDeskPrivacyUrl',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: muted,
                height: 1.35,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/terms'),
              child: const Text('Open Terms of Use'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/privacy'),
              child: const Text('Open Privacy Policy'),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequiredSubscriptionSummary extends StatelessWidget {
  const _RequiredSubscriptionSummary();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final price = BillingService.instance.monthlyProduct?.price ??
        managerSubscriptionPrice;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.primary.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Subscription title',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(
            washDeskSubscriptionTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          const _SummaryLine(
            label: 'Length of subscription',
            value: washDeskSubscriptionPeriod,
          ),
          const _SummaryLine(
            label: 'Free trial',
            value: '1 week for eligible new subscribers, managed by Apple.',
          ),
          const _SummaryLine(
            label: 'Renewal',
            value: washDeskSubscriptionRenewal,
          ),
          const _SummaryLine(
            label: 'Services provided each subscription period',
            value: washDeskIncludedService,
          ),
          _SummaryLine(
            label: 'Price',
            value: '$price for each 1-month subscription period',
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                height: 1.35,
              ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final ManagerAccount? account;

  const _PlanCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isActive = account?.isActive ?? false;
    final product = BillingService.instance.monthlyProduct;
    final price = product?.price ?? managerSubscriptionPrice;
    final includes = product?.description.isNotEmpty == true
        ? product!.description
        : washDeskIncludedService;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_car_wash_rounded, color: cs.primary, size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  washDeskSubscriptionTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              if (isActive)
                Chip(
                  label: const Text('Active'),
                  visualDensity: VisualDensity.compact,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                ),
            ],
          ),
          const SizedBox(height: 14),
          const _PlanInfoRow(
            label: 'Length of subscription',
            value: washDeskSubscriptionPeriod,
          ),
          const _PlanInfoRow(
            label: 'Renewal',
            value: washDeskSubscriptionRenewal,
          ),
          _PlanInfoRow(
            label: 'Price',
            value: '$price per month',
          ),
          _PlanInfoRow(
            label: 'Price per unit',
            value: '$price for each 1-month subscription period',
          ),
          _PlanInfoRow(
            label: 'Included service',
            value: includes,
          ),
          const _PlanInfoRow(
            label: 'Trial',
            value:
                '1-week free trial for eligible new subscribers. Apple bills automatically after the trial unless cancelled.',
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            Text(
              'Subscription active for this business.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _PlanInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.35,
                ),
          ),
        ],
      ),
    );
  }
}
