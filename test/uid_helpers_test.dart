import 'package:flutter_test/flutter_test.dart';
import 'package:v_a_rpc/utils/uid_helpers.dart';

void main() {
  test('adds uid segment without deleting existing patient info', () {
    expect(
      patientInfoWithUid('Name: Asha Age: 62', 'ABC123'),
      'Name: Asha Age: 62 [UID=ABC123]',
    );
  });

  test('updates existing uid segment and preserves other patient info', () {
    expect(
      patientInfoWithUid('Name: Asha [UID=OLD] Age: 62', 'NEW-456'),
      'Name: Asha [UID=NEW-456] Age: 62',
    );
  });

  test('uses scanned qr value exactly apart from surrounding whitespace', () {
    expect(
      patientInfoWithUid('', ' patient_id=ABC123&site=7 '),
      '[UID=patient_id=ABC123&site=7]',
    );
  });

  test('extracts unique id for independent export column', () {
    expect(
      uniqueIdFromPatientInfo('Name: Asha [UID=ABC123] Age: 62'),
      'ABC123',
    );
    expect(uniqueIdFromPatientInfo('Name: Asha'), '');
  });
}
