import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mls_demo/main.dart';

/// Captures the real app and native MLS operations, with no mocked client state.
/// Use flutter drive with test_driver/screenshots.dart to save the PNG files.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture README phone screenshots', (tester) async {
    await tester.pumpWidget(const MlsLabApp());
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('phone-overview');
    for (var step = 0; step < 5; step++) {
      await tester.ensureVisible(find.text('Run next step'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run next step'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    expect(find.text('Bob cannot decrypt'), findsNWidgets(2));
    await Scrollable.ensureVisible(
      tester.element(find.text('Experiment complete')),
      alignment: 0.12,
    );
    await tester.pumpAndSettle();
    await binding.takeScreenshot('phone-eviction');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
