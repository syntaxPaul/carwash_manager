import 'dart:async';
import 'package:flutter/material.dart';
import '../data/settings.dart';
import '../services/manager_auth.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _vatCtrl;
  late final TextEditingController _taxCtrl;
  late final TextEditingController _currencyCtrl;
  late final TextEditingController _loyaltyWashesCtrl;
  bool _includeVat = true;
  bool _autoClassifyExpenses = true;
  bool _autoPostTransactions = true;
  bool _autoMarkOverdue = true;
  bool _autoGenerateMonthlyClose = true;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.instance;
    _nameCtrl = TextEditingController(text: s.businessName);
    _vatCtrl = TextEditingController(text: s.vatReg);
    _taxCtrl =
        TextEditingController(text: (s.taxRate * 100).toStringAsFixed(2));
    _currencyCtrl = TextEditingController(text: s.currencySymbol);
    _loyaltyWashesCtrl =
        TextEditingController(text: s.loyaltyWashesPerReward.toString());
    _includeVat = s.pricesIncludeVat;
    _autoClassifyExpenses = s.autoClassifyExpenses;
    _autoPostTransactions = s.autoPostTransactions;
    _autoMarkOverdue = s.autoMarkOverdue;
    _autoGenerateMonthlyClose = s.autoGenerateMonthlyClose;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vatCtrl.dispose();
    _taxCtrl.dispose();
    _currencyCtrl.dispose();
    _loyaltyWashesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final s = AppSettings.instance;
    s.businessName =
        _nameCtrl.text.trim().isEmpty ? 'My Car Wash' : _nameCtrl.text.trim();
    s.vatReg = _vatCtrl.text.trim();
    s.taxRate = (double.tryParse(_taxCtrl.text.trim()) ?? 15) / 100.0;
    s.currencySymbol =
        _currencyCtrl.text.trim().isEmpty ? 'R' : _currencyCtrl.text.trim();
    s.pricesIncludeVat = _includeVat;
    s.loyaltyWashesPerReward =
        (int.tryParse(_loyaltyWashesCtrl.text.trim()) ?? 5).clamp(1, 99);
    s.autoClassifyExpenses = _autoClassifyExpenses;
    s.autoPostTransactions = _autoPostTransactions;
    s.autoMarkOverdue = _autoMarkOverdue;
    s.autoGenerateMonthlyClose = _autoGenerateMonthlyClose;
    await s.saveAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      setState(() {});
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _changePassword() async {
    final form = GlobalKey<FormState>();
    final currentCtrl = TextEditingController();
    final nextCtrl = TextEditingController();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Change password'),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                    obscureText: true,
                    validator: _required('Enter your current password'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: nextCtrl,
                    decoration: const InputDecoration(
                      labelText: 'New password',
                    ),
                    obscureText: true,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 8) return 'Use at least 8 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        },
      );
      if (confirmed != true) return;
      await ManagerAuth.instance.changePassword(
        currentPassword: currentCtrl.text,
        newPassword: nextCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      currentCtrl.dispose();
      nextCtrl.dispose();
    }
  }

  Future<void> _signOut() async {
    await ManagerAuth.instance.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (_) => false);
  }

  Future<void> _deleteAccount(ManagerAccount account) async {
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete WashDesk account?'),
          content: const Text(
            'This permanently deletes this manager account and the WashDesk '
            'business data stored on this device, including bookings, washes, '
            'customers, employees, services, expenses, reports and backups '
            'state. If cloud backup is configured, the cloud account and '
            'backup files are deleted too. This cannot be undone.\n\n'
            'Your App Store subscription is managed by Apple and must be '
            'cancelled from your Apple account if you no longer want it to '
            'renew.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
    if (firstConfirm != true || !mounted) return;

    final form = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    try {
      final finalConfirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Confirm deletion'),
            content: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type ${account.email} to permanently delete this account.',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Account email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    validator: (value) {
                      if ((value ?? '').trim().toLowerCase() !=
                          account.email.toLowerCase()) {
                        return 'Enter the signed-in account email.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () {
                  if (form.currentState!.validate()) {
                    Navigator.pop(context, true);
                  }
                },
                child: const Text('Delete account'),
              ),
            ],
          );
        },
      );
      if (finalConfirm != true || !mounted) return;

      setState(() => _deletingAccount = true);
      await ManagerAuth.instance.deleteCurrentAccount();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/onboarding', (_) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WashDesk account deleted')),
      );
    } on StateError catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Account deletion failed: $e');
    } finally {
      emailCtrl.dispose();
      if (mounted) setState(() => _deletingAccount = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 24, 18, 48),
          children: [
            const Text('Account',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ValueListenableBuilder<ManagerAccount?>(
              valueListenable: ManagerAuth.instance.listenable,
              builder: (context, account, _) {
                if (account == null) {
                  return const Text('No manager account is signed in.');
                }
                final status = account.isActive
                    ? 'Subscription active'
                    : account.hasAccess
                        ? '${account.trialDaysRemaining} trial day${account.trialDaysRemaining == 1 ? '' : 's'} left'
                        : 'Trial expired';
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.businessName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text('${account.ownerName} • ${account.email}'),
                        const SizedBox(height: 8),
                        Chip(label: Text(status)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _changePassword,
                                icon: const Icon(Icons.lock_reset_rounded),
                                label: const Text('Password'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _signOut,
                                icon: const Icon(Icons.logout_rounded),
                                label: const Text('Sign out'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error
                                    .withValues(alpha: 0.55),
                              ),
                            ),
                            onPressed: _deletingAccount
                                ? null
                                : () => _deleteAccount(account),
                            icon: _deletingAccount
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_forever_rounded),
                            label: Text(
                              _deletingAccount
                                  ? 'Deleting account'
                                  : 'Delete account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            const Text('Business',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _vatCtrl,
              decoration: const InputDecoration(
                  labelText: 'VAT reg. number (optional)'),
            ),
            const SizedBox(height: 16),
            const Text('Tax & Currency',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taxCtrl,
              decoration: const InputDecoration(labelText: 'Tax rate (%)'),
              keyboardType: TextInputType.number,
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0 || n > 100) {
                  return 'Enter a valid percentage';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _currencyCtrl,
              decoration: const InputDecoration(labelText: 'Currency symbol'),
              maxLength: 3,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Prices include tax (VAT)'),
              value: _includeVat,
              onChanged: (v) => setState(() => _includeVat = v),
            ),
            const SizedBox(height: 16),
            const Text('Loyalty',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _loyaltyWashesCtrl,
              decoration: const InputDecoration(
                labelText: 'Washes per free wash',
                helperText:
                    'Example: 5 means every 5 paid washes unlocks 1 free wash.',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final count = int.tryParse(value?.trim() ?? '');
                if (count == null || count < 1 || count > 99) {
                  return 'Enter a number from 1 to 99';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('Automation',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Auto classify expenses'),
              subtitle:
                  const Text('Use vendor/note rules to pick expense category'),
              value: _autoClassifyExpenses,
              onChanged: (v) => setState(() => _autoClassifyExpenses = v),
            ),
            SwitchListTile(
              title: const Text('Auto post transactions'),
              subtitle: const Text(
                  'Auto-create accounting entries for washes and expenses'),
              value: _autoPostTransactions,
              onChanged: (v) => setState(() => _autoPostTransactions = v),
            ),
            SwitchListTile(
              title: const Text('Auto mark overdue invoices/bills'),
              subtitle: const Text(
                  'Automatically update statuses by due date and balance'),
              value: _autoMarkOverdue,
              onChanged: (v) => setState(() => _autoMarkOverdue = v),
            ),
            SwitchListTile(
              title: const Text('Auto generate monthly close'),
              subtitle: const Text(
                  'Keep monthly profit, VAT and AR/AP snapshots up to date'),
              value: _autoGenerateMonthlyClose,
              onChanged: (v) => setState(() => _autoGenerateMonthlyClose = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            const SizedBox(height: 24),
            const Text('Legal', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/terms'),
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('Terms'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/privacy'),
                    icon: const Icon(Icons.privacy_tip_outlined),
                    label: const Text('Privacy'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String? Function(String?) _required(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}
