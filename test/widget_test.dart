import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:v_a_rpc/main.dart';
import 'package:v_a_rpc/screens/near_brightness_calibration_screen.dart';

void main() {
  testWidgets('app builds the root visual acuity app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VisualAcuityApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(VisualAcuityApp), findsOneWidget);
  });

  testWidgets('distance brightness instruction screen explains 6/19 calibration', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: DistanceBrightnessInstructionScreen()),
    );

    expect(find.text('Before calibration'), findsOneWidget);
    expect(find.textContaining('6/19 E'), findsOneWidget);
    expect(find.text('Start Calibration'), findsOneWidget);
  });
}
