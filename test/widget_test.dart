import 'package:flutter_test/flutter_test.dart';

import 'package:carwash_manager/main.dart';

void main() {
  testWidgets('Onboarding screen loads by default', (tester) async {
    await tester.pumpWidget(const App());

    expect(find.text('Less paperwork. More paid washes.'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
