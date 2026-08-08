# Changelog

## [1.3.0] - 2026-08-08

- Added config file support, automated changelog updater, git hooks installer, and modularized codebase into lib/src/

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-05-21

### Added
- **Automated Prerelease Bumping (`--pre` / `--prerelease <label>`)**:
  - Automatically transitions stable versions to prereleases (e.g. `1.0.0` -> `1.0.1-beta.1`).
  - Increments prerelease suffix counters when bumping the same label (e.g. `1.0.1-beta.1` -> `1.0.1-beta.2`).
  - Gracefully transitions between different labels (e.g. `beta.2` -> `rc.1`).
  - Seamlessly promotes to stable version track when running a standard bump without `--pre`.
- **Git Push Automation (`--git-push`)**:
  - Push committed files and created tags directly to Git remote origin (`git push origin HEAD` and `git push origin <tagName>`) in one CLI invocation.
  - Full dry-run (`-d`) simulation reporting support.

## [1.1.0] - 2026-05-21

### Added
- **Full SemVer & Pre-release Support**: Bumper can parse and process versions with pre-release identifiers and metadata (e.g. `1.0.0-beta.1+12`).
- **Interactive Mode**: Launch via `fvb -i` to bump versions step-by-step through a friendly interactive terminal selector.
- **Customizable Build Numbers**:
    - `--keep-build` (`-k`) to keep build number constant.
    - `-n`/`--build-number` to explicitly override the build number.
    - `--no-build` to completely remove the build number segment.
- **Git Commit & Tagging Automation**: Staging, committing (`-g`/`--commit-msg`), and tagging (`-t`/`--tag-prefix`) of the bumped version.
- **Dry-run Mode (`-d`)**: Safe simulation of filesystem and git actions.
- **Monorepo / Custom Path (`-p`/`--path`)**: Support custom paths for targeting monorepos.
- **Quiet & JSON Outputs**: `--json` and `--quiet` (`-q`) flags optimized for automation and CI/CD pipelines.
- **Comprehensive Test Suite**: Expanded the test file covering all new advanced CLI features.

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
