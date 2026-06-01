import 'package:flutter_test/flutter_test.dart';
import 'package:v_a_rpc/utils/helpers.dart';

void main() {
  test(
    'near vision uses lower default screen brightness than distance tests',
    () {
      expect(defaultScreenBrightnessForVisionType('Presenting Near VA'), 0.5);
      expect(
        defaultScreenBrightnessForVisionType(
          'Near Corrected Visual Acuity (with Near Glasses)',
        ),
        0.5,
      );
      expect(defaultScreenBrightnessForVisionType('Unaided Near VA'), 0.5);
      expect(defaultScreenBrightnessForVisionType('Right eye - UVA'), 0.65);
    },
  );

  test('ambient light checks avoid aggressive polling during field use', () {
    expect(ambientLightCheckInterval, const Duration(seconds: 15));
  });

  test('distance vision brightness has its own calibration policy', () {
    expect(defaultDistanceScreenBrightnessPercent, 65);
    expect(normalizeDistanceScreenBrightnessPercent(45), 50);
    expect(normalizeDistanceScreenBrightnessPercent(85), 80);
    expect(normalizeDistanceScreenBrightnessPercent(70), 70);
  });

  test('presenting and unaided near VA use the near test track', () {
    expect(isNearVisionType('Presenting Near VA'), isTrue);
    expect(
      isNearVisionType('Near Corrected Visual Acuity (with Near Glasses)'),
      isTrue,
    );
    expect(isNearVisionType('Unaided Near VA'), isTrue);
    expect(isNearVisionType('Near Vision'), isTrue);
    expect(
      isNearVisionType('Right eye corrected vision / with glasses (CVA)'),
      isFalse,
    );
  });

  test(
    'near VA instructions distinguish presenting from unaided assessment',
    () {
      expect(
        nearVisionInstructionForVisionType('Presenting Near VA'),
        contains('usual near correction'),
      );
      expect(
        nearVisionInstructionForVisionType('Unaided Near VA'),
        contains('without spectacles'),
      );
      expect(
        nearVisionInstructionForVisionType(
          'Near Corrected Visual Acuity (with Near Glasses)',
        ),
        contains('near glasses'),
      );
      expect(nearVisionInstructionForVisionType('Near Vision'), isNull);
    },
  );

  test('elapsed test time is stored as whole seconds', () {
    final startedAt = DateTime(2026, 6, 1, 10, 0, 0);
    final endedAt = DateTime(2026, 6, 1, 10, 0, 42, 900);

    expect(elapsedSecondsBetween(startedAt, endedAt), 42);
  });

  test('local date time export is truncated to seconds', () {
    final dateTime = DateTime(2026, 6, 1, 12, 47, 20, 67, 77);

    expect(formatLocalDateTimeSeconds(dateTime), '2026-06-01 12:47:20');
  });

  test('ambient lux by level is exported in stable order', () {
    expect(
      ambientLuxByLevelToExport({'6/60': 1234.4, 'N6': 55.8}),
      '6/60=1234; N6=56',
    );
  });

  test('screen brightness by level is exported as percentages', () {
    expect(
      screenBrightnessByLevelToExport({'6/60': 0.8, 'N6': 0.5}),
      '6/60=80; N6=50',
    );
  });

  test('near test starts at N8 when that level is enabled', () {
    expect(startNearLevel(disabledLevels: {}), 9);
    expect(startNearLevel(disabledLevels: {9}), 5);
  });

  test('alternate distance flow brackets 6/12 with 6/19 confirmation', () {
    expect(
      nextDistanceFlowStep(
        mode: DistanceFlowMode.alternate612,
        level: 1,
        isPass: true,
        confirming612After619: false,
      ),
      const DistanceFlowStep(nextLevel: 3),
    );
    expect(
      nextDistanceFlowStep(
        mode: DistanceFlowMode.alternate612,
        level: 3,
        isPass: false,
        confirming612After619: false,
      ),
      const DistanceFlowStep(nextLevel: 2),
    );
    expect(
      nextDistanceFlowStep(
        mode: DistanceFlowMode.alternate612,
        level: 2,
        isPass: true,
        confirming612After619: false,
      ),
      const DistanceFlowStep(nextLevel: 3, confirming612After619: true),
    );
    expect(
      nextDistanceFlowStep(
        mode: DistanceFlowMode.alternate612,
        level: 3,
        isPass: false,
        confirming612After619: true,
      ),
      const DistanceFlowStep(finalResult: '6/19'),
    );
  });
}
