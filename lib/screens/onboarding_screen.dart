import 'package:flutter/material.dart';
import '../data/settings.dart';
import '../services/manager_auth.dart';
import '../utils/store_names.dart';
import '../widgets/app_background.dart';

const String appLogoAsset = 'assets/branding/app_logo.png';
const String appIconSourceAsset = 'assets/branding/app_icon.png';
const String landingHeroImageAsset = 'assets/branding/landing_carwash.jpg';
const String subscriptionPrice = 'R499.99';
const String trialOffer = '1-week free trial';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 50,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandHeader(),
                        const SizedBox(height: 18),
                        const _LandingHero(),
                        const SizedBox(height: 14),
                        const _PaperworkSolvedPanel(),
                        const SizedBox(height: 14),
                        const _FeatureGrid(),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/sign-up'),
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: const Text('Create account'),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activate your $storeName subscription after signup. New eligible accounts get a 1-week free trial, then $subscriptionPrice/month.',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () =>
                              Navigator.pushNamed(context, '/sign-in'),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('Sign in'),
                        ),
                        const SizedBox(height: 12),
                        const _LegalLinks(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  final String nextRoute;

  const SignUpScreen({super.key, this.nextRoute = '/role'});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _businessCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;
  bool _acceptedLegal = false;

  @override
  void dispose() {
    _businessCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_acceptedLegal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept the Terms and Privacy Policy to continue.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ManagerAuth.instance.register(
        businessName: _businessCtrl.text,
        ownerName: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      AppSettings.instance.businessName = _businessCtrl.text.trim();
      await AppSettings.instance.saveAll();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        widget.nextRoute,
        (_) => false,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not create the account. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create your account',
      subtitle:
          'Create your WashDesk account, then activate your $storeName subscription. Eligible new accounts get a 1-week free trial before billing starts.',
      footer: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/sign-in'),
        child: const Text('Already have an account? Sign in'),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _businessCtrl,
              decoration: const InputDecoration(
                labelText: 'Business name',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: _required('Enter your business name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: _required('Enter your name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 8) return 'Use at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 14),
            const _PlanPanel(compact: true),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _acceptedLegal,
              onChanged: (value) =>
                  setState(() => _acceptedLegal = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text('I agree to the Terms and Privacy Policy'),
              subtitle: const _LegalLinks(alignment: WrapAlignment.start),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignInScreen extends StatefulWidget {
  final String nextRoute;

  const SignInScreen({super.key, this.nextRoute = '/role'});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final account = await ManagerAuth.instance.login(
        email: _emailCtrl.text,
        password: _passwordCtrl.text,
      );
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        account.hasAccess ? widget.nextRoute : '/subscription',
        (_) => false,
      );
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign in. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to continue managing your wash bay.',
      footer: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/sign-up'),
        child: const Text('New here? Create an account'),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: _required('Enter your password'),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, '/forgot-password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _businessCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ManagerAuth.instance.resetPassword(
        email: _emailCtrl.text,
        businessName: _businessCtrl.text,
        newPassword: _passwordCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated. Sign in again.')),
      );
      Navigator.pushReplacementNamed(context, '/sign-in');
    } on StateError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Could not update the password. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Reset password',
      subtitle:
          'Confirm the business name linked to your WashDesk account, then choose a new password.',
      footer: TextButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/sign-in'),
        child: const Text('Back to sign in'),
      ),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _emailValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _businessCtrl,
              decoration: const InputDecoration(
                labelText: 'Business name',
                prefixIcon: Icon(Icons.storefront_rounded),
              ),
              textInputAction: TextInputAction.next,
              validator: _required('Enter your business name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(
                labelText: 'New password',
                prefixIcon: Icon(Icons.lock_reset_rounded),
              ),
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.length < 8) return 'Use at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: const Text('Update password'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget footer;

  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: Stack(
        children: [
          const AppBackground(),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
              children: [
                const _BrandHeader(centered: true),
                const SizedBox(height: 26),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                        color: cs.primary.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 20),
                      child,
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Center(child: footer),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final bool centered;

  const _BrandHeader({this.centered = false});

  @override
  Widget build(BuildContext context) {
    final logo = SizedBox(
      width: centered ? 260 : 190,
      height: 58,
      child: Image.asset(
        appLogoAsset,
        fit: BoxFit.contain,
        alignment: centered ? Alignment.center : Alignment.centerLeft,
        errorBuilder: (_, __, ___) => _LogoFallback(compact: !centered),
      ),
    );

    if (centered) return Center(child: logo);
    return Row(
      children: [
        Flexible(child: Align(alignment: Alignment.centerLeft, child: logo)),
        const SizedBox(width: 12),
        const _PriceChip(),
      ],
    );
  }
}

class _LogoFallback extends StatelessWidget {
  final bool compact;

  const _LogoFallback({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.local_car_wash_rounded, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            compact ? 'WD' : 'WashDesk',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

class _LandingHero extends StatelessWidget {
  const _LandingHero();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 430,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF071B3B),
            Color(0xFF0B5C8D),
            Color(0xFF0DA6D7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 34,
            offset: const Offset(0, 18),
            color: cs.primary.withValues(alpha: 0.18),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              landingHeroImageAsset,
              fit: BoxFit.cover,
              alignment: const Alignment(0.05, 0.42),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.18),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    _HeroBadge(
                      icon: Icons.auto_awesome_rounded,
                      label: trialOffer,
                    ),
                    Spacer(),
                    _HeroBadge(
                      icon: Icons.payments_outlined,
                      label: '$subscriptionPrice/mo',
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Text(
                  'Less paperwork. More paid washes.',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.02,
                      ),
                ),
                const SizedBox(height: 14),
                Text(
                  'WashDesk replaces notebooks, loose slips and end-of-day guesswork with one live record of every car, plate, service and employee.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.86),
                        height: 1.34,
                      ),
                ),
                const Spacer(),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _HeroProof(label: 'No paper slips'),
                    _HeroProof(label: 'Daily totals'),
                    _HeroProof(label: 'Staff accountability'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.17),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 17),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroProof extends StatelessWidget {
  final String label;

  const _HeroProof({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: const Color(0xFF08233A),
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _PaperworkSolvedPanel extends StatelessWidget {
  const _PaperworkSolvedPanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BeforeAfterBlock(
              icon: Icons.description_outlined,
              label: 'Before',
              title: 'Paper trails',
              body: 'Lost slips, missing plates, unclear staff records.',
              color: cs.error,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.arrow_forward_rounded, color: cs.primary),
          ),
          Expanded(
            child: _BeforeAfterBlock(
              icon: Icons.phone_iphone_rounded,
              label: 'After',
              title: 'Live records',
              body: 'Every wash captured, searchable and totalled.',
              color: cs.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BeforeAfterBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String title;
  final String body;
  final Color color;

  const _BeforeAfterBlock({
    required this.icon,
    required this.label,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.25,
              ),
        ),
      ],
    );
  }
}

class _PlanPanel extends StatelessWidget {
  final bool compact;

  const _PlanPanel({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: compact ? 0.92 : 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.workspace_premium_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? trialOffer : '$subscriptionPrice / month',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  compact
                      ? 'Then $subscriptionPrice/month'
                      : 'One business subscription',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceChip extends StatelessWidget {
  const _PriceChip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        trialOffer,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cs.onPrimaryContainer,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final features = [
      (Icons.event_available_rounded, 'Walk-ins booked'),
      (Icons.format_list_bulleted_rounded, 'Wash history'),
      (Icons.groups_rounded, 'Team tracked'),
      (Icons.insights_rounded, 'Totals ready'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: features
          .map(
            (item) => Container(
              width: (MediaQuery.sizeOf(context).width - 50) / 2,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.34),
                ),
              ),
              child: Row(
                children: [
                  Icon(item.$1, color: cs.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  final WrapAlignment alignment;

  const _LegalLinks({this.alignment = WrapAlignment.center});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/terms'),
          child: const Text('Terms'),
        ),
        Text(
          'and',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
        ),
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/privacy'),
          child: const Text('Privacy Policy'),
        ),
      ],
    );
  }
}

String? Function(String?) _required(String message) {
  return (value) {
    if (value == null || value.trim().isEmpty) return message;
    return null;
  };
}

String? _emailValidator(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Enter your email address';
  if (!text.contains('@') || !text.contains('.')) {
    return 'Enter a valid email address';
  }
  return null;
}
