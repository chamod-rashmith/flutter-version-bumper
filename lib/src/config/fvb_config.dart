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

  /// Whether to allow Git operations even with uncommitted changes in the working tree.
  final bool? allowDirty;

  /// Whether to promote a pre-release version to a stable release.
  final bool? release;

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
    this.allowDirty,
    this.release,
    this.commitMsg,
    this.tagPrefix,
    this.changelog,
    this.changelogPath,
    this.changelogMsg,
  });

  /// Loads configuration from explicit custom path, `.fvb.yaml`, or `pubspec.yaml` (`fvb:` section).
  static FvbConfig load(
      {String? configPath, required String targetPubspecPath}) {
    final String projectDir = path.dirname(targetPubspecPath);

    // 1. Try explicit config path or .fvb.yaml in project dir
    final String dotFvbPath = configPath ?? path.join(projectDir, '.fvb.yaml');
    final dotFvbFile = File(dotFvbPath);

    if (dotFvbFile.existsSync()) {
      try {
        final content = dotFvbFile.readAsStringSync();
        final dynamic yamlParsed = loadYaml(content);
        if (yamlParsed is YamlMap) {
          final dynamic fvbSection =
              yamlParsed.containsKey('fvb') ? yamlParsed['fvb'] : yamlParsed;
          if (fvbSection is YamlMap) {
            return FvbConfig.fromYaml(fvbSection);
          }
        } else if (configPath != null) {
          throw FormatException(
              'Configuration in "$configPath" must be a valid YAML mapping.');
        }
      } catch (e) {
        if (configPath != null) {
          throw FormatException(
              'Failed to parse configuration file at "$configPath": ${e.toString()}');
        }
      }
    }

    // 2. Try fvb: section inside pubspec.yaml
    final pubspecFile = File(targetPubspecPath);
    if (pubspecFile.existsSync()) {
      try {
        final content = pubspecFile.readAsStringSync();
        final dynamic yamlParsed = loadYaml(content);
        if (yamlParsed is YamlMap && yamlParsed.containsKey('fvb')) {
          final dynamic fvbSection = yamlParsed['fvb'];
          if (fvbSection is YamlMap) {
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
      keepBuild: map['keep_build'] as bool? ??
          map['keepBuild'] as bool? ??
          map['keep-build'] as bool?,
      noBuild: map['no_build'] as bool? ??
          map['noBuild'] as bool? ??
          map['no-build'] as bool?,
      git: map['git'] as bool?,
      gitTag: map['git_tag'] as bool? ??
          map['gitTag'] as bool? ??
          map['git-tag'] as bool?,
      gitPush: map['git_push'] as bool? ??
          map['gitPush'] as bool? ??
          map['git-push'] as bool?,
      allowDirty: map['allow_dirty'] as bool? ??
          map['allowDirty'] as bool? ??
          map['allow-dirty'] as bool?,
      release: map['release'] as bool? ?? map['promote'] as bool?,
      commitMsg: map['commit_msg'] as String? ??
          map['commitMsg'] as String? ??
          map['commit-msg'] as String?,
      tagPrefix: map['tag_prefix'] as String? ??
          map['tagPrefix'] as String? ??
          map['tag-prefix'] as String?,
      changelog: map['changelog'] as bool?,
      changelogPath: map['changelog_path'] as String? ??
          map['changelogPath'] as String? ??
          map['changelog-path'] as String?,
      changelogMsg: map['changelog_msg'] as String? ??
          map['changelogMsg'] as String? ??
          map['changelog-msg'] as String?,
    );
  }
}
