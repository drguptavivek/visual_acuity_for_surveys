import 'package:flutter/material.dart';
import 'package:v_a_rpc/screens/tests/pl_test.dart';

import '../../utils/helpers.dart';
import 'finger_test.dart';

class VisualTestScreen extends StatefulWidget {
  final String patientInfo;
  final String visionType;
  final int durationSecondsBeforeFallback;
  final String ambientLuxBeforeFallback;
  final String screenBrightnessBeforeFallback;
  const VisualTestScreen({
    super.key,
    required this.patientInfo,
    required this.visionType,
    this.durationSecondsBeforeFallback = 0,
    this.ambientLuxBeforeFallback = '',
    this.screenBrightnessBeforeFallback = '',
  });

  @override
  State<VisualTestScreen> createState() => _VisualTestScreenState();
}

class _VisualTestScreenState extends State<VisualTestScreen> {
  bool test1Completed = false;
  bool test2Started = false;
  int correctCount = 0;
  int wrongCount = 0;
  late final DateTime _testStartedAt;
  final List<String> _ambientLuxParts = [];
  final List<String> _screenBrightnessParts = [];

  @override
  void initState() {
    super.initState();
    _testStartedAt = DateTime.now();
    if (widget.ambientLuxBeforeFallback.isNotEmpty) {
      _ambientLuxParts.add(widget.ambientLuxBeforeFallback);
    }
    if (widget.screenBrightnessBeforeFallback.isNotEmpty) {
      _screenBrightnessParts.add(widget.screenBrightnessBeforeFallback);
    }
    _recordScreenBrightnessForLevel('FC');
    _recordAmbientLuxForLevel('FC');
  }

  void _recordScreenBrightnessForLevel(String levelName) {
    _screenBrightnessParts.add('$levelName=80');
  }

  Future<void> _recordAmbientLuxForLevel(String levelName) async {
    final lux = await readAmbientLux();
    if (lux == null) return;
    _ambientLuxParts.add('$levelName=${lux.round()}');
  }

  void _onTest1Complete(int correct, int wrong) {
    correctCount = correct;
    wrongCount = wrong;
    if (correct >= 4) {
      _showResult('Finger Counting');
    } else {
      _recordScreenBrightnessForLevel('PL');
      _recordAmbientLuxForLevel('PL');
      setState(() {
        test1Completed = true;
        test2Started = true;
      });
    }
  }

  void _onTest2Complete(bool canSeeLight) {
    _showResult(canSeeLight ? "PL+" : "PL-");
  }

  void _showResult(String result) {
    final durationSeconds =
        widget.durationSecondsBeforeFallback +
        elapsedSecondsBetween(_testStartedAt, DateTime.now());

    Navigator.pushReplacementNamed(
      context,
      '/summary',
      arguments: {
        'finalResult': result,
        'totalCorrect': correctCount,
        'totalWrong': wrongCount,
        'ignoredGestures': 0,
        'patientInfo': widget.patientInfo,
        'visionType': widget.visionType,
        'durationSeconds': durationSeconds,
        'ambientLuxByLevel': _ambientLuxParts.join('; '),
        'screenBrightnessByLevel': _screenBrightnessParts.join('; '),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!test1Completed) {
      return FingerTest(
        patientInfo: widget.patientInfo,
        visionType: widget.visionType,
        onComplete: _onTest1Complete,
      );
    } else if (test2Started) {
      return PlTest(
        patientInfo: widget.patientInfo,
        visionType: widget.visionType,
        onComplete: _onTest2Complete,
      );
    } else {
      return const SizedBox();
    }
  }
}
