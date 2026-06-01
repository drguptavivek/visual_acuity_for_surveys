import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/helpers.dart';
import 'tests/e_optotest.dart'; // To access the levels map

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Set<int> _disabledLevels = {};
  DistanceFlowMode _distanceFlowMode = DistanceFlowMode.standard;
  bool _isCvaVisionTypeEnabled = true;
  bool _isPvaVisionTypeEnabled = false;
  bool _isPinvaVisionTypeEnabled = true;
  bool _isNearCvaVisionTypeEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final disabledList = prefs.getStringList('disabledLevels') ?? [];
    setState(() {
      _disabledLevels = disabledList.map((e) => int.parse(e)).toSet();
      _distanceFlowMode = DistanceFlowMode.fromStorageValue(
        prefs.getString('distanceFlowMode'),
      );
      _isCvaVisionTypeEnabled = prefs.getBool('isCvaVisionTypeEnabled') ?? true;
      _isPvaVisionTypeEnabled =
          prefs.getBool('isPvaVisionTypeEnabled') ?? false;
      _isPinvaVisionTypeEnabled =
          prefs.getBool('isPinvaVisionTypeEnabled') ?? true;
      _isNearCvaVisionTypeEnabled =
          prefs.getBool('isNearCvaVisionTypeEnabled') ?? false;
    });
  }

  Future<void> _setDistanceFlowMode(DistanceFlowMode mode) async {
    setState(() {
      _distanceFlowMode = mode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('distanceFlowMode', mode.storageValue);
  }

  Future<void> _setCvaVisionTypeEnabled(bool value) async {
    setState(() {
      _isCvaVisionTypeEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isCvaVisionTypeEnabled', value);
  }

  Future<void> _setPvaVisionTypeEnabled(bool value) async {
    setState(() {
      _isPvaVisionTypeEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPvaVisionTypeEnabled', value);
  }

  Future<void> _setPinvaVisionTypeEnabled(bool value) async {
    setState(() {
      _isPinvaVisionTypeEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPinvaVisionTypeEnabled', value);
  }

  Future<void> _setNearCvaVisionTypeEnabled(bool value) async {
    setState(() {
      _isNearCvaVisionTypeEnabled = value;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isNearCvaVisionTypeEnabled', value);
  }

  Future<void> _toggleLevel(int levelNumber, bool value) async {
    setState(() {
      if (value) {
        _disabledLevels.remove(levelNumber);
      } else {
        _disabledLevels.add(levelNumber);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'disabledLevels',
      _disabledLevels.map((e) => e.toString()).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Sort levels by level number to display them in order
    final sortedLevels = levels.values.toList()
      ..sort((a, b) => a.levelNumber.compareTo(b.levelNumber));
    final distanceLevels = sortedLevels
        .where((level) => level.levelNumber != 5 && level.levelNumber != 9)
        .toList();
    final nearLevels = sortedLevels
        .where((level) => level.levelNumber == 5 || level.levelNumber == 9)
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SettingsSectionHeader(title: 'Mode', theme: theme),
          const ListTile(
            title: Text('Distance VA progression'),
            subtitle: Text(
              'Choose the level progression used for distance VA.',
            ),
          ),
          RadioListTile<DistanceFlowMode>(
            title: const Text('Standard'),
            subtitle: const Text('6/60 -> 6/19 -> 6/12 -> 6/9.5'),
            value: DistanceFlowMode.standard,
            // ignore: deprecated_member_use
            groupValue: _distanceFlowMode,
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) _setDistanceFlowMode(value);
            },
          ),
          RadioListTile<DistanceFlowMode>(
            title: const Text('Alternate 6/12 bracket'),
            subtitle: const Text(
              '6/60 -> 6/12; if fail, 6/19 -> 6/12 confirmation',
            ),
            value: DistanceFlowMode.alternate612,
            // ignore: deprecated_member_use
            groupValue: _distanceFlowMode,
            // ignore: deprecated_member_use
            onChanged: (value) {
              if (value != null) _setDistanceFlowMode(value);
            },
          ),
          const ListTile(
            title: Text('Distance VA test types'),
            subtitle: Text('Choose which distance VA rows are shown.'),
          ),
          SwitchListTile(
            title: const Text('CVA'),
            subtitle: const Text('Corrected visual acuity with glasses'),
            value: _isCvaVisionTypeEnabled,
            onChanged: _setCvaVisionTypeEnabled,
          ),
          SwitchListTile(
            title: const Text('PVA'),
            subtitle: const Text('Presenting visual acuity'),
            value: _isPvaVisionTypeEnabled,
            onChanged: _setPvaVisionTypeEnabled,
          ),
          SwitchListTile(
            title: const Text('PinVA'),
            subtitle: const Text('Pinhole visual acuity'),
            value: _isPinvaVisionTypeEnabled,
            onChanged: _setPinvaVisionTypeEnabled,
          ),
          const ListTile(
            title: Text('Near VA test types'),
            subtitle: Text('Choose optional near VA rows.'),
          ),
          SwitchListTile(
            title: const Text('Near CVA'),
            subtitle: const Text(
              'Near corrected visual acuity with near glasses',
            ),
            value: _isNearCvaVisionTypeEnabled,
            onChanged: _setNearCvaVisionTypeEnabled,
          ),
          const SizedBox(height: 8),
          _SettingsSectionHeader(
            title: 'Distance VA Levels Enabled',
            theme: theme,
          ),
          ...distanceLevels.map(_buildLevelSwitch),
          _SettingsSectionHeader(title: 'Near VA Levels Enabled', theme: theme),
          ...nearLevels.map(_buildLevelSwitch),
        ],
      ),
    );
  }

  Widget _buildLevelSwitch(Level level) {
    final isEnabled = !_disabledLevels.contains(level.levelNumber);
    return SwitchListTile(
      title: Text('Level ${level.levelNumber} - ${level.name}'),
      subtitle: Text('Distance: ${level.distance ?? "N/A"}m'),
      value: isEnabled,
      onChanged: (val) => _toggleLevel(level.levelNumber, val),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SettingsSectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
