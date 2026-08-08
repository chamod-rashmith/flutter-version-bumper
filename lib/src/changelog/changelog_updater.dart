import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// Helper to handle updating CHANGELOG.md with release notes.
class ChangelogUpdater {
  /// Creates a [ChangelogUpdater] instance.
  const ChangelogUpdater();

  /// Updates or creates CHANGELOG.md with a new version section.
  static bool updateChangelog({
    required String pubspecPath,
    required String newVersion,
    String? customChangelogPath,
    String? customMsg,
    required bool dryRun,
    required bool quiet,
    required bool jsonMode,
  }) {
    final String projectDir = path.dirname(pubspecPath);
    final String changelogPath = customChangelogPath != null
        ? (FileSystemEntity.isDirectorySync(customChangelogPath)
            ? path.join(customChangelogPath, 'CHANGELOG.md')
            : customChangelogPath)
        : path.join(projectDir, 'CHANGELOG.md');

    final File changelogFile = File(changelogPath);
    final String nowStr = DateTime.now().toIso8601String().split('T').first;

    final entryHeader = '## [$newVersion] - $nowStr';
    final entryMsg = customMsg ?? 'Bump version to $newVersion';
    final newSection = '$entryHeader\n\n- $entryMsg\n\n';

    if (dryRun) {
      logInfo('[Dry Run] Would update CHANGELOG.md at: ${changelogFile.path}', quiet, jsonMode, colorCode: '\x1B[33m');
      logInfo('[Dry Run] Added section:\n$newSection', quiet, jsonMode, colorCode: '\x1B[33m');
      return true;
    }

    try {
      String existingContent = '';
      if (changelogFile.existsSync()) {
        existingContent = changelogFile.readAsStringSync();
      } else {
        existingContent = '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n';
      }

      // Prepend after title if "# Changelog" exists, otherwise prepend at top
      String updatedContent;
      if (existingContent.startsWith('# Changelog')) {
        final titleEndIndex = existingContent.indexOf('\n\n');
        if (titleEndIndex != -1) {
          final titlePart = existingContent.substring(0, titleEndIndex + 2);
          final restPart = existingContent.substring(titleEndIndex + 2);
          updatedContent = '$titlePart$newSection$restPart';
        } else {
          updatedContent = '$existingContent\n\n$newSection';
        }
      } else {
        updatedContent = '$newSection$existingContent';
      }

      changelogFile.writeAsStringSync(updatedContent);
      logInfo('[OK] CHANGELOG.md updated with release notes for $newVersion', quiet, jsonMode, colorCode: '\x1B[32m');
      return true;
    } catch (e) {
      logWarning('Failed to update CHANGELOG.md: ${e.toString()}', quiet, jsonMode);
      return false;
    }
  }
}
