String patientInfoWithUid(String currentInfo, String scannedUid) {
  final uid = scannedUid.trim();
  if (uid.isEmpty) return currentInfo;

  final normalized = '[UID=$uid]';
  final current = currentInfo.trim();
  final uidPattern = RegExp(r'\[UID=[^\]]*\]');

  if (uidPattern.hasMatch(current)) {
    return current.replaceFirst(uidPattern, normalized).trim();
  }

  if (current.isEmpty) return normalized;
  return '$current $normalized';
}

String uniqueIdFromPatientInfo(String patientInfo) {
  final match = RegExp(r'\[UID=([^\]]*)\]').firstMatch(patientInfo);
  return match?.group(1)?.trim() ?? '';
}
