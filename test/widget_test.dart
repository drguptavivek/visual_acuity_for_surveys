import 'package:flutter_test/flutter_test.dart';

import 'package:v_a_rpc/main.dart';

void main() {
  testWidgets('app builds the root visual acuity app', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const VisualAcuityApp());
    await tester.pump(const Duration(seconds: 3));

    expect(find.byType(VisualAcuityApp), findsOneWidget);
  });
}
