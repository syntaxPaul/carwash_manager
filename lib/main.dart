import 'package:flutter/material.dart';
import 'dart:async';

import 'theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/bookings_screen.dart';
import 'screens/employees_screen.dart';
import 'screens/services_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/wash_history_screen.dart';
import 'screens/settings_screen.dart';
import 'data/settings.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/carwash_detail_screen.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/customer/booking_confirm_screen.dart';
import 'screens/customer/track_screen.dart';
import 'screens/customer/customer_history_screen.dart';
import 'screens/customer/customer_rewards_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/legal_screen.dart';
import 'screens/role_screen.dart';
import 'screens/loyalty_screen.dart';
import 'screens/subscription_screen.dart';
import 'services/customer_auth.dart';
import 'services/billing_service.dart';
import 'services/cloud_backup_service.dart';
import 'services/manager_auth.dart';
import 'services/supabase_backend.dart';
import 'services/bookkeeping_service.dart';
import 'screens/bookkeeping_screen.dart';
import 'widgets/manager_access_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());

  await AppSettings.instance.load();
  await SupabaseBackend.instance.bootstrap();
  await ManagerAuth.instance.bootstrap();
  BillingService.instance.start();
  unawaited(CloudBackupService.instance.bootstrap());
  unawaited(CustomerAuth.instance.bootstrap());
  unawaited(BookkeepingService.instance.bootstrap());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WashDesk',
      theme: buildTheme(),
      initialRoute: '/onboarding',
      routes: {
        '/onboarding': (_) => const OnboardingScreen(),
        '/sign-up': (_) => const SignUpScreen(nextRoute: '/role'),
        '/sign-in': (_) => const SignInScreen(nextRoute: '/role'),
        '/forgot-password': (_) => const ForgotPasswordScreen(),
        '/privacy': (_) => const PrivacyPolicyScreen(),
        '/terms': (_) => const TermsOfServiceScreen(),
        '/subscription': (_) => const SubscriptionScreen(),
        '/role': (_) => const RoleScreen(),
        '/': (_) => const RequireManagerAccess(child: DashboardScreen()),
        '/bookings': (_) => const RequireManagerAccess(child: BookingsScreen()),
        '/record-wash': (_) => const RequireManagerAccess(
              child: BookingsScreen(openWalkInOnStart: true),
            ),
        '/expenses': (_) =>
            const RequireManagerAccess(child: BookkeepingScreen()),
        '/employees': (_) =>
            const RequireManagerAccess(child: EmployeesScreen()),
        '/services': (_) => const RequireManagerAccess(child: ServicesScreen()),
        '/reports': (_) => const RequireManagerAccess(child: ReportsScreen()),
        '/wash-history': (_) =>
            const RequireManagerAccess(child: WashHistoryScreen()),
        '/settings': (_) => const RequireManagerAccess(child: SettingsScreen()),
        '/loyalty': (_) => const RequireManagerAccess(child: LoyaltyScreen()),
        '/bookkeeping': (_) =>
            const RequireManagerAccess(child: BookkeepingScreen()),
        // Customer side
        '/customer': (_) => const CustomerHomeScreen(),
        '/customer/history': (_) => const CustomerHistoryScreen(),
        '/customer/carwash': (_) => const CarwashDetailScreen(),
        '/customer/book': (_) => const BookingScreen(),
        '/customer/confirm': (_) => const BookingConfirmScreen(),
        '/customer/track': (_) => const TrackScreen(),
        '/customer/rewards': (_) => const CustomerRewardsScreen(),
      },
    );
  }
}
