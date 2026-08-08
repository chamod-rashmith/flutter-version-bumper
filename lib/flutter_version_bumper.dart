import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as path;

import 'src/changelog/changelog_updater.dart';
import 'src/cli/arg_parser.dart';
import 'src/cli/interactive_runner.dart';
import 'src/config/fvb_config.dart';
import 'src/git/git_automation.dart';
import 'src/git/git_hooks.dart';
import 'src/models/pubspec_version.dart';
import 'src/utils/file_utils.dart';
import 'src/utils/logger.dart';

export 'src/changelog/changelog_updater.dart';
export 'src/config/fvb_config.dart';
export 'src/git/git_hooks.dart';
export 'src/models/pubspec_version.dart';
export 'src/utils/file_utils.dart' show versionRegex;

/// Main entry point to process command-line arguments and perform the version bump.
void bumpVersion(List<String> arguments) {
  final parser = buildArgParser();

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    printError('Argument parsing error: ${e.toString()}');
    exit(1);
  }

  if (argResults['help'] as bool) {
    printHelp(parser);
    return;
  }

  final quiet = argResults['quiet'] as bool;
  final jsonMode = argResults['json'] as bool;
  final dryRun = argResults['dry-run'] as bool;
  final customPath = argResults['path'] as String?;
  final configPath = argResults['config-path'] as String?;

  final pubspecFile = resolvePubspecFile(customPath);

  // Handle Git Hook command flags if specified
  final installHookType = argResults['install-hook'] as String?;
  if (installHookType != null) {
    final projectDir = path.dirname(pubspecFile.path);
    final ok = GitHooksManager.installHook(
      projectDir: projectDir,
      hookType: installHookType,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) exit(1);
    return;
  }

  final removeHookType = argResults['remove-hook'] as String?;
  if (removeHookType != null) {
    final projectDir = path.dirname(pubspecFile.path);
    final ok = GitHooksManager.removeHook(
      projectDir: projectDir,
      hookType: removeHookType,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) exit(1);
    return;
  }

  // Load configuration from file (.fvb.yaml / pubspec.yaml)
  final config = FvbConfig.load(configPath: configPath, targetPubspecPath: pubspecFile.path);

  final keepBuild = (argResults['keep-build'] as bool) || (config.keepBuild ?? false);
  final removeBuild = (argResults['no-build'] as bool) || (config.noBuild ?? false);
  final runGit = (argResults['git'] as bool) || (config.git ?? false);
  final runGitTag = (argResults['git-tag'] as bool) || (config.gitTag ?? false);
  final runGitPush = (argResults['git-push'] as bool) || (config.gitPush ?? false);

  final commitMsg = (argResults['commit-msg'] as String?) ?? config.commitMsg ?? 'chore: bump version to {version}';
  final tagPrefix = (argResults['tag-prefix'] as String?) ?? config.tagPrefix ?? 'v';

  final runChangelog = (argResults['changelog'] as bool) || (config.changelog ?? false);
  final changelogMsg = (argResults['changelog-msg'] as String?) ?? config.changelogMsg;

  final interactive = argResults['interactive'] as bool;
  final preReleaseLabel = argResults['pre'] as String?;

  int? explicitBuild;
  if (argResults['build-number'] != null) {
    explicitBuild = int.tryParse(argResults['build-number'] as String);
    if (explicitBuild == null) {
      logError('build-number must be a valid integer.', jsonMode);
      exit(1);
    }
  }

  if (!pubspecFile.existsSync()) {
    logError('pubspec.yaml not found at: ${pubspecFile.path}. Make sure the path is correct.', jsonMode);
    exit(1);
  }

  String content;
  try {
    content = pubspecFile.readAsStringSync();
  } catch (e) {
    logError('Failed to read pubspec.yaml: ${e.toString()}', jsonMode);
    exit(1);
  }

  final match = versionRegex.firstMatch(content);
  if (match == null) {
    logError('Could not parse version line in pubspec.yaml.\nExpected format matches: "version: X.Y.Z" or "version: X.Y.Z+W"', jsonMode);
    exit(1);
  }

  final String oldVersionStr = match.group(1)!;
  PubspecVersion currentVersion;
  try {
    currentVersion = PubspecVersion.parse(oldVersionStr);
  } catch (e) {
    logError('Failed to parse current version "$oldVersionStr": ${e.toString()}', jsonMode);
    exit(1);
  }

  logInfo('Current version: $currentVersion', quiet, jsonMode, colorCode: '\x1B[36m');

  PubspecVersion targetVersion;

  if (interactive) {
    try {
      targetVersion = runInteractive(currentVersion, keepBuild, explicitBuild, removeBuild);
    } catch (e) {
      logError('Interactive mode error: ${e.toString()}', jsonMode);
      exit(1);
    }
  } else {
    final setVer = argResults['set'] as String?;
    if (setVer != null) {
      try {
        final parsedSet = PubspecVersion.parse(setVer);

        String? finalBuild;
        if (removeBuild) {
          finalBuild = null;
        } else if (explicitBuild != null) {
          finalBuild = explicitBuild.toString();
        } else if (parsedSet.build != null) {
          finalBuild = parsedSet.build;
        } else if (keepBuild) {
          finalBuild = currentVersion.build;
        } else {
          // Backward compatibility: increment original build number if none provided in setVer
          final int currentBuildInt = currentVersion.build != null ? (int.tryParse(currentVersion.build!) ?? 0) : 0;
          finalBuild = (currentBuildInt + 1).toString();
        }

        targetVersion = PubspecVersion(
          major: parsedSet.major,
          minor: parsedSet.minor,
          patch: parsedSet.patch,
          preRelease: parsedSet.preRelease,
          build: finalBuild,
        );
      } catch (e) {
        logError('Failed to parse set version string: ${e.toString()}', jsonMode);
        exit(1);
      }
    } else {
      final bumpType = (argResults['bump'] as String?) ?? config.bump ?? 'patch';
      targetVersion = currentVersion.bump(
        bumpType,
        incrementBuild: !keepBuild,
        explicitBuild: explicitBuild,
        removeBuild: removeBuild,
        preReleaseLabel: preReleaseLabel,
      );
    }
  }

  final String newFullStr = targetVersion.toString();
  logInfo('New version:     $newFullStr', quiet, jsonMode, colorCode: '\x1B[32m');

  // Replace old version in content and write back if not a dry-run
  final newContent = content.replaceFirst(versionRegex, 'version: $newFullStr');

  if (!dryRun) {
    try {
      pubspecFile.writeAsStringSync(newContent);
    } catch (e) {
      logError('Failed to write changes to pubspec.yaml: ${e.toString()}', jsonMode);
      exit(1);
    }
    logInfo('\n[OK] pubspec.yaml updated: $currentVersion -> $newFullStr', quiet, jsonMode, colorCode: '\x1B[33m');
  } else {
    logInfo('\n[Dry Run] pubspec.yaml would be updated: $currentVersion -> $newFullStr', quiet, jsonMode, colorCode: '\x1B[33m');
  }

  // Handle CHANGELOG.md update if enabled
  bool changelogUpdated = false;
  if (runChangelog) {
    changelogUpdated = ChangelogUpdater.updateChangelog(
      pubspecPath: pubspecFile.path,
      newVersion: newFullStr,
      customChangelogPath: config.changelogPath,
      customMsg: changelogMsg,
      dryRun: dryRun,
      quiet: quiet,
      jsonMode: jsonMode,
    );
  }

  // Handle Git integration
  bool gitCommitted = false;
  bool gitTagged = false;
  bool gitPushed = false;

  if (runGit || runGitTag || runGitPush) {
    final finalRunGit = runGit || runGitPush;
    final result = runGitAutomation(
      pubspecPath: pubspecFile.path,
      version: newFullStr,
      doCommit: finalRunGit,
      doTag: runGitTag,
      doPush: runGitPush,
      commitMsgTemplate: commitMsg,
      tagPrefix: tagPrefix,
      dryRun: dryRun,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    gitCommitted = result['committed'] ?? false;
    gitTagged = result['tagged'] ?? false;
    gitPushed = result['pushed'] ?? false;
  }

  if (jsonMode) {
    final jsonResult = {
      'success': true,
      'previous_version': currentVersion.toString(),
      'new_version': newFullStr,
      'pubspec_path': pubspecFile.path,
      'dry_run': dryRun,
      'changelog_updated': changelogUpdated,
      'git_committed': gitCommitted,
      'git_tagged': gitTagged,
      'git_pushed': gitPushed,
    };
    print(json.encode(jsonResult));
  }
}
