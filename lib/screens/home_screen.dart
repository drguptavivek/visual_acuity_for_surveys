import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loadingCalibration = true;
  bool _hasBoxCalibration = false;

  @override
  void initState() {
    super.initState();
    _loadCalibrationStatus();
  }

  Future<void> _loadCalibrationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _hasBoxCalibration = prefs.getDouble('pxPerCm') != null;
      _loadingCalibration = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Visual Acuity RPC v1.0'), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/home_screen_image.gif',
                  width: 300,
                  height: 300,
                  fit: BoxFit.cover,
                ),
                const SizedBox(height: 20),
                if (!_loadingCalibration && !_hasBoxCalibration) ...[
                  _CalibrationWarningCard(
                    onCalibrate: () async {
                      await Navigator.pushNamed(context, '/calibrate');
                      await _loadCalibrationStatus();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _hasBoxCalibration
                          ? () => Navigator.pushNamed(
                              context,
                              '/testHome',
                              arguments: {'patientInfo': null},
                            )
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Colors.indigo, // Button background color
                        foregroundColor: Colors.white, // Text/icon color
                        textStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            12,
                          ), // Rounded corners
                        ),
                      ),
                      child: const Text('Start Test'),
                    ),
                  ),
                ),

                const SizedBox(height: 10),
                _buildFullWidthButton(
                  context,
                  label: 'Instructions',
                  route: '/instructions',
                ),
                _buildFullWidthButton(
                  context,
                  label: 'Tutorial',
                  route: '/tutorial',
                ),
                _buildFullWidthButtonWithAction(
                  label: 'Calibrate Screen',
                  onPressed: () async {
                    await Navigator.pushNamed(context, '/calibrate');
                    await _loadCalibrationStatus();
                  },
                ),
                _buildFullWidthButton(
                  context,
                  label: 'History',
                  route: '/history',
                ),
                _buildFullWidthButton(
                  context,
                  label: 'Settings',
                  route: '/settings',
                ),
                _buildFullWidthButton(context, label: 'About', route: '/about'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(
    BuildContext context, {
    required String label,
    required String route,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, route),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _buildFullWidthButtonWithAction({
    required String label,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      ),
    );
  }
}

class _CalibrationWarningCard extends StatelessWidget {
  final VoidCallback onCalibrate;

  const _CalibrationWarningCard({required this.onCalibrate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        border: Border.all(color: Colors.amber.shade700),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Screen size is not calibrated. Optotype size may be inaccurate.',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onCalibrate, child: const Text('Calibrate')),
        ],
      ),
    );
  }
}
