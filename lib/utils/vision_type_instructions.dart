String visionTypeInstruction(String visionType) {
  return _visionTypeInstructions[visionType] ??
      'Confirm that the selected visual acuity type is correct before starting the test.';
}

const Map<String, String> _visionTypeInstructions = {
  'Right eye uncorrected vision / without glasses (UCVA)':
      'Remove distance glasses if present. Assess without any glasses.',
  'Left eye uncorrected vision / without glasses (UCVA)':
      'Remove distance glasses if present. Assess without any glasses.',
  'Right eye corrected vision / with glasses (CVA)':
      'Measure with distance glasses. If the person does not have distance glasses, do not proceed with CVA.',
  'Left eye corrected vision / with glasses (CVA)':
      'Measure with distance glasses. If the person does not have distance glasses, do not proceed with CVA.',
  'Right eye presenting vision (PVA)':
      'Measure with distance glasses if the person has distance glasses, and without glasses if the person does not have distance glasses.',
  'Left eye presenting vision (PVA)':
      'Measure with distance glasses if the person has distance glasses, and without glasses if the person does not have distance glasses.',
  'Right eye pinhole vision (PinVA)':
      'Use the pinhole. Assess through the pinhole according to the survey protocol.',
  'Left eye pinhole vision (PinVA)':
      'Use the pinhole. Assess through the pinhole according to the survey protocol.',
  'Presenting Near VA':
      'Measure with near glasses if the person normally uses near glasses, and without near glasses if the person does not use near glasses.',
  'Near Corrected Visual Acuity (with Near Glasses)':
      'Measure with near glasses. If the person does not have near glasses, do not proceed with Near CVA.',
  'Unaided Near VA':
      'Remove near glasses if present. Assess without near glasses.',
};
