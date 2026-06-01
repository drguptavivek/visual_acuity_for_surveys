import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:v_a_rpc/managers/test_history.dart';
import 'package:v_a_rpc/utils/uid_helpers.dart';

import '../../Logger/logger.dart';

const String _rightUcva =
    'Right eye uncorrected vision / without glasses (UCVA)';
const String _leftUcva = 'Left eye uncorrected vision / without glasses (UCVA)';
const String _rightCva = 'Right eye corrected vision / with glasses (CVA)';
const String _leftCva = 'Left eye corrected vision / with glasses (CVA)';
const String _rightPva = 'Right eye presenting vision (PVA)';
const String _leftPva = 'Left eye presenting vision (PVA)';
const String _rightPinva = 'Right eye pinhole vision (PinVA)';
const String _leftPinva = 'Left eye pinhole vision (PinVA)';
const String _presentingNearVa = 'Presenting Near VA';
const String _nearCva = 'Near Corrected Visual Acuity (with Near Glasses)';
const String _unaidedNearVa = 'Unaided Near VA';

const List<String> _allVisionOptions = [
  _rightUcva,
  _leftUcva,
  _rightCva,
  _leftCva,
  _rightPva,
  _leftPva,
  _rightPinva,
  _leftPinva,
  _presentingNearVa,
  _nearCva,
  _unaidedNearVa,
];

class _DistanceVisionRow {
  final String title;
  final String rightValue;
  final String leftValue;

  const _DistanceVisionRow({
    required this.title,
    required this.rightValue,
    required this.leftValue,
  });
}

class PatientInputScreenWrapper extends StatelessWidget {
  const PatientInputScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    try {
      logger.d("patientInfo from start : ${args?['patientInfo']}");
      return PatientInputScreen(patientInfo: args?['patientInfo']);
    } catch (e) {
      logger.d("Gone something wrong : $e");
      return const PatientInputScreen();
    }
  }
}

class PatientInputScreen extends StatefulWidget {
  final String? patientInfo;
  const PatientInputScreen({super.key, this.patientInfo});

  @override
  State<PatientInputScreen> createState() => _PatientInputScreenState();
}

class _PatientInputScreenState extends State<PatientInputScreen> {
  final TextEditingController _infoController = TextEditingController();
  String? _selectedVisionType;
  bool _isCvaEnabled = true;
  bool _isPvaEnabled = false;
  bool _isPinvaEnabled = true;
  bool _isNearCvaEnabled = false;

  List<bool> _operationDone = [];

  void clearFields() {
    _infoController.clear();
    setState(() {
      _selectedVisionType = null;
      _operationDone = List<bool>.filled(_allVisionOptions.length, false);
    });
  }

  @override
  void initState() {
    super.initState();
    _initAsync(); // fire-and-forget async setup
  }

  Future<void> _initAsync() async {
    await _loadVisionTypeSettings();

    // 1. If patientInfo passed via arguments, use it.
    if (widget.patientInfo != null && widget.patientInfo!.trim().isNotEmpty) {
      final info = widget.patientInfo!.trim();
      logger.d("patientInfo from args: $info");
      _infoController.text = info;

      await fetchOperationDone(info);
      return;
    }

    // 2. Otherwise, try to load last patient ID from history
    final lastPatientID = await fetchLastPatientID();

    logger.d(
      "patientInfo after fetchLastPatientID: '${_infoController.text.trim()}'",
    );

    if (lastPatientID.isNotEmpty) {
      await fetchOperationDone(lastPatientID);
    } else {
      // No last patient: mark all operations as false
      if (!mounted) return;
      setState(() {
        _operationDone = List<bool>.filled(_allVisionOptions.length, false);
      });
    }
  }

  Future<void> _loadVisionTypeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isCvaEnabled = prefs.getBool('isCvaVisionTypeEnabled') ?? true;
      _isPvaEnabled = prefs.getBool('isPvaVisionTypeEnabled') ?? false;
      _isPinvaEnabled = prefs.getBool('isPinvaVisionTypeEnabled') ?? true;
      _isNearCvaEnabled = prefs.getBool('isNearCvaVisionTypeEnabled') ?? false;
    });
  }

  /// Loads latest patient ID from history and sets the text controller.
  /// Returns the patient ID string (or empty if none).
  Future<String> fetchLastPatientID() async {
    final latestRow = await TestHistoryManager.readLatestHistoryRow();
    final lastPatientID = latestRow.isNotEmpty && latestRow.length > 1
        ? latestRow[1]
        : '';

    logger.d("lastPatientID from history: '$lastPatientID'");

    if (lastPatientID.isEmpty) {
      logger.d("No last patient, keeping text empty");
      return '';
    }

    if (!mounted) return '';
    setState(() {
      _infoController.text = lastPatientID;
    });

    return lastPatientID;
  }

  /// Fills _operationDone: for each vision option, true if any row for this patient has that vision.
  Future<void> fetchOperationDone(String patientId) async {
    if (patientId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _operationDone = List<bool>.filled(_allVisionOptions.length, false);
      });
      logger.d("Empty patientId in fetchOperationDone, setting all false");
      return;
    }

    final rowData = await TestHistoryManager.readHistoryByPatient(patientId);

    // Prepare local list: one bool per vision option
    final List<bool> operationDone = List<bool>.filled(
      _allVisionOptions.length,
      false,
    );

    const int visionColIndex = 2; // <-- adjust to your actual column index

    for (int i = 0; i < _allVisionOptions.length; i++) {
      final option = _allVisionOptions[i];

      // Check if ANY row has this vision option
      final exists = rowData.any((row) {
        logger.d("Checking row for option '$option': $row");
        if (row.length <= visionColIndex) return false;
        final visionValue = row[visionColIndex];
        return visionValue.toLowerCase() == option.toLowerCase();
      });

      operationDone[i] = exists;
    }

    if (!mounted) return;
    setState(() {
      _operationDone = operationDone;
    });

    logger.d("fetched _operationDone : $_operationDone");
  }

  void _startTest() {
    final info = _infoController.text.trim();
    final selected = _selectedVisionType;

    if (info.isEmpty || selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter info and select vision type'),
        ),
      );
      return;
    }

    Navigator.pushReplacementNamed(
      context,
      '/test',
      arguments: {'patientInfo': info, 'visionType': selected},
    );
  }

  bool _isDone(String visionType) {
    final index = _allVisionOptions.indexOf(visionType);
    return index >= 0 && _operationDone.length > index && _operationDone[index];
  }

  void _selectVisionType(String visionType) {
    setState(() {
      _selectedVisionType = visionType;
    });
  }

  Future<void> _scanUniqueId() async {
    final scannedResult = await Navigator.pushNamed(
      context,
      '/qrScanner',
    );
    final scannedValue = scannedResult as String?;
    if (scannedValue == null || scannedValue.trim().isEmpty) return;

    final updatedInfo = patientInfoWithUid(
      _infoController.text,
      scannedValue,
    );
    if (!mounted) return;
    setState(() {
      _infoController.text = updatedInfo;
      _infoController.selection = TextSelection.collapsed(
        offset: updatedInfo.length,
      );
    });
    await fetchOperationDone(updatedInfo);
  }

  List<_DistanceVisionRow> get _distanceVisionRows {
    return [
      const _DistanceVisionRow(
        title: 'UCVA',
        rightValue: _rightUcva,
        leftValue: _leftUcva,
      ),
      if (_isCvaEnabled)
        const _DistanceVisionRow(
          title: 'CVA',
          rightValue: _rightCva,
          leftValue: _leftCva,
        ),
      if (_isPvaEnabled)
        const _DistanceVisionRow(
          title: 'PVA',
          rightValue: _rightPva,
          leftValue: _leftPva,
        ),
      if (_isPinvaEnabled)
        const _DistanceVisionRow(
          title: 'PinVA',
          rightValue: _rightPinva,
          leftValue: _leftPinva,
        ),
    ];
  }

  Widget _buildEyeChoiceButton({
    required String label,
    required String visionType,
  }) {
    final selected = _selectedVisionType == visionType;
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _selectVisionType(visionType),
        icon: _isDone(visionType)
            ? const Icon(Icons.check_circle, color: Colors.green)
            : Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
              ),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          backgroundColor: selected ? Colors.indigo.shade50 : Colors.white,
          foregroundColor: selected ? Colors.indigo : Colors.black87,
          side: BorderSide(
            color: selected ? Colors.indigo : Colors.grey.shade400,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildDistanceVisionRow(_DistanceVisionRow row) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              row.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          _buildEyeChoiceButton(label: 'Right', visionType: row.rightValue),
          const SizedBox(width: 8),
          _buildEyeChoiceButton(label: 'Left', visionType: row.leftValue),
        ],
      ),
    );
  }

  Widget _buildNearVisionOption(String visionType) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: RadioListTile<String>(
        title: Text(visionType),
        value: visionType,
        // ignore: deprecated_member_use
        groupValue: _selectedVisionType,
        // ignore: deprecated_member_use
        onChanged: (val) {
          if (val != null) _selectVisionType(val);
        },
        tileColor: Colors.white,
        secondary: _isDone(visionType)
            ? const Icon(Icons.check_circle, color: Colors.green)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text(
          'Patient Information',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/tutorialSwipe');
            },
            child: const Text('Tutorial'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Enter Id:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton(
                    onPressed: _initAsync,
                    child: const Text('Load Last'),
                  ),
                  ElevatedButton(
                    onPressed: clearFields,
                    child: const Text('Clear'),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              TextField(
                controller: _infoController,
                maxLines: 1,
                decoration: InputDecoration(
                  hintText: 'Enter name, age, etc.',
                  suffixIcon: IconButton(
                    onPressed: _scanUniqueId,
                    icon: const Icon(Icons.qr_code_scanner),
                    tooltip: 'Scan Unique ID',
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Distance VA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final row in _distanceVisionRows)
                _buildDistanceVisionRow(row),
              const SizedBox(height: 16),
              const Text(
                'Near VA (binocular)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildNearVisionOption(_presentingNearVa),
              if (_isNearCvaEnabled) _buildNearVisionOption(_nearCva),
              _buildNearVisionOption(_unaidedNearVa),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _startTest,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Start Test"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
