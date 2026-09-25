import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:antigravity_mobile/app.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('Antigravity Mobile Smoke Test - App renders Dashboard',
      (WidgetTester tester) async {
    // Wrap inside ProviderScope
    await tester.pumpWidget(
      const ProviderScope(
        child: AntigravityMobileApp(),
      ),
    );

    // Initial pump and wait for Splash transition
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump(const Duration(milliseconds: 200));

    // Verify Antigravity Branding header
    expect(find.text('ANTIGRAVITY'), findsOneWidget);
    expect(find.text('MOBILE CONTROL CENTER'), findsOneWidget);

    // Verify Bottom Navigation Items
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Verify PC Status section
    expect(find.text('ACTIVE SESSIONS'), findsOneWidget);
  });
}
