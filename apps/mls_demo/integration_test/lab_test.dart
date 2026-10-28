import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mls_demo/main.dart';

/// Run this on a simulator or phone: it uses the bundled target Rust library,
/// unlike a host widget test. Scroll before tapping on compact phone screens.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('real device completes Welcome, update, and removal', (
    tester,
  ) async {
    await tester.pumpWidget(const MlsLabApp());
    for (var step = 0; step < 5; step++) {
      final next = find.text('Run next step');
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Experiment complete'), findsOneWidget);
    expect(find.text('Bob cannot decrypt'), findsNWidgets(2));
    expect(find.text('Member · epoch 4'), findsNWidgets(2));
    await tester.ensureVisible(find.text('Reset lab'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset lab'));
    await tester.pumpAndSettle();
    expect(find.text('Invite Bob'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
