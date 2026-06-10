import 'package:flutter/material.dart';

import '../services/customer_auth.dart';

class CustomerLoginCard extends StatefulWidget {
  final String title;
  const CustomerLoginCard(
      {super.key,
      this.title = 'Create a profile to keep your history synced.'});

  @override
  State<CustomerLoginCard> createState() => _CustomerLoginCardState();
}

class _CustomerLoginCardState extends State<CustomerLoginCard> {
  final _loginForm = GlobalKey<FormState>();
  final _registerForm = GlobalKey<FormState>();
  final _loginPhoneCtrl = TextEditingController();
  final _loginPinCtrl = TextEditingController();
  final _regNameCtrl = TextEditingController();
  final _regPhoneCtrl = TextEditingController();
  final _regEmailCtrl = TextEditingController();
  final _regPinCtrl = TextEditingController();
  int _tab = 0; // 0 login, 1 register
  bool _loginLoading = false;
  bool _registerLoading = false;
  String? _loginError;
  String? _registerError;

  @override
  void dispose() {
    _loginPhoneCtrl.dispose();
    _loginPinCtrl.dispose();
    _regNameCtrl.dispose();
    _regPhoneCtrl.dispose();
    _regEmailCtrl.dispose();
    _regPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Sign in'),
                  selected: _tab == 0,
                  onSelected: (v) => setState(() => _tab = 0),
                ),
                ChoiceChip(
                  label: const Text('Create account'),
                  selected: _tab == 1,
                  onSelected: (v) => setState(() => _tab = 1),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _tab == 0
                  ? KeyedSubtree(
                      key: const ValueKey('login'),
                      child: _buildLoginForm(context))
                  : KeyedSubtree(
                      key: const ValueKey('register'),
                      child: _buildRegisterForm(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Form(
      key: _loginForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: (v) =>
                (v == null || v.trim().length < 8) ? 'Enter your phone' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _loginPinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration: const InputDecoration(labelText: '4-digit PIN'),
            validator: (v) =>
                (v == null || v.length != 4) ? 'Enter your PIN' : null,
          ),
          if (_loginError != null) ...[
            const SizedBox(height: 8),
            Text(_loginError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loginLoading ? null : _handleLogin,
            icon: _loginLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open),
            label: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterForm(BuildContext context) {
    return Form(
      key: _registerForm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _regNameCtrl,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                (v == null || v.trim().length < 3) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone number'),
            validator: (v) => (v == null || v.trim().length < 8)
                ? 'Enter a phone number'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _regPinCtrl,
            keyboardType: TextInputType.number,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Choose a 4-digit PIN'),
            validator: (v) =>
                (v == null || v.length != 4) ? 'PIN must be 4 digits' : null,
          ),
          if (_registerError != null) ...[
            const SizedBox(height: 8),
            Text(_registerError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _registerLoading ? null : _handleRegister,
            icon: _registerLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.person_add_alt_1),
            label: const Text('Create account'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_loginForm.currentState!.validate()) return;
    setState(() {
      _loginLoading = true;
      _loginError = null;
    });
    try {
      await CustomerAuth.instance.login(
        phone: _loginPhoneCtrl.text.trim(),
        pin: _loginPinCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed in successfully.')),
      );
    } catch (e) {
      setState(() => _loginError = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loginLoading = false);
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerForm.currentState!.validate()) return;
    setState(() {
      _registerLoading = true;
      _registerError = null;
    });
    try {
      await CustomerAuth.instance.register(
        name: _regNameCtrl.text,
        phone: _regPhoneCtrl.text,
        email: _regEmailCtrl.text,
        pin: _regPinCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome aboard! Account created.')),
      );
      setState(() => _tab = 0);
    } catch (e) {
      setState(() => _registerError = _friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _registerLoading = false);
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    final idx = message.indexOf(':');
    if (idx != -1 && idx + 1 < message.length) {
      return message.substring(idx + 1).trim();
    }
    return message;
  }
}
