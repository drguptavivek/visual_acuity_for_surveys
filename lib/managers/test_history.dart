import 'dart:io';
import 'package:device_info_sdk/device_info_sdk.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';

import '../Logger/logger.dart';
import '../utils/helpers.dart';
import '../utils/uid_helpers.dart';

class TestHistoryManager {
  static Future<void> clearHistory() async {
    final filePath = await getFilePath();
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<String> getFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/test_history.xlsx';
    return path;
  }

  static Future<void> saveTest({
    required String dateTime,
    required String patientInfo,
    required String visionType,
    required String result,
    int? durationSeconds,
    String? ambientLuxByLevel,
    String? screenBrightnessByLevel,
  }) async {
    final filePath = await getFilePath();
    final file = File(filePath);

    Excel excel;
    Sheet sheetObject;

    if (await file.exists()) {
      final bytes = file.readAsBytesSync();
      excel = Excel.decodeBytes(bytes);
      sheetObject = excel['Sheet1'];
      _ensureUniqueIdHeader(sheetObject);
      _ensureHeader(sheetObject, 'DistanceBrightnessPercent');
      _ensureHeader(sheetObject, 'NearBrightnessPercent');
      _ensureHeader(sheetObject, 'PxPerCm');
      _ensureHeader(sheetObject, 'DevicePlatform');
      _ensureHeader(sheetObject, 'DeviceManufacturer');
      _ensureHeader(sheetObject, 'DeviceModel');
      _ensureHeader(sheetObject, 'DeviceOperatingSystem');
      _ensureHeader(sheetObject, 'DeviceOsVersion');
    } else {
      excel = Excel.createExcel();
      sheetObject = excel['Sheet1'];
      sheetObject.appendRow([
        TextCellValue('DateTime'),
        TextCellValue('patientInfo'),
        TextCellValue('visionType'),
        TextCellValue('Result'),
        TextCellValue('DurationSeconds'),
        TextCellValue('AmbientLuxByLevel'),
        TextCellValue('ScreenBrightnessByLevel'),
        TextCellValue('UniqueID'),
        TextCellValue('DistanceBrightnessPercent'),
        TextCellValue('NearBrightnessPercent'),
        TextCellValue('PxPerCm'),
        TextCellValue('DevicePlatform'),
        TextCellValue('DeviceManufacturer'),
        TextCellValue('DeviceModel'),
        TextCellValue('DeviceOperatingSystem'),
        TextCellValue('DeviceOsVersion'),
      ]);
    }

    final distanceBrightness = await calibratedDistanceScreenBrightnessPercent();
    final nearBrightness = await calibratedNearScreenBrightnessPercent();
    final pxPerCm = await savedPxPerCm();
    final deviceInfo = await _deviceInfoForExport();

    sheetObject.appendRow([
      TextCellValue(dateTime),
      TextCellValue(patientInfo),
      TextCellValue(visionType),
      TextCellValue(result),
      TextCellValue(durationSeconds?.toString() ?? ''),
      TextCellValue(ambientLuxByLevel ?? ''),
      TextCellValue(screenBrightnessByLevel ?? ''),
      TextCellValue(uniqueIdFromPatientInfo(patientInfo)),
      TextCellValue(distanceBrightness.toString()),
      TextCellValue(nearBrightness.toString()),
      TextCellValue(pxPerCm?.toStringAsFixed(4) ?? ''),
      TextCellValue(deviceInfo.platform),
      TextCellValue(deviceInfo.manufacturer),
      TextCellValue(deviceInfo.model),
      TextCellValue(deviceInfo.operatingSystem),
      TextCellValue(deviceInfo.osVersion),
    ]);

    final encodedBytes = excel.encode();
    if (encodedBytes != null) {
      await file.writeAsBytes(encodedBytes);
    }
  }

  static Future<List<List<String>>> readHistory() async {
    final filePath = await getFilePath();
    final file = File(filePath);

    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Sheet1'];

    return sheet.rows
        .map((row) => row.map((cell) => cell?.value.toString() ?? '').toList())
        .toList();
  }

  static Future<List<String>> readLatestHistoryRow() async {
    final filePath = await getFilePath();
    final file = File(filePath);

    if (!await file.exists()) {
      logger.d("File does not exist: $filePath");
      return []; // no file, return empty
    }

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Sheet1'];

    // If no rows at all
    if (sheet.rows.isEmpty) {
      logger.d("No rows in the sheet");
      return [];
    }

    // Convert rows to list of string lists
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value.toString() ?? '').toList())
        .toList();

    // If only header exists
    if (rows.length <= 1) {
      logger.d("Only header row exists");
      return [];
    }

    // Latest row = last item in list (skip header at index 0)
    return rows.last;
  }

  static Future<List<List<String>>> readHistoryByPatient(
    String patientId,
  ) async {
    final filePath = await getFilePath();
    final file = File(filePath);

    if (!await file.exists()) return [];

    final bytes = await file.readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Sheet1'];

    if (sheet.rows.isEmpty) return [];

    // Convert Excel rows to list of string lists
    final rows = sheet.rows
        .map((row) => row.map((cell) => cell?.value.toString() ?? '').toList())
        .toList();

    // Remove header row (first row)
    if (rows.length <= 1) return [];

    final dataRows = rows.sublist(1);

    // Filter rows by matching patient ID (column index 2)
    final matchingRows = dataRows.where((row) {
      if (row.length <= 2) return false; // skip malformed rows
      return row[1] == patientId;
    }).toList();

    return matchingRows;
  }

  static void _ensureUniqueIdHeader(Sheet sheetObject) {
    _ensureHeader(sheetObject, 'UniqueID');
  }

  static void _ensureHeader(Sheet sheetObject, String header) {
    if (sheetObject.rows.isEmpty) return;

    final headers = sheetObject.rows.first
        .map((cell) => cell?.value.toString() ?? '')
        .toList();
    if (headers.any((value) => value.toLowerCase() == header.toLowerCase())) {
      return;
    }

    sheetObject
        .cell(
          CellIndex.indexByColumnRow(
            columnIndex: headers.length,
            rowIndex: 0,
          ),
        )
        .value = TextCellValue(header);
  }

  static Future<_ExportDeviceInfo> _deviceInfoForExport() async {
    try {
      final info = await DeviceInfoSDK.instance.getDeviceInfo();
      return _ExportDeviceInfo(
        platform: info.platform,
        manufacturer: info.manufacturer ?? '',
        model: info.model ?? '',
        operatingSystem: info.operatingSystem ?? '',
        osVersion: info.osVersion ?? '',
      );
    } catch (e) {
      logger.d('Failed to get device info for export: $e');
      return const _ExportDeviceInfo();
    }
  }
}

class _ExportDeviceInfo {
  final String platform;
  final String manufacturer;
  final String model;
  final String operatingSystem;
  final String osVersion;

  const _ExportDeviceInfo({
    this.platform = '',
    this.manufacturer = '',
    this.model = '',
    this.operatingSystem = '',
    this.osVersion = '',
  });
}
