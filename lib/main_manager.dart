import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/services_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/wash_history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/subscription_screen.dart';
import 'data/settings.dart';
import 'services/billing_service.dart';
import 'services/bookkeeping_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/manager_auth.dart';
import 'services/supabase_backend.dart';
import 'screens/bookkeeping_screen.dart';
import 'widgets/manager_access_gate.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        unawaited(
          SupabaseBackend.instance.recordAppError(
            severity: 'error',
            context: 'flutter_error',
            error: details.exception,
            stackTrace: details.stack,
            rawPayload: {
              'library': details.library,
              'context': details.context?.toDescription(),
            },
          ),
        );
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        unawaited(
          SupabaseBackend.instance.recordAppError(
            severity: 'fatal',
            context: 'platform_dispatcher',
            error: error,
            stackTrace: stack,
          ),
        );
        return false;
      };

      await AppSettings.instance.load();
      await SupabaseBackend.instance.bootstrap();
      await ManagerAuth.instance.bootstrap();

      runApp(const ManagerApp());

      BillingService.instance.start();
      unawaited(CloudBackupService.instance.bootstrap());
      unawaited(BookkeepingService.instance.bootstrap());
    },
    (error, stackTrace) {
      unawaited(
        SupabaseBackend.instance.recordAppError(
          severity: 'fatal',
          context: 'run_zoned_guarded',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
  );
}

class ManagerApp extends StatelessWidget {
  const ManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WashDesk',
      theme: buildTheme(),
      initialRoute: managerInitialRoute(),
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/sign-up': (_) => const SignUpScreen(nextRoute: '/'),
        '/sign-in': (_) => const SignInScreen(nextRoute: '/'),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/terms': (_) => const TermsOfServiceScreen(),
        '/subscription': (_) => const SubscriptionScreen(),
        '/': (_) => const RequireManagerAccess(child: DashboardScreen()),
        '/record-wash': (_) => const RequireManagerAccess(
              child: BookingsScreen(openWalkInOnStart: true),
            ),
        '/bookings': (_) => const RequireManagerAccess(child: BookingsScreen()),
        '/expenses': (_) =>
            const RequireManagerAccess(child: BookkeepingScreen()),
        '/employees': (_) =>
            const RequireManagerAccess(child: EmployeesScreen()),
        '/services': (_) => const RequireManagerAccess(child: ServicesScreen()),
        '/reports': (_) => const RequireManagerAccess(child: ReportsScreen()),
        '/wash-history': (_) =>
            const RequireManagerAccess(child: WashHistoryScreen()),
        '/bookkeeping': (_) =>
            const RequireManagerAccess(child: BookkeepingScreen()),
        '/loyalty': (_) => const RequireManagerAccess(child: LoyaltyScreen()),
        '/settings': (_) => const RequireManagerAccess(child: SettingsScreen()),
      },
    );
  }
}
