import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// A manager for maintaining and updating changelog release sections.
class ChangelogUpdater {
  /// Creates a [ChangelogUpdater] instance.
  const ChangelogUpdater();

  /// Resolves the canonical file path to the target CHANGELOG.md file.
  ///
  /// Derives the project directory from [pubspecPath]. If [customChangelogPath] is
  /// provided, resolves it relative to the project directory or uses it directly
  /// if already absolute. If [customChangelogPath] points to an existing directory,
  /// appends `'CHANGELOG.md'` to the path.
  static String resolveChangelogPath(String pubspecPath,
      [String? customChangelogPath]) {
    final String projectDir = path.dirname(pubspecPath);
    if (customChangelogPath != null) {
      final customPath = path.isAbsolute(customChangelogPath)
          ? customChangelogPath
          : path.join(projectDir, customChangelogPath);
      if (FileSystemEntity.isDirectorySync(customPath)) {
        return path.join(customPath, 'CHANGELOG.md');
      }
      return customPath;
    }
    return path.join(projectDir, 'CHANGELOG.md');
  }

  /// Updates or creates a CHANGELOG.md file with an entry for [newVersion].
  ///
  /// Prepends a new Markdown release section with the current date directly beneath
  /// the main `# Changelog` header if present, or at the top of the file.
  /// Handles both Unix (`\n`) and Windows (`\r\n`) line endings safely.
  ///
  /// The [customMsg] specifies the bullet note for the version entry; defaults
  /// to `"Bump version to $newVersion"` if omitted.
  ///
  /// If [dryRun] is `true`, prints the simulated changes without writing to disk.
  /// If [quiet] is `true`, suppresses console output.
  /// If [jsonMode] is `true`, routes logs to standard error.
  ///
  /// Returns `true` if the changelog was successfully updated (or simulated);
  /// otherwise `false`.
  static bool updateChangelog({
    required String pubspecPath,
    required String newVersion,
    String? customChangelogPath,
    String? customMsg,
    required bool dryRun,
    required bool quiet,
    required bool jsonMode,
  }) {
    final String changelogPath =
        resolveChangelogPath(pubspecPath, customChangelogPath);
    final File changelogFile = File(changelogPath);
    final String nowStr = DateTime.now().toIso8601String().split('T').first;

    final entryHeader = '## [$newVersion] - $nowStr';
    final entryMsg = customMsg ?? 'Bump version to $newVersion';
    final newSection = '$entryHeader\n\n- $entryMsg\n\n';

    if (dryRun) {
      logInfo('[Dry Run] Would update CHANGELOG.md at: ${changelogFile.path}',
          quiet, jsonMode,
          colorCode: '\x1B[33m');
      logInfo('[Dry Run] Added section:\n$newSection', quiet, jsonMode,
          colorCode: '\x1B[33m');
      return true;
    }

    try {
      String existingContent = '';
      if (changelogFile.existsSync()) {
        existingContent = changelogFile.readAsStringSync();
      } else {
        existingContent =
            '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n';
      }

      // Case-insensitive check for '# Changelog' header and release sections.
      String updatedContent;
      final releaseSectionMatch =
          RegExp(r'^\s*##\s+', multiLine: true).firstMatch(existingContent);

      if (releaseSectionMatch != null) {
        // If release sections already exist, insert before the first release section
        // to preserve the title and preamble description above it.
        final insertIndex = releaseSectionMatch.start;
        final beforePart = existingContent.substring(0, insertIndex);
        final afterPart = existingContent.substring(insertIndex);
        updatedContent = '$beforePart$newSection$afterPart';
      } else {
        final changelogHeaderMatch = RegExp(r'^[ \t]*#\s+Changelog[^\r\n]*',
                caseSensitive: false, multiLine: true)
            .firstMatch(existingContent);

        if (changelogHeaderMatch != null) {
          // No release sections yet. If a preamble/introductory description exists (e.g. "All notable changes"),
          // insert the new section after the preamble. Otherwise insert after the title header.
          final headerStart = changelogHeaderMatch.start;
          final afterHeader = existingContent.substring(headerStart);
          final preambleMatch = RegExp(
                  r'^([ \t]*#\s+Changelog[^\r\n]*(?:\r?\n)+(?:All notable changes[^\r\n]*(?:\r?\n)+)?)',
                  caseSensitive: false)
              .firstMatch(afterHeader);

          if (preambleMatch != null) {
            final insertIndex = headerStart + preambleMatch.group(1)!.length;
            final beforePart = existingContent.substring(0, insertIndex);
            final restPart = existingContent.substring(insertIndex);
            final separator =
                (beforePart.endsWith('\n\n') || beforePart.endsWith('\r\n\r\n'))
                    ? ''
                    : (beforePart.endsWith('\r\n') ? '\r\n' : '\n');
            updatedContent = '$beforePart$separator$newSection$restPart';
          } else {
            final insertIndex = changelogHeaderMatch.end;
            final beforePart = existingContent.substring(0, insertIndex);
            final restPart = existingContent.substring(insertIndex);
            updatedContent = '$beforePart\n\n$newSection$restPart';
          }
        } else {
          if (existingContent.trim().isEmpty) {
            updatedContent =
                '# Changelog\n\nAll notable changes to this project will be documented in this file.\n\n$newSection';
          } else {
            updatedContent = '$newSection$existingContent';
          }
        }
      }

      changelogFile.writeAsStringSync(updatedContent);
      logInfo('[OK] CHANGELOG.md updated with release notes for $newVersion',
          quiet, jsonMode,
          colorCode: '\x1B[32m');
      return true;
    } catch (e) {
      logWarning(
          'Failed to update CHANGELOG.md: ${e.toString()}', quiet, jsonMode);
      return false;
    }
  }
}
