import 'package:flutter_test/flutter_test.dart';
import 'package:v_a_rpc/utils/vision_type_instructions.dart';

void main() {
  test('UCVA instructs removal of glasses', () {
    expect(
      visionTypeInstruction(
        'Right eye uncorrected vision / without glasses (UCVA)',
      ),
      contains('Assess without any glasses'),
    );
  });

  test('distance CVA instructs to use glasses and stop if absent', () {
    final instruction = visionTypeInstruction(
      'Left eye corrected vision / with glasses (CVA)',
    );

    expect(instruction, contains('Measure with distance glasses'));
    expect(instruction, contains('do not proceed'));
  });

  test('PVA instructs based on whether distance glasses are present', () {
    final instruction = visionTypeInstruction(
      'Right eye presenting vision (PVA)',
    );

    expect(instruction, contains('if the person has distance glasses'));
    expect(instruction, contains('without glasses'));
  });

  test('near CVA instructs to use near glasses and stop if absent', () {
    final instruction = visionTypeInstruction(
      'Near Corrected Visual Acuity (with Near Glasses)',
    );

    expect(instruction, contains('Measure with near glasses'));
    expect(instruction, contains('do not proceed'));
  });

  test('unaided near VA instructs removal of near glasses', () {
    expect(
      visionTypeInstruction('Unaided Near VA'),
      contains('Assess without near glasses'),
    );
  });

  test('instruction lookup does not use partial matching', () {
    expect(
      visionTypeInstruction('Unexpected corrected vision / with glasses (CVA)'),
      'Confirm that the selected visual acuity type is correct before starting the test.',
    );
  });
}
