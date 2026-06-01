# Changelog

## 2026.6.1-rc2 - 2026-06-01

- Added distance brightness calibration with a 6/19 optotype preview.
- Added pre-calibration instructions for field distance brightness setup.
- Reduced default distance-test brightness and ambient light polling frequency to reduce heat during outdoor survey use.
- Added QR scanning for participant unique IDs on the Start Test screen.
- Preserved manual patient info entry while appending or updating `[UID=...]` from scanned QR values.
- Added a separate `UniqueID` column to XLSX exports.
- Added current distance and near brightness settings to XLSX exports.
- Added the saved screen calibration size value (`PxPerCm`) to XLSX exports.
- Added phone metadata to XLSX exports, including platform, manufacturer, model, operating system, and OS version.
- Added Android and iOS camera permissions for QR scanning.
