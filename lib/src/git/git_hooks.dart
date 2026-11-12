import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// A manager for installing and removing executable Git hooks.
class GitHooksManager {
  /// Creates a [GitHooksManager] instance.
  const GitHooksManager();

  /// Resolves the Git hooks directory across normal repositories, worktrees, and submodules.
  static Directory _resolveHooksDirectory(String projectDir) {
    try {
      final res = Process.runSync('git', ['rev-parse', '--git-path', 'hooks'],
          workingDirectory: projectDir);
      if (res.exitCode == 0) {
        final p = (res.stdout as String).trim();
        if (p.isNotEmpty) {
          final resolved = path.isAbsolute(p)
              ? p
              : path.canonicalize(path.join(projectDir, p));
          return Directory(resolved);
        }
      }
    } catch (_) {}
    return Directory(path.join(projectDir, '.git', 'hooks'));
  }

  /// Installs an executable Git pre-commit or pre-push hook.
  ///
  /// Installs the hook script into the Git hooks directory for [projectDir].
  /// The [hookType] defaults to `'pre-commit'`, but also supports `'pre-push'`.
  ///
  /// Automatically normalizes the script to Unix line endings (`\n`) to prevent
  /// shebang interpreter errors on Windows (`/bin/sh^M: bad interpreter`).
  ///
  /// If [quiet] is `true`, suppresses success notifications.
  /// If [jsonMode] is `true`, routes informational messages to standard error.
  ///
  /// Returns `true` if the hook was successfully written and marked executable;
  /// returns `false` if the hooks directory is missing or inaccessible.
  static bool installHook({
    required String projectDir,
    String hookType = 'pre-commit',
    required bool quiet,
    required bool jsonMode,
  }) {
    final gitHooksDir = _resolveHooksDirectory(projectDir);
    if (!gitHooksDir.existsSync()) {
      logError(
          'Git repository hooks directory not found at ${gitHooksDir.path}. Make sure git is initialized.',
          jsonMode);
      return false;
    }

    final hookFile = File(path.join(gitHooksDir.path, hookType));
    final scriptContent = '''#!/bin/sh
# FVB Git Hook - Validate pubspec.yaml version
export PATH="/opt/homebrew/bin:/usr/local/bin:\$HOME/.pub-cache/bin:\$PATH"
echo "🔍 Running Flutter Version Bumper $hookType check..."
if command -v fvb >/dev/null 2>&1; then
  fvb --dry-run --quiet
elif [ -f "bin/fvb.dart" ]; then
  dart run bin/fvb.dart --dry-run --quiet
elif dart pub global list 2>/dev/null | grep -q "flutter_version_bumper"; then
  dart pub global run flutter_version_bumper --dry-run --quiet
else
  echo "⚠️ Flutter Version Bumper (fvb) not found in PATH. Skipping version check."
  exit 0
fi
if [ \$? -ne 0 ]; then
  echo "❌ FVB $hookType check failed."
  exit 1
fi
echo "✅ FVB check passed."
''';

    try {
      if (hookFile.existsSync()) {
        final backupFile = File('${hookFile.path}.fvb-backup');
        try {
          hookFile.copySync(backupFile.path);
          logInfo(
              '[Git Hook] Existing $hookType backed up to ${backupFile.path}',
              quiet,
              jsonMode,
              colorCode: '\x1B[33m');
        } catch (_) {}
      }

      // Always normalize to Unix LF to prevent shebang issues on Windows MSYS2
      final normalizedScript = scriptContent.replaceAll('\r\n', '\n');
      hookFile.writeAsStringSync(normalizedScript);
      // Make executable on POSIX systems
      if (!Platform.isWindows) {
        Process.runSync('chmod', ['+x', hookFile.path]);
      }
      logInfo('[Git Hook] Installed $hookType hook at: ${hookFile.path}', quiet,
          jsonMode,
          colorCode: '\x1B[32m');
      return true;
    } catch (e) {
      logError('Failed to install Git hook: ${e.toString()}', jsonMode);
      return false;
    }
  }

  /// Removes an installed Git hook from the project.
  ///
  /// Locates and deletes the hook file matching [hookType] from the hooks directory
  /// inside [projectDir]. If a previously backed up hook (`<hookType>.fvb-backup`)
  /// exists, restores it to the original hook path.
  ///
  /// Returns `true` if the hook was successfully removed or was not present;
  /// returns `false` if an error occurred while attempting removal.
  static bool removeHook({
    required String projectDir,
    String hookType = 'pre-commit',
    required bool quiet,
    required bool jsonMode,
  }) {
    final gitHooksDir = _resolveHooksDirectory(projectDir);
    final hookFile = File(path.join(gitHooksDir.path, hookType));
    final backupFile = File('${hookFile.path}.fvb-backup');

    if (hookFile.existsSync()) {
      try {
        hookFile.deleteSync();
        logInfo('[Git Hook] Removed $hookType hook.', quiet, jsonMode,
            colorCode: '\x1B[33m');

        if (backupFile.existsSync()) {
          backupFile.renameSync(hookFile.path);
          logInfo('[Git Hook] Restored original $hookType hook from backup.',
              quiet, jsonMode,
              colorCode: '\x1B[32m');
        }
        return true;
      } catch (e) {
        logError('Failed to remove Git hook: ${e.toString()}', jsonMode);
        return false;
      }
    } else if (backupFile.existsSync()) {
      try {
        backupFile.renameSync(hookFile.path);
        logInfo('[Git Hook] Restored original $hookType hook from backup.',
            quiet, jsonMode,
            colorCode: '\x1B[32m');
        return true;
      } catch (e) {
        logError('Failed to restore Git hook from backup: ${e.toString()}',
            jsonMode);
        return false;
      }
    } else {
      logInfo('[Git Hook] No $hookType hook found to remove.', quiet, jsonMode);
      return true;
    }
  }
}
