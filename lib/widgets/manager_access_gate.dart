import 'package:flutter/material.dart';

import '../services/manager_auth.dart';

class RequireManagerAccess extends StatelessWidget {
  final Widget child;

  const RequireManagerAccess({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ManagerAccount?>(
      valueListenable: ManagerAuth.instance.listenable,
      builder: (context, account, _) {
        if (account == null) {
          return const _RouteRedirect(route: '/onboarding');
        }
        if (!account.hasAccess) {
          return const _RouteRedirect(route: '/subscription');
        }
        return child;
      },
    );
  }
}

String managerInitialRoute({String signedInRoute = '/'}) {
  final account = ManagerAuth.instance.current;
  if (account == null) return '/onboarding';
  return account.hasAccess ? signedInRoute : '/subscription';
}

class _RouteRedirect extends StatefulWidget {
  final String route;

  const _RouteRedirect({required this.route});

  @override
  State<_RouteRedirect> createState() => _RouteRedirectState();
}

class _RouteRedirectState extends State<_RouteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, widget.route, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
