import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_mobile/main.dart' as app_main;

void main() {
  testWidgets('Test main() startup lifecycle', (tester) async {
    try {
      app_main.main();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 200));
    } catch (e, stack) {
      // ignore: avoid_print
      print('EXCEPTION IN MAIN STARTUP: $e');
      // ignore: avoid_print
      print(stack);
      rethrow;
    }
  });
}
