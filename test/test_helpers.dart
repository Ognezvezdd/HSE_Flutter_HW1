import 'package:flutter_test/flutter_test.dart';

// Image codecs run outside the fake test clock. Yield a real frame between
// pumps so decoding can finish before testing the resulting interactions.
Future<void> settle(WidgetTester tester) async {
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    do {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      if (!tester.binding.hasScheduledFrame) return;
    } while (DateTime.now().isBefore(deadline));
    fail('The screen did not settle within five seconds');
  });
}
