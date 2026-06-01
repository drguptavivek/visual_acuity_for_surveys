import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/helpers.dart';
import 'tests/e_optotest.dart';

enum BrightnessCalibrationMode {
  distance(
    title: 'Distance brightness',
    storageKey: distanceScreenBrightnessPercentKey,
    defaultPercent: defaultDistanceScreenBrightnessPercent,
    minPercent: minDistanceScreenBrightnessPercent,
    maxPercent: maxDistanceScreenBrightnessPercent,
    stepPercent: distanceScreenBrightnessStepPercent,
    resetLabel: 'Reset 65%',
    savedLabel: 'Distance brightness saved',
    helperText:
        'Set the lowest brightness where the distance E is clear outdoors without heating the phone unnecessarily.',
  ),
  near(
    title: 'Near brightness',
    storageKey: nearScreenBrightnessPercentKey,
    defaultPercent: defaultNearScreenBrightnessPercent,
    minPercent: minNearScreenBrightnessPercent,
    maxPercent: maxNearScreenBrightnessPercent,
    stepPercent: nearScreenBrightnessStepPercent,
    resetLabel: 'Reset 50%',
    savedLabel: 'Near brightness saved',
    helperText:
        'Set the lowest comfortable brightness where the E is clear and not glaring.',
  );

  final String title;
  final String storageKey;
  final int defaultPercent;
  final int minPercent;
  final int maxPercent;
  final int stepPercent;
  final String resetLabel;
  final String savedLabel;
  final String helperText;

  const BrightnessCalibrationMode({
    required this.title,
    required this.storageKey,
    required this.defaultPercent,
    required this.minPercent,
    required this.maxPercent,
    required this.stepPercent,
    required this.resetLabel,
    required this.savedLabel,
    required this.helperText,
  });

  int normalize(int value) => value.clamp(minPercent, maxPercent);

  double get previewBoxCm {
    if (this == BrightnessCalibrationMode.near) {
      return 0.15 * 11 / 5;
    }
    return levels[2]!.levelSize! * 11 / 5;
  }
}

class NearBrightnessCalibrationScreen extends StatelessWidget {
  const NearBrightnessCalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrightnessCalibrationScreen(
      mode: BrightnessCalibrationMode.near,
    );
  }
}

class DistanceBrightnessCalibrationScreen extends StatelessWidget {
  const DistanceBrightnessCalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const BrightnessCalibrationScreen(
      mode: BrightnessCalibrationMode.distance,
    );
  }
}

class DistanceBrightnessInstructionScreen extends StatelessWidget {
  const DistanceBrightnessInstructionScreen({super.key});

  static const String instruction =
      'Stand where the survey is usually done. Keep the phone shaded from direct sun, hold it at normal testing position, and set the lowest brightness at which the 6/19 E is clearly visible without glare.';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Distance Brightness')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.wb_sunny_outlined,
                size: 56,
                color: Colors.indigo,
              ),
              const SizedBox(height: 24),
              Text(
                'Before calibration',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                instruction,
                style: TextStyle(fontSize: 18, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.pushReplacementNamed(
                    context,
                    '/distanceBrightnessCalibration',
                  );
                },
                child: const Text('Start Calibration'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BrightnessCalibrationScreen extends StatefulWidget {
  final BrightnessCalibrationMode mode;

  const BrightnessCalibrationScreen({super.key, required this.mode});

  @override
  State<BrightnessCalibrationScreen> createState() =>
      _BrightnessCalibrationScreenState();
}

class _BrightnessCalibrationScreenState
    extends State<BrightnessCalibrationScreen> {
  late int _brightnessPercent = widget.mode.defaultPercent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBrightness();
  }

  Future<void> _loadBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    final percent = widget.mode.normalize(
      prefs.getInt(widget.mode.storageKey) ?? widget.mode.defaultPercent,
    );
    if (!mounted) return;
    setState(() {
      _brightnessPercent = percent;
      _loading = false;
    });
    await _applyBrightness(percent);
  }

  Future<void> _applyBrightness(int percent) async {
    await setApplicationBrightness(percent / 100);
  }

  Future<void> _setBrightness(int percent) async {
    final normalized = widget.mode.normalize(percent);
    setState(() {
      _brightnessPercent = normalized;
    });
    await _applyBrightness(normalized);
  }

  Future<void> _saveBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(widget.mode.storageKey, _brightnessPercent);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${widget.mode.savedLabel}: $_brightnessPercent%'),
      ),
    );
    Navigator.pop(context, _brightnessPercent);
  }

  @override
  void dispose() {
    resetApplicationBrightness();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canDecrease = _brightnessPercent > widget.mode.minPercent;
    final canIncrease = _brightnessPercent < widget.mode.maxPercent;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              left: 8,
              top: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
            ),
            Center(
              child: FutureBuilder<double>(
                future: cmToPx(context, widget.mode.previewBoxCm),
                builder: (context, snapshot) {
                  final eSizePx = snapshot.data ?? 24.0;
                  return SizedBox(
                    width: eSizePx,
                    height: eSizePx,
                    child: SvgPicture.asset(
                      'assets/images/tests/e_optom_box.svg',
                      fit: BoxFit.fill,
                    ),
                  );
                },
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.mode.title} $_brightnessPercent%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.mode.helperText,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: canDecrease
                                ? () => _setBrightness(
                                    _brightnessPercent -
                                        widget.mode.stepPercent,
                                  )
                                : null,
                            child: const Icon(Icons.remove, size: 32),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: canIncrease
                                ? () => _setBrightness(
                                    _brightnessPercent +
                                        widget.mode.stepPercent,
                                  )
                                : null,
                            child: const Icon(Icons.add, size: 32),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                _setBrightness(widget.mode.defaultPercent),
                            child: Text(widget.mode.resetLabel),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saveBrightness,
                            child: const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
