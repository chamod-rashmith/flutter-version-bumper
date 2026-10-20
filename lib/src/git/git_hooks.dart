import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// A manager for installing and removing executable Git hooks.
class GitHooksManager {
  /// Creates a [GitHooksManager] instance.
  const GitHooksManager();

  /// Installs an executable Git pre-commit or pre-push hook.
  ///
  /// Installs the hook script into the `.git/hooks/` directory located inside [projectDir].
  /// The [hookType] defaults to `'pre-commit'`, but also supports `'pre-push'`.
  ///
  /// If [quiet] is `true`, suppresses success notifications.
  /// If [jsonMode] is `true`, routes informational messages to standard error.
  ///
  /// Returns `true` if the hook was successfully written and marked executable;
  /// returns `false` if the `.git/hooks/` directory is missing or inaccessible.
  static bool installHook({
    required String projectDir,
    String hookType = 'pre-commit',
    required bool quiet,
    required bool jsonMode,
  }) {
    final gitHooksDir = Directory(path.join(projectDir, '.git', 'hooks'));
    if (!gitHooksDir.existsSync()) {
      logError(
          'Git repository hooks directory not found at ${gitHooksDir.path}. Make sure git is initialized.',
          jsonMode);
      return false;
    }

    final hookFile = File(path.join(gitHooksDir.path, hookType));
    const scriptContent = '''#!/bin/sh
# FVB Git Hook - Validate pubspec.yaml version
echo "🔍 Running Flutter Version Bumper pre-commit check..."
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
  echo "❌ FVB pre-commit check failed."
  exit 1
fi
echo "✅ FVB check passed."
''';

    try {
      hookFile.writeAsStringSync(scriptContent);
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
  /// Locates and deletes the hook file matching [hookType] from `.git/hooks/`
  /// inside [projectDir].
  ///
  /// Returns `true` if the hook was successfully removed or was not present;
  /// returns `false` if an error occurred while attempting removal.
  static bool removeHook({
    required String projectDir,
    String hookType = 'pre-commit',
    required bool quiet,
    required bool jsonMode,
  }) {
    final hookFile = File(path.join(projectDir, '.git', 'hooks', hookType));
    if (hookFile.existsSync()) {
      try {
        hookFile.deleteSync();
        logInfo('[Git Hook] Removed $hookType hook.', quiet, jsonMode,
            colorCode: '\x1B[33m');
        return true;
      } catch (e) {
        logError('Failed to remove Git hook: ${e.toString()}', jsonMode);
        return false;
      }
    } else {
      logInfo('[Git Hook] No $hookType hook found to remove.', quiet, jsonMode);
      return true;
    }
  }
}
