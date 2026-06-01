import 'dart:math';

import 'package:ambient_light/ambient_light.dart';
import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Logger/logger.dart';

enum DistanceFlowMode {
  standard('standard'),
  alternate612('alternate612');

  final String storageValue;

  const DistanceFlowMode(this.storageValue);

  static DistanceFlowMode fromStorageValue(String? value) {
    return DistanceFlowMode.values.firstWhere(
      (mode) => mode.storageValue == value,
      orElse: () => DistanceFlowMode.standard,
    );
  }
}

const String nearScreenBrightnessPercentKey = 'nearScreenBrightnessPercent';
const String distanceScreenBrightnessPercentKey =
    'distanceScreenBrightnessPercent';
const int defaultNearScreenBrightnessPercent = 50;
const int minNearScreenBrightnessPercent = 30;
const int maxNearScreenBrightnessPercent = 70;
const int nearScreenBrightnessStepPercent = 2;
const int defaultDistanceScreenBrightnessPercent = 65;
const int minDistanceScreenBrightnessPercent = 50;
const int maxDistanceScreenBrightnessPercent = 80;
const int distanceScreenBrightnessStepPercent = 5;
const double defaultDistanceScreenBrightness =
    defaultDistanceScreenBrightnessPercent / 100;
const Duration ambientLightCheckInterval = Duration(seconds: 15);

class DistanceFlowStep {
  final int? nextLevel;
  final String? finalResult;
  final bool confirming612After619;

  const DistanceFlowStep({
    this.nextLevel,
    this.finalResult,
    this.confirming612After619 = false,
  });

  @override
  bool operator ==(Object other) {
    return other is DistanceFlowStep &&
        other.nextLevel == nextLevel &&
        other.finalResult == finalResult &&
        other.confirming612After619 == confirming612After619;
  }

  @override
  int get hashCode =>
      Object.hash(nextLevel, finalResult, confirming612After619);
}

DistanceFlowStep? nextDistanceFlowStep({
  required DistanceFlowMode mode,
  required int level,
  required bool isPass,
  required bool confirming612After619,
}) {
  if (mode != DistanceFlowMode.alternate612) return null;

  if (level == 1 && isPass) {
    return const DistanceFlowStep(nextLevel: 3);
  }

  if (level == 3 && !isPass) {
    if (confirming612After619) {
      return const DistanceFlowStep(finalResult: '6/19');
    }
    return const DistanceFlowStep(nextLevel: 2);
  }

  if (level == 2 && isPass) {
    return const DistanceFlowStep(nextLevel: 3, confirming612After619: true);
  }

  return null;
}

Future<bool> checkAmbientLight(
  int maxluxvalue,
  bool lightWarningShown,
  BuildContext context,
) async {
  try {
    double? lux = await readAmbientLux();
    if (!context.mounted) return false;
    // logger.d(
    //   "lux : $lux | maxluxvalue : $maxluxvalue | lightWarningShown : $lightWarningShown",
    // );
    if (lux != null && lux > maxluxvalue && !lightWarningShown) {
      lightWarningShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text("Too Bright!"),
          content: Text(
            "Ambient light is too high (${lux.toStringAsFixed(0)} lux).\nPlease go indoors.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("OK"),
            ),
          ],
        ),
      );
      return true;
    }
  } catch (e) {
    logger.d('Failed to get ambient light: $e');
  }
  return false;
}

bool isNearVisionType(String visionType) {
  return visionType == 'Near Vision' ||
      visionType == 'Presenting Near VA' ||
      visionType == 'Near Corrected Visual Acuity (with Near Glasses)' ||
      visionType == 'Unaided Near VA';
}

String? nearVisionInstructionForVisionType(String visionType) {
  if (visionType == 'Presenting Near VA') {
    return 'Presenting Near VA: test with the participant using their usual near correction, if they normally use one. Keep the phone at 40 cm, perpendicular to the visual axis, and avoid screen glare.';
  }

  if (visionType == 'Unaided Near VA') {
    return 'Unaided Near VA: test without spectacles or any near correction. Keep the phone at 40 cm, perpendicular to the visual axis, and avoid screen glare.';
  }

  if (visionType == 'Near Corrected Visual Acuity (with Near Glasses)') {
    return 'Near Corrected Visual Acuity: test with the participant using their near glasses. Keep the phone at 40 cm, perpendicular to the visual axis, and avoid screen glare.';
  }

  return null;
}

int startNearLevel({required Set<int> disabledLevels}) {
  return disabledLevels.contains(9) ? 5 : 9;
}

double defaultScreenBrightnessForVisionType(String visionType) {
  return isNearVisionType(visionType)
      ? defaultNearScreenBrightnessPercent / 100
      : defaultDistanceScreenBrightness;
}

int normalizeNearScreenBrightnessPercent(int value) {
  return value.clamp(
    minNearScreenBrightnessPercent,
    maxNearScreenBrightnessPercent,
  );
}

int normalizeDistanceScreenBrightnessPercent(int value) {
  return value.clamp(
    minDistanceScreenBrightnessPercent,
    maxDistanceScreenBrightnessPercent,
  );
}

double brightnessPercentToFraction(int percent) {
  return normalizeNearScreenBrightnessPercent(percent) / 100;
}

double distanceBrightnessPercentToFraction(int percent) {
  return normalizeDistanceScreenBrightnessPercent(percent) / 100;
}

Future<int> calibratedNearScreenBrightnessPercent() async {
  final prefs = await SharedPreferences.getInstance();
  return normalizeNearScreenBrightnessPercent(
    prefs.getInt(nearScreenBrightnessPercentKey) ??
        defaultNearScreenBrightnessPercent,
  );
}

Future<int> calibratedDistanceScreenBrightnessPercent() async {
  final prefs = await SharedPreferences.getInstance();
  return normalizeDistanceScreenBrightnessPercent(
    prefs.getInt(distanceScreenBrightnessPercentKey) ??
        defaultDistanceScreenBrightnessPercent,
  );
}

Future<double?> savedPxPerCm() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getDouble('pxPerCm');
}

Future<double> screenBrightnessForVisionType(String visionType) async {
  if (!isNearVisionType(visionType)) {
    final distancePercent = await calibratedDistanceScreenBrightnessPercent();
    return distanceBrightnessPercentToFraction(distancePercent);
  }
  final nearPercent = await calibratedNearScreenBrightnessPercent();
  return brightnessPercentToFraction(nearPercent);
}

Future<double?> readAmbientLux() async {
  try {
    final AmbientLight ambientLight = AmbientLight(frontCamera: true);
    return ambientLight.currentAmbientLight();
  } catch (e) {
    logger.d('Failed to get ambient light: $e');
    return null;
  }
}

String ambientLuxByLevelToExport(Map<String, double> ambientLuxByLevel) {
  return ambientLuxByLevel.entries
      .map((entry) => '${entry.key}=${entry.value.round()}')
      .join('; ');
}

String screenBrightnessByLevelToExport(
  Map<String, double> screenBrightnessByLevel,
) {
  return screenBrightnessByLevel.entries
      .map((entry) => '${entry.key}=${(entry.value * 100).round()}')
      .join('; ');
}

int elapsedSecondsBetween(DateTime startedAt, DateTime endedAt) {
  final elapsed = endedAt.difference(startedAt).inSeconds;
  return elapsed < 0 ? 0 : elapsed;
}

String formatLocalDateTimeSeconds(DateTime dateTime) {
  final local = dateTime.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final second = local.second.toString().padLeft(2, '0');

  return '$year-$month-$day $hour:$minute:$second';
}

Future<void> setApplicationBrightness(double brightness) async {
  try {
    await ScreenBrightness().setApplicationScreenBrightness(brightness);
  } catch (e) {
    logger.d('Failed to set brightness: $e');
  }
}

Future<void> resetApplicationBrightness() async {
  try {
    await ScreenBrightness().resetApplicationScreenBrightness();
  } catch (e) {
    logger.d('Failed to reset brightness: $e');
  }
}

Future<void> setBrightnessTo90() async {
  await setApplicationBrightness(0.9);
}

Future<void> setBrightnessTo80() async {
  await setApplicationBrightness(0.8);
}

/// Convert centimeters to logical pixels based on calibration if available.
/// Requires calibration to be saved first via CalibrationScreen.
/// If not calibrated, uses baseline estimate (160 logical DPI).
Future<double> cmToPx(BuildContext context, double cm) async {
  final prefs = await SharedPreferences.getInstance();

  // 1️⃣ Use saved calibration if exists
  final pxPerCm = prefs.getDouble('pxPerCm');
  if (pxPerCm != null) {
    logger.i(
      'cmToPx: $cm cm × $pxPerCm px/cm = ${(cm * pxPerCm).toStringAsFixed(2)} px',
    );
    return cm * pxPerCm;
  }

  // 2️⃣ Fallback: estimate using baseline logical DPI
  // Flutter's standard logical DPI is 160 (device-independent)
  const baselineLogicalDpi = 160.0;
  final logicalPxPerCm = (baselineLogicalDpi / 2.54);

  logger.w(
    'cmToPx: No calibration found. Using baseline estimate: '
    '$cm cm × $logicalPxPerCm px/cm = ${(cm * logicalPxPerCm).toStringAsFixed(2)} px. '
    'Please run calibration for accuracy.',
  );

  return cm * logicalPxPerCm;
}

Future<Size> getCalibratedSvgSize(
  BuildContext context,
  double widthCm,
  double heightCm,
) async {
  // Get device DPI for diagnostic logging
  final mq = MediaQuery.of(context);
  final dpr = mq.devicePixelRatio;

  final prefs = await SharedPreferences.getInstance();
  final pxPerCm = prefs.getDouble('pxPerCm');

  if (pxPerCm == null) {
    logger.w(
      'getCalibratedSvgSize: No calibration found. '
      'Using baseline estimate. Please run calibration.',
    );
    // Fallback to baseline estimate
    const baselineLogicalDpi = 160.0;
    final logicalPxPerCm = (baselineLogicalDpi / 2.54);
    final width = widthCm * logicalPxPerCm;
    final height = heightCm * logicalPxPerCm;

    logger.i(
      'Calibrated SVG Size (fallback): '
      '${width.toStringAsFixed(2)} x ${height.toStringAsFixed(2)} px | DPR=$dpr',
    );

    return Size(width, height);
  }

  final width = widthCm * pxPerCm;
  final height = heightCm * pxPerCm;

  logger.i(
    'Calibrated SVG Size (using $pxPerCm px/cm): '
    '${width.toStringAsFixed(2)} x ${height.toStringAsFixed(2)} px | '
    'Input: ${widthCm}cm x ${heightCm}cm | DPR=$dpr',
  );

  return Size(width, height);
}

String detectSwipeDirection(Offset swipeDelta) {
  double angleDeg = atan2(swipeDelta.dy, swipeDelta.dx) * (180 / pi);

  if (angleDeg >= -45 && angleDeg < 45) return 'right';
  if (angleDeg >= 45 && angleDeg < 135) return 'up';
  if (angleDeg >= -135 && angleDeg < -45) return 'down';
  return 'left';
}
