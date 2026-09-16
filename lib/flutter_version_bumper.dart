/// Flutter Version Bumper (FVB) library.
///
/// Provides CLI tooling and programmatic APIs for parsing, bumping, and automating
/// Semantic Versioning (SemVer) and build numbers in Flutter/Dart projects.
library flutter_version_bumper;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:io/io.dart';
import 'package:path/path.dart' as path;

import 'src/changelog/changelog_updater.dart';
import 'src/cli/arg_parser.dart';
import 'src/cli/interactive_runner.dart';
import 'src/config/fvb_config.dart';
import 'src/git/git_automation.dart';
import 'src/git/git_hooks.dart';
import 'src/models/pubspec_version.dart';
import 'src/skill/skill_manager.dart';
import 'src/utils/file_utils.dart';
import 'src/utils/logger.dart';

export 'package:io/io.dart' show ExitCode;
export 'src/changelog/changelog_updater.dart';
export 'src/config/fvb_config.dart';
export 'src/git/git_hooks.dart';
export 'src/models/pubspec_version.dart';
export 'src/skill/skill_manager.dart';
export 'src/utils/file_utils.dart' show versionRegex;

/// Main entry point to process command-line arguments and perform the version bump.
void bumpVersion(List<String> arguments) {
  final parser = buildArgParser();

  final processedArgs = <String>[];
  for (var i = 0; i < arguments.length; i++) {
    final arg = arguments[i];
    if (arg == '--install-hook') {
      processedArgs.add(arg);
      if (i + 1 >= arguments.length || arguments[i + 1].startsWith('-')) {
        processedArgs.add('pre-commit');
      }
    } else if (arg == '--remove-hook') {
      processedArgs.add(arg);
      if (i + 1 >= arguments.length || arguments[i + 1].startsWith('-')) {
        processedArgs.add('pre-commit');
      }
    } else {
      processedArgs.add(arg);
    }
  }

  ArgResults argResults;
  try {
    argResults = parser.parse(processedArgs);
  } catch (e) {
    printError('Argument parsing error: ${e.toString()}');
    exit(ExitCode.usage.code);
  }

  if (argResults['help'] as bool) {
    printHelp(parser);
    return;
  }

  final quiet = argResults['quiet'] as bool;
  final jsonMode = argResults['json'] as bool;
  final dryRun = argResults['dry-run'] as bool;
  final isGlobal = argResults['global'] as bool;
  final customPath = argResults['path'] as String?;
  final configPath = argResults['config-path'] as String?;

  // Handle Agent Skill command flags if specified
  final installSkill = argResults['install-skill'] as bool;
  if (installSkill) {
    final targetDir =
        customPath != null ? path.dirname(customPath) : Directory.current.path;
    final ok = SkillManager.installSkill(
      targetDir: targetDir,
      global: isGlobal,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) exit(ExitCode.ioError.code);
    return;
  }

  final removeSkill = argResults['remove-skill'] as bool;
  if (removeSkill) {
    final targetDir =
        customPath != null ? path.dirname(customPath) : Directory.current.path;
    final ok = SkillManager.removeSkill(
      targetDir: targetDir,
      global: isGlobal,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) exit(ExitCode.ioError.code);
    return;
  }

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
    if (!ok) exit(ExitCode.ioError.code);
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
    if (!ok) exit(ExitCode.ioError.code);
    return;
  }

  if (configPath != null && !File(configPath).existsSync()) {
    logError('Configuration file not found at: $configPath', jsonMode);
    exit(ExitCode.config.code);
  }

  // Load configuration from file (.fvb.yaml / pubspec.yaml)
  FvbConfig config;
  try {
    config = FvbConfig.load(
        configPath: configPath, targetPubspecPath: pubspecFile.path);
  } catch (e) {
    logError(e.toString(), jsonMode);
    exit(ExitCode.config.code);
  }

  final keepBuild =
      (argResults['keep-build'] as bool) || (config.keepBuild ?? false);
  final removeBuild =
      (argResults['no-build'] as bool) || (config.noBuild ?? false);
  final runGit = (argResults['git'] as bool) || (config.git ?? false);
  final runGitTag = (argResults['git-tag'] as bool) || (config.gitTag ?? false);
  final runGitPush =
      (argResults['git-push'] as bool) || (config.gitPush ?? false);
  final allowDirty =
      (argResults['allow-dirty'] as bool) || (config.allowDirty ?? false);

  final cliReleaseParsed = argResults.wasParsed('release');
  final cliBumpParsed = argResults.wasParsed('bump');
  final cliSetParsed = argResults.wasParsed('set');

  final commitMsg = (argResults['commit-msg'] as String?) ??
      config.commitMsg ??
      'chore: bump version to {version}';
  final tagPrefix =
      (argResults['tag-prefix'] as String?) ?? config.tagPrefix ?? 'v';

  final runChangelog =
      (argResults['changelog'] as bool) || (config.changelog ?? false);
  final changelogMsg =
      (argResults['changelog-msg'] as String?) ?? config.changelogMsg;

  final interactive = argResults['interactive'] as bool;
  final preReleaseLabel = argResults['pre'] as String?;

  if (cliReleaseParsed && preReleaseLabel != null) {
    logError('Cannot use --release/--promote together with --pre.', jsonMode);
    exit(ExitCode.usage.code);
  }

  if (cliReleaseParsed && cliBumpParsed) {
    logError(
        'Cannot use --release/--promote together with -b/--bump.', jsonMode);
    exit(ExitCode.usage.code);
  }

  if (cliReleaseParsed && cliSetParsed) {
    logError(
        'Cannot use --release/--promote together with -s/--set.', jsonMode);
    exit(ExitCode.usage.code);
  }

  if (argResults.wasParsed('keep-build') && argResults.wasParsed('no-build')) {
    logError('Cannot use --keep-build together with --no-build.', jsonMode);
    exit(ExitCode.usage.code);
  }

  if (argResults.wasParsed('build-number') &&
      argResults.wasParsed('no-build')) {
    logError(
        'Cannot use -n/--build-number together with --no-build.', jsonMode);
    exit(ExitCode.usage.code);
  }

  final isRelease = cliReleaseParsed ||
      (!cliBumpParsed &&
          !cliSetParsed &&
          preReleaseLabel == null &&
          (config.release ?? false));

  int? explicitBuild;
  if (argResults['build-number'] != null) {
    explicitBuild = int.tryParse(argResults['build-number'] as String);
    if (explicitBuild == null) {
      logError('build-number must be a valid integer.', jsonMode);
      exit(ExitCode.usage.code);
    }
    if (explicitBuild < 0) {
      logError('build-number must be a valid non-negative integer.', jsonMode);
      exit(ExitCode.usage.code);
    }
  }

  if (!pubspecFile.existsSync()) {
    logError(
        'pubspec.yaml not found at: ${pubspecFile.path}. Make sure the path is correct.',
        jsonMode);
    exit(ExitCode.ioError.code);
  }

  String content;
  try {
    content = pubspecFile.readAsStringSync();
  } catch (e) {
    logError('Failed to read pubspec.yaml: ${e.toString()}', jsonMode);
    exit(ExitCode.ioError.code);
  }

  final match = versionRegex.firstMatch(content);
  if (match == null) {
    logError(
        'Could not parse version line in pubspec.yaml.\nExpected format matches: "version: X.Y.Z" or "version: X.Y.Z+W"',
        jsonMode);
    exit(ExitCode.data.code);
  }

  final String oldVersionStr = match.group(1)!;
  PubspecVersion currentVersion;
  try {
    currentVersion = PubspecVersion.parse(oldVersionStr);
  } catch (e) {
    logError(
        'Failed to parse current version "$oldVersionStr": ${e.toString()}',
        jsonMode);
    exit(ExitCode.data.code);
  }

  logInfo('Current version: $currentVersion', quiet, jsonMode,
      colorCode: '\x1B[36m');

  PubspecVersion targetVersion;

  if (interactive) {
    try {
      targetVersion =
          runInteractive(currentVersion, keepBuild, explicitBuild, removeBuild);
    } catch (e) {
      logError('Interactive mode error: ${e.toString()}', jsonMode);
      exit(ExitCode.software.code);
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
          final int currentBuildInt = currentVersion.build != null
              ? (int.tryParse(currentVersion.build!) ?? 0)
              : 0;
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
        logError(
            'Failed to parse set version string: ${e.toString()}', jsonMode);
        exit(ExitCode.data.code);
      }
    } else if (isRelease) {
      if (currentVersion.preRelease == null) {
        logWarning(
            'Current version "$currentVersion" is already a stable release (has no pre-release label).',
            quiet,
            jsonMode);
      }
      targetVersion = currentVersion.promote(
        incrementBuild: !keepBuild,
        explicitBuild: explicitBuild,
        removeBuild: removeBuild,
      );
    } else {
      final bumpType =
          (argResults['bump'] as String?) ?? config.bump ?? 'patch';
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
  logInfo('New version:     $newFullStr', quiet, jsonMode,
      colorCode: '\x1B[32m');

  // Replace old version in content and write back if not a dry-run
  final newContent = content.replaceFirst(versionRegex, 'version: $newFullStr');

  if (!dryRun) {
    try {
      pubspecFile.writeAsStringSync(newContent);
    } catch (e) {
      logError(
          'Failed to write changes to pubspec.yaml: ${e.toString()}', jsonMode);
      exit(ExitCode.ioError.code);
    }
    logInfo('\n[OK] pubspec.yaml updated: $currentVersion -> $newFullStr',
        quiet, jsonMode,
        colorCode: '\x1B[33m');
  } else {
    logInfo(
        '\n[Dry Run] pubspec.yaml would be updated: $currentVersion -> $newFullStr',
        quiet,
        jsonMode,
        colorCode: '\x1B[33m');
  }

  // Handle CHANGELOG.md update if enabled
  bool changelogUpdated = false;
  final resolvedChangelogPath = runChangelog
      ? ChangelogUpdater.resolveChangelogPath(
          pubspecFile.path, config.changelogPath)
      : null;

  if (runChangelog && resolvedChangelogPath != null) {
    changelogUpdated = ChangelogUpdater.updateChangelog(
      pubspecPath: pubspecFile.path,
      newVersion: newFullStr,
      customChangelogPath: resolvedChangelogPath,
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
      changelogPath: resolvedChangelogPath,
      allowDirty: allowDirty,
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
