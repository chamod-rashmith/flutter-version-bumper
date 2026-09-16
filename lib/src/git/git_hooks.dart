import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// Manages installation and removal of Git hooks for FVB.
class GitHooksManager {
  /// Creates a [GitHooksManager] instance.
  const GitHooksManager();

  /// Installs an executable Git pre-commit or pre-push hook.
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
dart run bin/fvb.dart --dry-run --quiet
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

  /// Removes installed FVB Git hook.
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
