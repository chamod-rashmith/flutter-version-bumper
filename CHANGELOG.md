# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-04-08

### Added
- Comprehensive test coverage for:
    - Bumping versions without build numbers.
    - Versions with unconventional spacing.
    - Versions in complex `pubspec.yaml` structures.
    - Multiple sequential bumps.
    - The `--help` flag functionality.

### Fixed
- Resolved a "Could not parse" error in `pubspec.yaml` by refining the version regex and enabling multiline support for more reliable matching in varying file structures.

### Improved
- Increased `pubspec.yaml` parsing robustness to handle unconventional spacing and missing build numbers, verified by extensive new test cases.

## [1.0.0] - 2026-04-08

### Initial Release
- Converted from PowerShell script to cross-platform Dart CLI tool.
- Supports `major`, `minor`, `patch`, and `build` bumping.
- Option to set explicit versions (`--set`).
- Safe regex-based file parsing for `pubspec.yaml`.
- Global installation support via `dart pub global activate`.
