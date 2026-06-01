import 'dart:math';
import 'dart:io';
import 'package:intl/intl.dart';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../Logger/logger.dart';
import '../managers/test_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  List<String> _headers = [];
  List<List<String>> _data = [];
  List<_PatientHistoryGroup> _patientGroups = [];

  bool _loading = true;
  bool _error = false;

  // How many items we’re currently showing in the list
  int _itemsToShow = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadHistory();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final rows = await TestHistoryManager.readHistory();
      logger.d(rows);

      if (rows.isEmpty) {
        _headers = ['DateTime', 'Result'];
        _data = [
          ['No records found', ''],
        ];
        _patientGroups = [];
      } else {
        _headers = rows.first.map((e) => e.toString()).toList();
        _data = rows
            .skip(1)
            .map<List<String>>(
              (row) => row.map((cell) => cell.toString()).toList(),
            )
            .toList()
            .reversed
            .toList(); // latest first
        _patientGroups = _buildPatientGroups(_headers, _data);
      }

      _itemsToShow = min(_pageSize, _patientGroups.length);
    } catch (e, st) {
      logger.e('Error reading history , $e, $st');
      _error = true;
      _headers = ['DateTime', 'Result'];
      _data = [
        ['Error reading history', ''],
      ];
      _patientGroups = [];
      _itemsToShow = _patientGroups.length;
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _itemsToShow < _patientGroups.length) {
      // Auto-load more when nearing the bottom
      setState(() {
        _itemsToShow = min(_itemsToShow + _pageSize, _patientGroups.length);
      });
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Clear History?"),
        content: const Text(
          "Are you sure you want to delete all test history?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Clear"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TestHistoryManager.clearHistory();
      setState(() {
        _headers = ['DateTime', 'Result'];
        _data = [
          ['History cleared', ''],
        ];
        _patientGroups = [];
        _itemsToShow = _patientGroups.length;
      });
    }
  }

  Future<void> _shareHistoryXlsx() async {
    final filePath = await TestHistoryManager.getFilePath();
    final file = File(filePath);

    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No XLS history file found to share.')),
      );
      return;
    }

    await SharePlus.instance.share(
      ShareParams(
        text: 'RPC VA App test history',
        subject: 'RPC VA App test_history.xlsx',
        files: [
          XFile(
            filePath,
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: 'test_history.xlsx',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test History'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Share XLS',
            onPressed: _data.isEmpty ? null : _shareHistoryXlsx,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Clear History',
            onPressed: _data.isEmpty ? null : _clearHistory,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: _data.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Text(
                        _error ? 'Failed to load history' : 'No history found',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              )
            : _patientGroups.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Text(
                        _error ? 'Failed to load history' : 'No history found',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount:
                    _itemsToShow + 1, // extra one for the footer (Load more)
                itemBuilder: (context, index) {
                  if (index < _itemsToShow) {
                    final group = _patientGroups[index];
                    return _PatientHistoryCard(headers: _headers, group: group);
                  }

                  // Footer
                  final hasMore = _itemsToShow < _patientGroups.length;
                  if (!hasMore) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _itemsToShow = min(
                              _itemsToShow + _pageSize,
                              _patientGroups.length,
                            );
                          });
                        },
                        icon: const Icon(Icons.expand_more),
                        label: const Text('Load more'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

List<_PatientHistoryGroup> _buildPatientGroups(
  List<String> headers,
  List<List<String>> rows,
) {
  final byPatient = <String, List<List<String>>>{};

  for (final row in rows) {
    final patient = _cell(headers, row, 'patientInfo').trim();
    final key = patient.isEmpty ? 'Unknown patient' : patient;
    byPatient.putIfAbsent(key, () => []).add(row);
  }

  final groups = byPatient.entries.map((entry) {
    final records = _buildPatientRecords(headers, entry.value);
    final latest = entry.value
        .map((row) => _parseSafeDate(_cell(headers, row, 'DateTime')))
        .whereType<DateTime>()
        .fold<DateTime?>(null, (latest, current) {
          if (latest == null || current.isAfter(latest)) return current;
          return latest;
        });
    return _PatientHistoryGroup(
      patientInfo: entry.key,
      latestDateTime: latest,
      records: records,
    );
  }).toList();

  groups.sort((a, b) {
    final aTime = a.latestDateTime;
    final bTime = b.latestDateTime;
    if (aTime == null && bTime == null) return 0;
    if (aTime == null) return 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });

  return groups;
}

List<_PatientVisionRecord> _buildPatientRecords(
  List<String> headers,
  List<List<String>> rows,
) {
  final recordsByType = <String, _MutablePatientVisionRecord>{};

  for (final row in rows.reversed) {
    final visionType = _cell(headers, row, 'visionType');
    final result = _cell(headers, row, 'Result');
    final duration = _cell(headers, row, 'DurationSeconds');
    final type = _visionTypeLabel(visionType);
    final eye = _eyeForVisionType(visionType);

    final record = recordsByType.putIfAbsent(
      type,
      () => _MutablePatientVisionRecord(type),
    );
    if (eye == _HistoryEye.right) {
      record.rightResult = result;
      record.rightDurationSeconds = duration;
    } else if (eye == _HistoryEye.left) {
      record.leftResult = result;
      record.leftDurationSeconds = duration;
    } else {
      record.rightResult = result;
      record.rightDurationSeconds = duration;
    }
    record.sourceRows = [row];
  }

  final records = recordsByType.values
      .map((record) => record.freeze())
      .toList();
  records.sort(
    (a, b) =>
        _historyTypeSortOrder(a.type).compareTo(_historyTypeSortOrder(b.type)),
  );
  return records;
}

String _cell(List<String> headers, List<String> row, String header) {
  final index = headers.indexWhere(
    (candidate) => candidate.toLowerCase() == header.toLowerCase(),
  );
  if (index < 0 || row.length <= index) return '';
  return row[index];
}

String _joinDuration(String current, String next) {
  if (next.isEmpty) return current;
  if (current.isEmpty) return next;
  if (current == next) return current;
  return '$current/$next';
}

int _historyTypeSortOrder(String type) {
  switch (type) {
    case 'Distance UCVA':
      return 0;
    case 'Distance CVA':
      return 1;
    case 'Distance PVA':
      return 2;
    case 'Distance PinVA':
      return 3;
    case 'Near UCVA':
      return 4;
    case 'Near CVA':
      return 5;
    case 'Near PVA':
      return 6;
    case 'Near VA':
      return 7;
    default:
      return 100;
  }
}

String _visionTypeLabel(String visionType) {
  switch (visionType) {
    case 'Presenting Near VA':
      return 'Near PVA';
    case 'Near Corrected Visual Acuity (with Near Glasses)':
      return 'Near CVA';
    case 'Unaided Near VA':
      return 'Near UCVA';
    case 'Near Vision':
      return 'Near VA';
    case 'Right eye uncorrected vision / without glasses (UCVA)':
    case 'Left eye uncorrected vision / without glasses (UCVA)':
    case 'Right eye uncorrected vision / without glasses (UVA)':
    case 'Left eye uncorrected vision / without glasses (UVA)':
      return 'Distance UCVA';
    case 'Right eye corrected vision / with glasses (CVA)':
    case 'Left eye corrected vision / with glasses (CVA)':
      return 'Distance CVA';
    case 'Right eye presenting vision (PVA)':
    case 'Left eye presenting vision (PVA)':
      return 'Distance PVA';
    case 'Right eye pinhole vision (PinVA)':
    case 'Left eye pinhole vision (PinVA)':
      return 'Distance PinVA';
  }

  return visionType.isEmpty ? 'Unknown' : visionType;
}

_HistoryEye _eyeForVisionType(String visionType) {
  final normalized = visionType.toLowerCase();
  if (normalized.startsWith('right eye')) return _HistoryEye.right;
  if (normalized.startsWith('left eye')) return _HistoryEye.left;
  return _HistoryEye.binocular;
}

DateTime? _parseSafeDate(String raw) {
  try {
    raw = raw.trim();
    final cleaned = raw.replaceAll(
      RegExp(r'(\d{4}-\d{2}-)(\d{1,2})\d'),
      r'$1$2',
    );
    return DateTime.parse(cleaned);
  } catch (_) {
    return null;
  }
}

class _PatientHistoryGroup {
  final String patientInfo;
  final DateTime? latestDateTime;
  final List<_PatientVisionRecord> records;

  const _PatientHistoryGroup({
    required this.patientInfo,
    required this.latestDateTime,
    required this.records,
  });
}

class _PatientVisionRecord {
  final String type;
  final String rightResult;
  final String leftResult;
  final String durationSeconds;
  final List<List<String>> sourceRows;

  const _PatientVisionRecord({
    required this.type,
    required this.rightResult,
    required this.leftResult,
    required this.durationSeconds,
    required this.sourceRows,
  });
}

class _MutablePatientVisionRecord {
  final String type;
  String rightResult = '';
  String leftResult = '';
  String rightDurationSeconds = '';
  String leftDurationSeconds = '';
  List<List<String>> sourceRows = [];

  _MutablePatientVisionRecord(this.type);

  _PatientVisionRecord freeze() {
    return _PatientVisionRecord(
      type: type,
      rightResult: rightResult,
      leftResult: leftResult,
      durationSeconds: _joinDuration(rightDurationSeconds, leftDurationSeconds),
      sourceRows: sourceRows,
    );
  }
}

enum _HistoryEye { right, left, binocular }

class _PatientHistoryCard extends StatelessWidget {
  final List<String> headers;
  final _PatientHistoryGroup group;

  const _PatientHistoryCard({required this.headers, required this.group});

  String _formattedLatest() {
    final latest = group.latestDateTime;
    if (latest == null) return '';
    return DateFormat('dd MMM yyyy, hh:mm a').format(latest);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    group.patientInfo,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${group.records.length} tests',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (_formattedLatest().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(_formattedLatest(), style: theme.textTheme.bodyMedium),
            ],
            const SizedBox(height: 12),
            _HistoryTableHeader(theme: theme),
            const Divider(height: 10),
            for (final record in group.records)
              _HistoryTableRow(headers: headers, record: record),
          ],
        ),
      ),
    );
  }
}

class _HistoryTableHeader extends StatelessWidget {
  final ThemeData theme;

  const _HistoryTableHeader({required this.theme});

  @override
  Widget build(BuildContext context) {
    final style = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
    );
    return Row(
      children: [
        Expanded(flex: 4, child: Text('Type', style: style)),
        Expanded(flex: 2, child: Text('Rt', style: style)),
        Expanded(flex: 2, child: Text('Lt', style: style)),
        SizedBox(width: 36, child: Text('Sec', style: style)),
      ],
    );
  }
}

class _HistoryTableRow extends StatelessWidget {
  final List<String> headers;
  final _PatientVisionRecord record;

  const _HistoryTableRow({required this.headers, required this.record});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      onTap: () {
        final rows = record.sourceRows;
        if (rows.isEmpty) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => _HistoryDetailsSheet(
            headers: headers,
            rows: rows,
            title: '${record.type} Details',
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text(record.type, style: valueStyle)),
            Expanded(
              flex: 2,
              child: Text(
                record.rightResult.isEmpty ? '-' : record.rightResult,
                style: valueStyle,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                record.leftResult.isEmpty ? '-' : record.leftResult,
                style: valueStyle,
              ),
            ),
            SizedBox(
              width: 36,
              child: Text(
                record.durationSeconds.isEmpty ? '-' : record.durationSeconds,
                style: valueStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailsSheet extends StatelessWidget {
  final List<String> headers;
  final List<List<String>> rows;
  final String title;

  _HistoryDetailsSheet({
    required this.headers,
    List<String>? row,
    List<List<String>>? rows,
    this.title = 'Test Details',
  }) : rows = rows ?? (row == null ? const [] : [row]);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: 24,
          ),
          child: Column(
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, rowIndex) {
                    final row = rows[rowIndex];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (rows.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 6),
                            child: Text(
                              'Record ${rowIndex + 1}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        for (int i = 0; i < row.length; i++)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              i < headers.length
                                  ? headers[i]
                                  : 'Field ${i + 1}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                            subtitle: Text(
                              row[i],
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
