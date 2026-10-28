import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mls_demo/main.dart';

void main() {
  for (final size in [const Size(1200, 1800), const Size(320, 700)]) {
    testWidgets('guided experiment and reset at ${size.width}px', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MlsLabApp());
      for (var i = 0; i < 5; i++) {
        await tester.ensureVisible(find.text('Run next step'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Run next step'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Experiment complete'), findsOneWidget);
      expect(find.text('Bob cannot decrypt'), findsNWidgets(2));
      await tester.ensureVisible(find.text('Reset lab'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset lab'));
      await tester.pumpAndSettle();
      expect(find.text('Invite Bob'), findsOneWidget);
    });
  }
}
