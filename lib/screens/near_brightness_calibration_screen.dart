import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/helpers.dart';

class NearBrightnessCalibrationScreen extends StatefulWidget {
  const NearBrightnessCalibrationScreen({super.key});

  @override
  State<NearBrightnessCalibrationScreen> createState() =>
      _NearBrightnessCalibrationScreenState();
}

class _NearBrightnessCalibrationScreenState
    extends State<NearBrightnessCalibrationScreen> {
  static const double _n8SvgBoxCm = 0.15 * 11 / 5;

  int _brightnessPercent = defaultNearScreenBrightnessPercent;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBrightness();
  }

  Future<void> _loadBrightness() async {
    final percent = await calibratedNearScreenBrightnessPercent();
    if (!mounted) return;
    setState(() {
      _brightnessPercent = percent;
      _loading = false;
    });
    await _applyBrightness(percent);
  }

  Future<void> _applyBrightness(int percent) async {
    await setApplicationBrightness(brightnessPercentToFraction(percent));
  }

  Future<void> _setBrightness(int percent) async {
    final normalized = normalizeNearScreenBrightnessPercent(percent);
    setState(() {
      _brightnessPercent = normalized;
    });
    await _applyBrightness(normalized);
  }

  Future<void> _saveBrightness() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(nearScreenBrightnessPercentKey, _brightnessPercent);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Near brightness saved: $_brightnessPercent%')),
    );
    Navigator.pop(context, _brightnessPercent);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canDecrease = _brightnessPercent > minNearScreenBrightnessPercent;
    final canIncrease = _brightnessPercent < maxNearScreenBrightnessPercent;

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
                future: cmToPx(context, _n8SvgBoxCm),
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
                      'Near brightness $_brightnessPercent%',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Set the lowest comfortable brightness where the E is clear and not glaring.',
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
                                        nearScreenBrightnessStepPercent,
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
                                        nearScreenBrightnessStepPercent,
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
                            onPressed: () => _setBrightness(
                              defaultNearScreenBrightnessPercent,
                            ),
                            child: const Text('Reset 50%'),
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
