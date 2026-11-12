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
import 'src/transaction/transaction_manager.dart';
import 'src/utils/file_utils.dart';
import 'src/utils/logger.dart';
import 'src/version.dart';

export 'package:io/io.dart' show ExitCode;
export 'src/changelog/changelog_updater.dart';
export 'src/config/fvb_config.dart';
export 'src/git/git_hooks.dart';
export 'src/models/pubspec_version.dart';
export 'src/skill/skill_manager.dart';
export 'src/transaction/rollback_step.dart';
export 'src/transaction/transaction_manager.dart';
export 'src/transaction/transaction_snapshot.dart';
export 'src/utils/file_utils.dart' show versionRegex;
export 'src/version.dart' show packageVersion;

/// Processes command-line arguments and performs the version bump.
///
/// Parses [arguments] to determine the target version segment, pre-release track,
/// build number configuration, changelog entries, and Git automation preferences.
///
/// Returns a standard POSIX exit code:
/// - [ExitCode.success] (`0`): The operation completed successfully.
/// - [ExitCode.usage] (`64`): Command-line syntax or conflicting flag error.
/// - [ExitCode.data] (`65`): Version string or SemVer parsing error.
/// - [ExitCode.software] (`70`): Unhandled internal software error.
/// - [ExitCode.ioError] (`74`): Filesystem read/write error.
/// - [ExitCode.config] (`78`): Configuration file parsing error.
int bumpVersion(List<String> arguments) {
  final parser = buildArgParser();

  // Support `fvb rollback` subcommand directly
  final isRollbackCmd = arguments.isNotEmpty && arguments.first == 'rollback';
  final processedArgs = <String>[];
  if (isRollbackCmd) {
    processedArgs.add('--rollback');
  }
  for (var i = (isRollbackCmd ? 1 : 0); i < arguments.length; i++) {
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
    printError('Argument parsing error: ${e.toString()}\n\n${parser.usage}');
    return ExitCode.usage.code;
  }

  if (argResults.flag('help')) {
    printHelp(parser);
    return ExitCode.success.code;
  }

  if (argResults.flag('version')) {
    if (argResults.flag('json')) {
      print(json.encode({'version': packageVersion}));
    } else {
      print('flutter_version_bumper version: $packageVersion');
    }
    return ExitCode.success.code;
  }

  final quiet = argResults.flag('quiet');
  final jsonMode = argResults.flag('json');
  final dryRun = argResults.flag('dry-run');
  final isGlobal = argResults.flag('global');
  final customPath = argResults.option('path');
  final configPath = argResults.option('config-path');

  // Helper to resolve project directory from customPath (supports both directory or pubspec.yaml path)
  String resolveTargetDirectory(String? customPath) {
    if (customPath == null) return Directory.current.path;
    final abs = path.canonicalize(path.absolute(customPath));
    return FileSystemEntity.isDirectorySync(abs) ? abs : path.dirname(abs);
  }

  // Handle manual rollback if requested via `fvb rollback` or `fvb --rollback`
  final rollbackRequested = isRollbackCmd || argResults.flag('rollback');
  if (rollbackRequested) {
    final targetDir = resolveTargetDirectory(customPath);
    final ok = TransactionManager.performManualRollback(
      projectDir: targetDir,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    return ok ? ExitCode.success.code : ExitCode.software.code;
  }

  // Handle Agent Skill command flags if specified
  final installSkill = argResults.flag('install-skill');
  if (installSkill) {
    final targetDir = resolveTargetDirectory(customPath);
    final ok = SkillManager.installSkill(
      targetDir: targetDir,
      global: isGlobal,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) return ExitCode.ioError.code;
    return ExitCode.success.code;
  }

  final removeSkill = argResults.flag('remove-skill');
  if (removeSkill) {
    final targetDir = resolveTargetDirectory(customPath);
    final ok = SkillManager.removeSkill(
      targetDir: targetDir,
      global: isGlobal,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) return ExitCode.ioError.code;
    return ExitCode.success.code;
  }

  final pubspecFile = resolvePubspecFile(customPath);

  // Handle Git Hook command flags if specified
  final installHookType = argResults.option('install-hook');
  if (installHookType != null) {
    final projectDir = path.dirname(pubspecFile.path);
    final ok = GitHooksManager.installHook(
      projectDir: projectDir,
      hookType: installHookType,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) return ExitCode.ioError.code;
    return ExitCode.success.code;
  }

  final removeHookType = argResults.option('remove-hook');
  if (removeHookType != null) {
    final projectDir = path.dirname(pubspecFile.path);
    final ok = GitHooksManager.removeHook(
      projectDir: projectDir,
      hookType: removeHookType,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    if (!ok) return ExitCode.ioError.code;
    return ExitCode.success.code;
  }

  if (configPath != null && !File(configPath).existsSync()) {
    logError('Configuration file not found at: $configPath', jsonMode);
    return ExitCode.config.code;
  }

  // Load configuration from file (.fvb.yaml / pubspec.yaml)
  FvbConfig config;
  try {
    config = FvbConfig.load(
        configPath: configPath, targetPubspecPath: pubspecFile.path);
  } catch (e) {
    logError(e.toString(), jsonMode);
    return ExitCode.config.code;
  }

  final keepBuild =
      argResults.flag('keep-build') || (config.keepBuild ?? false);
  final removeBuild = argResults.flag('no-build') || (config.noBuild ?? false);
  final runGit = argResults.flag('git') || (config.git ?? false);
  final runGitTag = argResults.flag('git-tag') || (config.gitTag ?? false);
  final runGitPush = argResults.flag('git-push') || (config.gitPush ?? false);
  final allowDirty =
      argResults.flag('allow-dirty') || (config.allowDirty ?? false);

  final cliReleaseParsed = argResults.wasParsed('release');
  final cliBumpParsed = argResults.wasParsed('bump');
  final cliSetParsed = argResults.wasParsed('set');

  final commitMsg = argResults.option('commit-msg') ??
      config.commitMsg ??
      'chore: bump version to {version}';
  final tagPrefix = argResults.option('tag-prefix') ?? config.tagPrefix ?? 'v';

  final runChangelog =
      argResults.flag('changelog') || (config.changelog ?? false);
  final changelogMsg =
      argResults.option('changelog-msg') ?? config.changelogMsg;
  final changelogPath =
      argResults.option('changelog-path') ?? config.changelogPath;

  final noRollback = argResults.flag('no-rollback');
  final rollbackOnFailureFlag = argResults.flag('rollback-on-failure');
  final rollbackOnFailure = !noRollback &&
      (argResults.wasParsed('rollback-on-failure')
          ? rollbackOnFailureFlag
          : (config.rollbackOnFailure ?? true));

  final interactive = argResults.flag('interactive');
  final preReleaseLabel = argResults.option('pre');

  if (cliReleaseParsed && preReleaseLabel != null) {
    logError('Cannot use --release/--promote together with --pre.', jsonMode);
    return ExitCode.usage.code;
  }

  if (cliReleaseParsed && cliBumpParsed) {
    logError(
        'Cannot use --release/--promote together with -b/--bump.', jsonMode);
    return ExitCode.usage.code;
  }

  if (cliReleaseParsed && cliSetParsed) {
    logError(
        'Cannot use --release/--promote together with -s/--set.', jsonMode);
    return ExitCode.usage.code;
  }

  if (argResults.wasParsed('keep-build') && argResults.wasParsed('no-build')) {
    logError('Cannot use --keep-build together with --no-build.', jsonMode);
    return ExitCode.usage.code;
  }

  if (argResults.wasParsed('build-number') &&
      argResults.wasParsed('no-build')) {
    logError(
        'Cannot use -n/--build-number together with --no-build.', jsonMode);
    return ExitCode.usage.code;
  }

  if (argResults.wasParsed('keep-build') &&
      argResults.wasParsed('build-number')) {
    logError(
        'Cannot use --keep-build together with -n/--build-number.', jsonMode);
    return ExitCode.usage.code;
  }

  final isRelease = cliReleaseParsed ||
      (!cliBumpParsed &&
          !cliSetParsed &&
          preReleaseLabel == null &&
          (config.release ?? false));

  int? explicitBuild;
  final buildNumberOpt = argResults.option('build-number');
  if (buildNumberOpt != null) {
    explicitBuild = int.tryParse(buildNumberOpt);
    if (explicitBuild == null) {
      logError('build-number must be a valid integer.', jsonMode);
      return ExitCode.usage.code;
    }
    if (explicitBuild < 0) {
      logError('build-number must be a valid non-negative integer.', jsonMode);
      return ExitCode.usage.code;
    }
  }

  if (!pubspecFile.existsSync()) {
    logError(
        'pubspec.yaml not found at: ${pubspecFile.path}. Make sure the path is correct.',
        jsonMode);
    return ExitCode.ioError.code;
  }

  String content;
  try {
    content = pubspecFile.readAsStringSync();
  } catch (e) {
    logError('Failed to read pubspec.yaml: ${e.toString()}', jsonMode);
    return ExitCode.ioError.code;
  }

  final match = versionRegex.firstMatch(content);
  if (match == null) {
    logError(
        'Could not parse version line in pubspec.yaml.\nExpected format matches: "version: X.Y.Z" or "version: X.Y.Z+W"',
        jsonMode);
    return ExitCode.data.code;
  }

  final String oldVersionStr = match.group(1)!;
  PubspecVersion currentVersion;
  try {
    currentVersion = PubspecVersion.parse(oldVersionStr);
  } catch (e) {
    logError(
        'Failed to parse current version "$oldVersionStr": ${e.toString()}',
        jsonMode);
    return ExitCode.data.code;
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
      return ExitCode.software.code;
    }
  } else {
    final setVer = argResults.option('set');
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
        return ExitCode.data.code;
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
      final bumpType = argResults.option('bump') ?? config.bump ?? 'patch';
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

  // Resolve changelog path before transaction capture
  final resolvedChangelogPath = runChangelog
      ? ChangelogUpdater.resolveChangelogPath(pubspecFile.path, changelogPath)
      : null;

  // Initialize TransactionManager to ensure atomic release execution and rollback
  final projectDir = path.dirname(pubspecFile.path);
  final transactionManager = TransactionManager(
    projectDir: projectDir,
    rollbackOnFailure: rollbackOnFailure,
    quiet: quiet,
    jsonMode: jsonMode,
  );

  if (!dryRun) {
    transactionManager.captureInitialState(
      previousVersion: currentVersion.toString(),
      newVersion: newFullStr,
      pubspecFile: pubspecFile,
      originalPubspecContent: content,
      changelogPath: resolvedChangelogPath,
    );
  }

  // Replace old version in content and write back if not a dry-run
  final newContent = content.replaceFirst(versionRegex, 'version: $newFullStr');

  if (!dryRun) {
    try {
      pubspecFile.writeAsStringSync(newContent);
    } catch (e) {
      logError(
          'Failed to write changes to pubspec.yaml: ${e.toString()}', jsonMode);
      if (transactionManager.rollbackOnFailure) {
        transactionManager.rollback();
      }
      return ExitCode.ioError.code;
    }

    transactionManager.registerRollbackStep(
      description: 'Restore pubspec.yaml to previous version ($currentVersion)',
      action: () {
        try {
          pubspecFile.writeAsStringSync(content);
        } catch (_) {}
      },
    );

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

    if (!dryRun) {
      if (changelogUpdated) {
        final originalChangelog =
            transactionManager.snapshot?.originalChangelogContent;
        final changelogExisted =
            transactionManager.snapshot?.changelogExisted ?? false;
        final changelogFile = File(resolvedChangelogPath);

        transactionManager.registerRollbackStep(
          description: 'Restore CHANGELOG.md',
          action: () {
            try {
              if (changelogExisted && originalChangelog != null) {
                changelogFile.writeAsStringSync(originalChangelog);
              } else if (!changelogExisted && changelogFile.existsSync()) {
                changelogFile.deleteSync();
              }
            } catch (_) {}
          },
        );
      } else if (transactionManager.rollbackOnFailure) {
        logError('Failed to update CHANGELOG.md during release.', jsonMode);
        transactionManager.rollback();
        return ExitCode.ioError.code;
      }
    }
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
      transactionManager: dryRun ? null : transactionManager,
      allowDirty: allowDirty,
      dryRun: dryRun,
      quiet: quiet,
      jsonMode: jsonMode,
    );
    gitCommitted = result['committed'] ?? false;
    gitTagged = result['tagged'] ?? false;
    gitPushed = result['pushed'] ?? false;
    final gitSuccess = result['success'] ?? true;

    if (!dryRun && !gitSuccess) {
      if (transactionManager.rollbackOnFailure) {
        transactionManager.rollback();
      }
      return ExitCode.software.code;
    }
  }

  // Manage transaction backup lifecycle
  if (!dryRun) {
    if (runGitPush && gitPushed) {
      // Remote push succeeded: remove local backup snapshot
      transactionManager.clearBackup();
    } else {
      // Local changes made (or commit/tag created locally): persist backup for manual rollback
      transactionManager.persistBackup();
    }
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

  return ExitCode.success.code;
}
