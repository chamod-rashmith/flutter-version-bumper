# Changelog

## [1.5.0] - 2026-09-16

### Added
- **Pre-Release Promotion (`--release` / `--promote`)**:
  - Graduate any pre-release version (e.g., `1.2.0-beta.1+2`) directly to a stable production release (`1.2.0+3`).
  - Added option `0. Promote to Stable Release` to interactive mode (`fvb -i`) when current version has a pre-release.
- **Git Working Tree Safety Guard (`--allow-dirty`)**:
  - Automatically verifies that the Git working tree has no uncommitted changes before performing commit/tag/push operations, preventing accidental commits.
  - Added `--allow-dirty` CLI flag and `allow-dirty` / `allow_dirty` configuration setting to bypass the check when intentional.
- **Standard POSIX Exit Codes (`package:io`)**:
  - Standardized exit codes across the CLI for seamless CI/CD integration:
    - `0` (`ExitCode.success`) on successful execution.
    - `64` (`ExitCode.usage`) on CLI syntax errors, conflicting arguments, or invalid build numbers.
    - `65` (`ExitCode.data`) on version string or SemVer formatting errors.
    - `74` (`ExitCode.ioError`) on file system read/write errors.
    - `78` (`ExitCode.config`) on `.fvb.yaml` configuration parsing errors.
- **Clean Asynchronous Stack Trace Handling (`package:stack_trace`)**:
  - Strips noisy internal Dart runtime frames to output concise, readable `Chain.terse` error traces on uncaught failures.
- **Strict Static Analysis Configuration**:
  - Added `analysis_options.yaml` enforcing `package:lints/recommended.yaml` and strict mode (`strict-casts`, `strict-inference`, `strict-raw-types`).
- **Modern AI Agent Skill**:
  - Modernized `SKILL.md` and embedded `defaultSkillContent` with progressive disclosure triggers, comprehensive command recipes, POSIX exit codes, and machine-readable JSON schemas.
- **Expanded Test Coverage**:
  - Added 30 new tests in `test/cli_exit_codes_and_enhancements_test.dart` bringing total passing tests to 74.

### Improved
- **Configuration Parsing**:
  - Added support for kebab-case configuration keys in `.fvb.yaml` (e.g., `allow-dirty`, `tag-prefix`, `keep-build`, `no-build`).
- **Path Resolution**:
  - Improved canonical absolute path comparison to eliminate false-positive dirty tree errors on Windows and across relative paths.

## [1.4.1] - 2026-08-08

### Fixed
- Improved `--install-hook` and `--remove-hook` argument handling to automatically default to `pre-commit` hook when specified without extra parameters.

### Added
- Comprehensive CLI option verification test suite (`test/cli_all_options_test.dart`) testing all `fvb -h` parameters and flags.

## [1.4.0] - 2026-08-08

- Added fvb --install-skill command to automatically deploy AI Agent SKILL.md into local or global agent directories

## [1.3.0] - 2026-08-08

### Added
- **Project Configuration File Support (`.fvb.yaml` / `pubspec.yaml`)**:
  - Save project-level defaults in `.fvb.yaml` or under `fvb:` in `pubspec.yaml` to avoid repeating long CLI flags.
- **Automated `CHANGELOG.md` Updater (`--changelog` / `-c`)**:
  - Automatically prepends new release sections to `CHANGELOG.md` upon version bumping (`-c` / `--changelog-msg`).
- **Git Hooks Integration (`--install-hook` / `--remove-hook`)**:
  - Easily install executable Git pre-commit or pre-push hooks (`fvb --install-hook pre-commit`) to enforce versioning checks.

### Refactored
- **Clean Modular Architecture (`lib/src/`)**:
  - Refactored monolithic codebase into dedicated modules (`models/`, `cli/`, `config/`, `git/`, `changelog/`, `utils/`) for enhanced maintainability and testability.

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
