import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import '../utils/logger.dart';
import 'skill_content.dart';

/// Manages installation and removal of AI Agent Skills for Flutter Version Bumper.
class SkillManager {
  /// Name of the skill directory.
  static const String skillName = 'flutter-version-bumper';

  /// Installs the AI Agent SKILL.md into local project skill directories
  /// (`.agents/skills/` and `.skills/`) or global home directory if [global] is true.
  static bool installSkill({
    required String targetDir,
    bool global = false,
    bool quiet = false,
    bool jsonMode = false,
    String? customContent,
  }) {
    final content = customContent ?? defaultSkillContent;
    final List<File> targetFiles =
        _getTargetSkillFiles(targetDir, global: global);

    final List<String> installedPaths = [];

    for (final file in targetFiles) {
      try {
        file.parent.createSync(recursive: true);
        file.writeAsStringSync(content);
        installedPaths.add(file.path);
      } catch (e) {
        logError('Failed to write skill file to ${file.path}: ${e.toString()}',
            jsonMode);
        return false;
      }
    }

    if (jsonMode) {
      final jsonOutput = {
        'success': true,
        'action': 'install-skill',
        'global': global,
        'installed_paths': installedPaths,
      };
      print(json.encode(jsonOutput));
    } else {
      final scopeStr = global ? 'Global' : 'Project';
      logInfo(
        '[Skill] Installed $scopeStr AI Agent Skill ($skillName):\n  - ${installedPaths.join('\n  - ')}',
        quiet,
        jsonMode,
        colorCode: '\x1B[32m',
      );
    }

    return true;
  }

  /// Removes installed SKILL.md files from local project skill directories or global folder.
  static bool removeSkill({
    required String targetDir,
    bool global = false,
    bool quiet = false,
    bool jsonMode = false,
  }) {
    final List<File> targetFiles =
        _getTargetSkillFiles(targetDir, global: global);
    final List<String> removedPaths = [];

    for (final file in targetFiles) {
      if (file.existsSync()) {
        try {
          file.deleteSync();
          removedPaths.add(file.path);
          // Try deleting parent skill directory if empty
          final parent = file.parent;
          if (parent.existsSync() && parent.listSync().isEmpty) {
            parent.deleteSync();
          }
        } catch (e) {
          logError(
              'Failed to remove skill file at ${file.path}: ${e.toString()}',
              jsonMode);
          return false;
        }
      }
    }

    if (jsonMode) {
      final jsonOutput = {
        'success': true,
        'action': 'remove-skill',
        'global': global,
        'removed_paths': removedPaths,
      };
      print(json.encode(jsonOutput));
    } else {
      final scopeStr = global ? 'Global' : 'Project';
      if (removedPaths.isNotEmpty) {
        logInfo(
          '[Skill] Removed $scopeStr AI Agent Skill ($skillName):\n  - ${removedPaths.join('\n  - ')}',
          quiet,
          jsonMode,
          colorCode: '\x1B[33m',
        );
      } else {
        logInfo(
            '[Skill] No installed $scopeStr AI Agent Skill found to remove.',
            quiet,
            jsonMode);
      }
    }

    return true;
  }

  /// Resolves the list of target SKILL.md files for given directory or global mode.
  static List<File> _getTargetSkillFiles(String targetDir,
      {required bool global}) {
    if (global) {
      final homeDir = _getHomeDir();
      if (homeDir == null) return [];
      return [
        File(path.join(homeDir, '.agents', 'skills', skillName, 'SKILL.md')),
        File(path.join(
            homeDir, '.gemini', 'config', 'skills', skillName, 'SKILL.md')),
      ];
    } else {
      return [
        File(path.join(targetDir, '.agents', 'skills', skillName, 'SKILL.md')),
        File(path.join(targetDir, '.skills', skillName, 'SKILL.md')),
      ];
    }
  }

  /// Helper to get user's home directory across platform environments.
  static String? _getHomeDir() {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  }
}
