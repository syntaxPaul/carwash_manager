import 'package:flutter/material.dart';
import 'theme.dart';
import 'data/settings.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/carwash_detail_screen.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/customer/booking_confirm_screen.dart';
import 'screens/customer/track_screen.dart';
import 'screens/customer/customer_history_screen.dart';
import 'screens/customer/customer_rewards_screen.dart';
import 'screens/customer/customer_map_screen.dart';
import 'services/customer_auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();
  await CustomerAuth.instance.bootstrap();
  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WashDesk',
      theme: buildTheme(),
      initialRoute: '/customer',
      routes: {
        '/customer': (_) => const CustomerHomeScreen(),
        '/customer/history': (_) => const CustomerHistoryScreen(),
        '/customer/carwash': (_) => const CarwashDetailScreen(),
        '/customer/book': (_) => const BookingScreen(),
        '/customer/confirm': (_) => const BookingConfirmScreen(),
        '/customer/track': (_) => const TrackScreen(),
        '/customer/rewards': (_) => const CustomerRewardsScreen(),
        '/customer/map': (_) => const CustomerMapScreen(),
      },
    );
  }
}
