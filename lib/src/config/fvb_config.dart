import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

/// Configuration options loaded from `.fvb.yaml` or `pubspec.yaml` (`fvb:` section).
class FvbConfig {
  /// Default bump segment ('major', 'minor', 'patch', 'build').
  final String? bump;

  /// Whether to keep current build number instead of incrementing.
  final bool? keepBuild;

  /// Whether to remove build number segment entirely.
  final bool? noBuild;

  /// Whether to commit pubspec.yaml and CHANGELOG.md automatically.
  final bool? git;

  /// Whether to create a Git tag automatically.
  final bool? gitTag;

  /// Whether to push commits and tags to remote Git origin automatically.
  final bool? gitPush;

  /// Custom commit message template (e.g., "chore: release {version}").
  final String? commitMsg;

  /// Tag prefix for Git tags (e.g., "v").
  final String? tagPrefix;

  /// Whether to automatically update CHANGELOG.md.
  final bool? changelog;

  /// Custom path to CHANGELOG.md file or directory.
  final String? changelogPath;

  /// Custom entry message for CHANGELOG.md release notes.
  final String? changelogMsg;

  /// Creates an [FvbConfig] instance with specified configuration options.
  FvbConfig({
    this.bump,
    this.keepBuild,
    this.noBuild,
    this.git,
    this.gitTag,
    this.gitPush,
    this.commitMsg,
    this.tagPrefix,
    this.changelog,
    this.changelogPath,
    this.changelogMsg,
  });

  /// Loads configuration from explicit custom path, `.fvb.yaml`, or `pubspec.yaml` (`fvb:` section).
  static FvbConfig load({String? configPath, required String targetPubspecPath}) {
    final String projectDir = path.dirname(targetPubspecPath);

    // 1. Try explicit config path or .fvb.yaml in project dir
    final String dotFvbPath = configPath ?? path.join(projectDir, '.fvb.yaml');
    final dotFvbFile = File(dotFvbPath);

    if (dotFvbFile.existsSync()) {
      try {
        final content = dotFvbFile.readAsStringSync();
        final YamlMap? yamlMap = loadYaml(content) as YamlMap?;
        if (yamlMap != null) {
          final fvbSection = yamlMap.containsKey('fvb') ? yamlMap['fvb'] as YamlMap? : yamlMap;
          if (fvbSection != null) {
            return FvbConfig.fromYaml(fvbSection);
          }
        }
      } catch (_) {}
    }

    // 2. Try fvb: section inside pubspec.yaml
    final pubspecFile = File(targetPubspecPath);
    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        final YamlMap? yamlMap = loadYaml(content) as YamlMap?;
        if (yamlMap != null && yamlMap.containsKey('fvb')) {
          final fvbSection = yamlMap['fvb'] as YamlMap?;
          if (fvbSection != null) {
            return FvbConfig.fromYaml(fvbSection);
          }
        }
      } catch (_) {}
    }

    return FvbConfig();
  }

  /// Creates an [FvbConfig] instance from a parsed YAML map.
  factory FvbConfig.fromYaml(YamlMap map) {
    return FvbConfig(
      bump: map['bump'] as String?,
      keepBuild: map['keep_build'] as bool? ?? map['keepBuild'] as bool?,
      noBuild: map['no_build'] as bool? ?? map['noBuild'] as bool?,
      git: map['git'] as bool?,
      gitTag: map['git_tag'] as bool? ?? map['gitTag'] as bool?,
      gitPush: map['git_push'] as bool? ?? map['gitPush'] as bool?,
      commitMsg: map['commit_msg'] as String? ?? map['commitMsg'] as String?,
      tagPrefix: map['tag_prefix'] as String? ?? map['tagPrefix'] as String?,
      changelog: map['changelog'] as bool?,
      changelogPath: map['changelog_path'] as String? ?? map['changelogPath'] as String?,
      changelogMsg: map['changelog_msg'] as String? ?? map['changelogMsg'] as String?,
    );
  }
}
