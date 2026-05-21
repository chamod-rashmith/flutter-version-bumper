import 'dart:convert';
import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// The regex pattern used to locate the version line in pubspec.yaml.
/// It matches 'version:' at the start of a line, followed by optional spaces,
/// and captures the version string up to the first space or comment character.
final RegExp versionRegex = RegExp(r'^version:\s*([^\s#]+)', multiLine: true);

/// Represents a parsed version string conforming to Semantic Versioning (SemVer)
/// with an optional build number (e.g., "1.2.3-beta.1+45").
class PubspecVersion {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? build;

  PubspecVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.build,
  });

  /// Parses a raw version string like "1.0.0", "1.0.0+1", "1.0.0-beta.1+12".
  static PubspecVersion parse(String versionStr) {
    final cleaned = versionStr.trim();

    // Split by '+' to separate build number/metadata
    final mainParts = cleaned.split('+');
    final versionAndPre = mainParts[0];
    final buildPart = mainParts.length > 1 ? mainParts[1] : null;

    // Split by '-' to separate pre-release identifier
    final preParts = versionAndPre.split('-');
    final numbersPart = preParts[0];
    final preReleasePart = preParts.length > 1 ? preParts.sublist(1).join('-') : null;

    // Parse major, minor, patch numbers
    final versionNumbers = numbersPart.split('.');
    if (versionNumbers.length < 3) {
      throw FormatException('Invalid version format: "$versionStr". Expected X.Y.Z format.');
    }

    final major = int.tryParse(versionNumbers[0]);
    final minor = int.tryParse(versionNumbers[1]);
    final patch = int.tryParse(versionNumbers[2]);

    if (major == null || minor == null || patch == null) {
      throw FormatException('Invalid integer version segments in: "$versionStr".');
    }

    return PubspecVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preReleasePart,
      build: buildPart,
    );
  }

  /// Generates a new bumped version based on the target segment.
  PubspecVersion bump(
    String bumpType, {
    required bool incrementBuild,
    int? explicitBuild,
    required bool removeBuild,
    String? preReleaseLabel,
  }) {
    int newMajor = major;
    int newMinor = minor;
    int newPatch = patch;
    String? newPre = preRelease;

    if (preReleaseLabel != null) {
      if (preRelease != null) {
        final parts = preRelease!.split('.');
        final existingLabel = parts[0];
        if (existingLabel == preReleaseLabel) {
          if (bumpType == 'major') {
            newMajor++;
            newMinor = 0;
            newPatch = 0;
            newPre = '$preReleaseLabel.1';
          } else if (bumpType == 'minor') {
            newMinor++;
            newPatch = 0;
            newPre = '$preReleaseLabel.1';
          } else {
            // Keep major, minor, patch same, bump pre-release suffix
            int existingNum = 0;
            if (parts.length > 1) {
              existingNum = int.tryParse(parts[1]) ?? 0;
            }
            newPre = '$preReleaseLabel.${existingNum + 1}';
          }
        } else {
          // Label changed (e.g. beta -> rc). Keep version same, start new pre-release sequence
          newPre = '$preReleaseLabel.1';
        }
      } else {
        // No pre-release currently. Bump standard segment, and set pre-release to label.1
        switch (bumpType) {
          case 'major':
            newMajor++;
            newMinor = 0;
            newPatch = 0;
            break;
          case 'minor':
            newMinor++;
            newPatch = 0;
            break;
          case 'patch':
            newPatch++;
            break;
          case 'build':
            break;
        }
        newPre = '$preReleaseLabel.1';
      }
    } else {
      // Standard bump (original logic)
      switch (bumpType) {
        case 'major':
          newMajor++;
          newMinor = 0;
          newPatch = 0;
          newPre = null; // Clear pre-release on major bump
          break;
        case 'minor':
          newMinor++;
          newPatch = 0;
          newPre = null; // Clear pre-release on minor bump
          break;
        case 'patch':
          newPatch++;
          newPre = null; // Clear pre-release on patch bump
          break;
        case 'build':
          // Standard semver parts remain the same, only the build is bumped
          break;
      }
    }

    String? newBuildStr;
    if (!removeBuild) {
      if (explicitBuild != null) {
        newBuildStr = explicitBuild.toString();
      } else if (incrementBuild) {
        final currentBuildInt = build != null ? (int.tryParse(build!) ?? 0) : 0;
        newBuildStr = (currentBuildInt + 1).toString();
      } else {
        newBuildStr = build;
      }
    }

    return PubspecVersion(
      major: newMajor,
      minor: newMinor,
      patch: newPatch,
      preRelease: newPre,
      build: newBuildStr,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer('$major.$minor.$patch');
    if (preRelease != null && preRelease!.isNotEmpty) {
      sb.write('-$preRelease');
    }
    if (build != null && build!.isNotEmpty) {
      sb.write('+$build');
    }
    return sb.toString();
  }
}

/// Main entry point to process command-line arguments and perform the version bump.
void bumpVersion(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('bump',
        abbr: 'b',
        allowed: ['major', 'minor', 'patch', 'build'],
        defaultsTo: 'patch',
        help: 'Which SemVer part to bump (major, minor, patch, build)')
    ..addOption('set',
        abbr: 's',
        help: 'Explicitly set a full version string (e.g., 2.0.0, 2.0.0-beta.1+3)')
    ..addOption('build-number',
        abbr: 'n',
        help: 'Explicitly override the build number segment')
    ..addFlag('keep-build',
        abbr: 'k',
        negatable: false,
        help: 'Keep the current build number instead of incrementing')
    ..addFlag('no-build',
        negatable: false,
        help: 'Completely remove the build number segment')
    ..addFlag('git',
        abbr: 'g',
        negatable: false,
        help: 'Automatically commit the pubspec.yaml version changes')
    ..addFlag('git-tag',
        abbr: 't',
        negatable: false,
        help: 'Automatically create a git tag for the new version')
    ..addFlag('git-push',
        negatable: false,
        help: 'Automatically push committed changes and tags to git remote origin')
    ..addOption('commit-msg',
        abbr: 'm',
        defaultsTo: 'chore: bump version to {version}',
        help: 'Commit message template (use {version} as placeholder)')
    ..addOption('tag-prefix',
        defaultsTo: 'v',
        help: 'Git tag prefix')
    ..addOption('pre',
        help: 'Specify pre-release label and transition to/increment prerelease (e.g. beta, rc)')
    ..addFlag('dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Simulate changes without modifying files or git status')
    ..addOption('path',
        abbr: 'p',
        help: 'Custom path to pubspec.yaml or its parent directory')
    ..addFlag('interactive',
        abbr: 'i',
        negatable: false,
        help: 'Launch a step-by-step interactive bumping workflow')
    ..addFlag('quiet',
        abbr: 'q',
        negatable: false,
        help: 'Mute all console outputs (errors will still print)')
    ..addFlag('json',
        negatable: false,
        help: 'Format output as a structured JSON string')
    ..addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'Show FVB command line usage instructions');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } catch (e) {
    _printError('Argument parsing error: ${e.toString()}');
    exit(1);
  }

  if (argResults['help'] as bool) {
    _printHelp(parser);
    return;
  }

  final quiet = argResults['quiet'] as bool;
  final jsonMode = argResults['json'] as bool;
  final dryRun = argResults['dry-run'] as bool;
  final keepBuild = argResults['keep-build'] as bool;
  final removeBuild = argResults['no-build'] as bool;
  final runGit = argResults['git'] as bool;
  final runGitTag = argResults['git-tag'] as bool;
  final runGitPush = argResults['git-push'] as bool;
  final commitMsg = argResults['commit-msg'] as String;
  final tagPrefix = argResults['tag-prefix'] as String;
  final customPath = argResults['path'] as String?;
  final interactive = argResults['interactive'] as bool;
  final preReleaseLabel = argResults['pre'] as String?;

  int? explicitBuild;
  if (argResults['build-number'] != null) {
    explicitBuild = int.tryParse(argResults['build-number'] as String);
    if (explicitBuild == null) {
      _logError('build-number must be a valid integer.', jsonMode);
      exit(1);
    }
  }

  final pubspecFile = _resolvePubspecFile(customPath);

  if (!pubspecFile.existsSync()) {
    _logError('pubspec.yaml not found at: ${pubspecFile.path}. Make sure the path is correct.', jsonMode);
    exit(1);
  }

  String content;
  try {
    content = pubspecFile.readAsStringSync();
  } catch (e) {
    _logError('Failed to read pubspec.yaml: ${e.toString()}', jsonMode);
    exit(1);
  }

  final match = versionRegex.firstMatch(content);
  if (match == null) {
    _logError('Could not parse version line in pubspec.yaml.\nExpected format matches: "version: X.Y.Z" or "version: X.Y.Z+W"', jsonMode);
    exit(1);
  }

  final String oldVersionStr = match.group(1)!;
  PubspecVersion currentVersion;
  try {
    currentVersion = PubspecVersion.parse(oldVersionStr);
  } catch (e) {
    _logError('Failed to parse current version "$oldVersionStr": ${e.toString()}', jsonMode);
    exit(1);
  }

  _logInfo('Current version: $currentVersion', quiet, jsonMode, colorCode: '\x1B[36m');

  PubspecVersion targetVersion;
  
  if (interactive) {
    try {
      targetVersion = _runInteractive(currentVersion, keepBuild, explicitBuild, removeBuild);
    } catch (e) {
      _logError('Interactive mode error: ${e.toString()}', jsonMode);
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
        _logError('Failed to parse set version string: ${e.toString()}', jsonMode);
        exit(1);
      }
    } else {
      final bumpType = argResults['bump'] as String;
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
  _logInfo('New version:     $newFullStr', quiet, jsonMode, colorCode: '\x1B[32m');

  // Replace old version in content and write back if not a dry-run
  final newContent = content.replaceFirst(versionRegex, 'version: $newFullStr');
  
  if (!dryRun) {
    try {
      pubspecFile.writeAsStringSync(newContent);
    } catch (e) {
      _logError('Failed to write changes to pubspec.yaml: ${e.toString()}', jsonMode);
      exit(1);
    }
    _logInfo('\n[OK] pubspec.yaml updated: $currentVersion -> $newFullStr', quiet, jsonMode, colorCode: '\x1B[33m');
  } else {
    _logInfo('\n[Dry Run] pubspec.yaml would be updated: $currentVersion -> $newFullStr', quiet, jsonMode, colorCode: '\x1B[33m');
  }

  // Handle Git integration
  bool gitCommitted = false;
  bool gitTagged = false;
  bool gitPushed = false;

  if (runGit || runGitTag || runGitPush) {
    final finalRunGit = runGit || runGitPush;
    final result = _runGitAutomation(
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
      'git_committed': gitCommitted,
      'git_tagged': gitTagged,
      'git_pushed': gitPushed,
    };
    print(json.encode(jsonResult));
  }
}

/// Resolves standard or custom path to pubspec.yaml.
File _resolvePubspecFile(String? customPath) {
  if (customPath == null) {
    return File(path.join(Directory.current.path, 'pubspec.yaml'));
  }
  
  if (FileSystemEntity.isDirectorySync(customPath)) {
    return File(path.join(customPath, 'pubspec.yaml'));
  }
  return File(customPath);
}

/// Runs standard Git commit, tagging, and push commands.
Map<String, bool> _runGitAutomation({
  required String pubspecPath,
  required String version,
  required bool doCommit,
  required bool doTag,
  required bool doPush,
  required String commitMsgTemplate,
  required String tagPrefix,
  required bool dryRun,
  required bool quiet,
  required bool jsonMode,
}) {
  final dir = path.dirname(pubspecPath);
  if (!_isGitRepository(dir)) {
    _logWarning('Not a Git repository. Skipping Git integrations.', quiet, jsonMode);
    return {'committed': false, 'tagged': false, 'pushed': false};
  }

  final commitMsg = commitMsgTemplate.replaceAll('{version}', version);
  final tagName = '$tagPrefix$version';

  if (dryRun) {
    _logInfo('[Dry Run] Would run: git add ${path.basename(pubspecPath)}', quiet, jsonMode, colorCode: '\x1B[33m');
    if (doCommit) {
      _logInfo('[Dry Run] Would run: git commit -m "$commitMsg"', quiet, jsonMode, colorCode: '\x1B[33m');
    }
    if (doTag) {
      _logInfo('[Dry Run] Would run: git tag -a $tagName -m "Release $version"', quiet, jsonMode, colorCode: '\x1B[33m');
    }
    if (doPush) {
      _logInfo('[Dry Run] Would run: git push origin HEAD', quiet, jsonMode, colorCode: '\x1B[33m');
      if (doTag) {
        _logInfo('[Dry Run] Would run: git push origin $tagName', quiet, jsonMode, colorCode: '\x1B[33m');
      }
    }
    return {'committed': doCommit, 'tagged': doTag, 'pushed': doPush};
  }

  bool committed = false;
  bool tagged = false;
  bool pushed = false;

  if (doCommit) {
    final addRes = Process.runSync('git', ['add', path.basename(pubspecPath)], workingDirectory: dir);
    if (addRes.exitCode != 0) {
      _logWarning('git add failed: ${addRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }

    final commitRes = Process.runSync('git', ['commit', '-m', commitMsg], workingDirectory: dir);
    if (commitRes.exitCode != 0) {
      _logWarning('git commit failed: ${commitRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }
    committed = true;
    _logInfo('[Git] Committed change: "$commitMsg"', quiet, jsonMode, colorCode: '\x1B[32m');
  }

  if (doTag) {
    final tagRes = Process.runSync('git', ['tag', '-a', tagName, '-m', 'Release $version'], workingDirectory: dir);
    if (tagRes.exitCode != 0) {
      _logWarning('git tag failed: ${tagRes.stderr}', quiet, jsonMode);
    } else {
      tagged = true;
      _logInfo('[Git] Created tag: $tagName', quiet, jsonMode, colorCode: '\x1B[32m');
    }
  }

  if (doPush) {
    _logInfo('[Git] Pushing changes to remote origin...', quiet, jsonMode, colorCode: '\x1B[36m');
    final pushRes = Process.runSync('git', ['push', 'origin', 'HEAD'], workingDirectory: dir);
    if (pushRes.exitCode != 0) {
      _logWarning('git push origin HEAD failed: ${pushRes.stderr}', quiet, jsonMode);
    } else {
      pushed = true;
      _logInfo('[Git] Pushed changes to remote origin (HEAD)', quiet, jsonMode, colorCode: '\x1B[32m');
    }

    if (doTag && tagged) {
      final pushTagRes = Process.runSync('git', ['push', 'origin', tagName], workingDirectory: dir);
      if (pushTagRes.exitCode != 0) {
        _logWarning('git push origin $tagName failed: ${pushTagRes.stderr}', quiet, jsonMode);
      } else {
        _logInfo('[Git] Pushed tag $tagName to remote origin', quiet, jsonMode, colorCode: '\x1B[32m');
      }
    }
  }

  return {'committed': committed, 'tagged': tagged, 'pushed': pushed};
}

/// Safe Git environment check helper.
bool _isGitRepository(String workingDirectory) {
  try {
    final result = Process.runSync('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: workingDirectory);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Provides a standard terminal-based selection flow.
PubspecVersion _runInteractive(PubspecVersion current, bool keepBuild, int? explicitBuild, bool removeBuild) {
  print('🚀 \x1B[36mFlutter Version Bumper - Interactive Mode\x1B[0m');
  print('Current Version: \x1B[33m$current\x1B[0m\n');
  print('Select the part to bump:');
  
  final patchPreview = current.bump('patch', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final minorPreview = current.bump('minor', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final majorPreview = current.bump('major', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final buildPreview = current.bump('build', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);

  print('  1. Patch  (-> \x1B[32m$patchPreview\x1B[0m)');
  print('  2. Minor  (-> \x1B[32m$minorPreview\x1B[0m)');
  print('  3. Major  (-> \x1B[32m$majorPreview\x1B[0m)');
  print('  4. Build  (-> \x1B[32m$buildPreview\x1B[0m)');
  print('  5. Custom Version String');
  
  int nullAttempts = 0;
  while (true) {
    stdout.write('\nEnter choice (1-5): ');
    final choice = stdin.readLineSync()?.trim();
    if (choice == null) {
      nullAttempts++;
      if (nullAttempts > 3) {
        throw StateError('No standard input stream. Cannot run in interactive mode.');
      }
      continue;
    }
    nullAttempts = 0;

    if (choice == '1') return patchPreview;
    if (choice == '2') return minorPreview;
    if (choice == '3') return majorPreview;
    if (choice == '4') return buildPreview;
    if (choice == '5') {
      while (true) {
        stdout.write('Enter custom version (e.g., 2.0.0-beta.1+3): ');
        final customStr = stdin.readLineSync()?.trim();
        if (customStr == null) {
          throw StateError('No standard input stream. Cannot run in interactive mode.');
        }
        if (customStr.isEmpty) {
          print('\x1B[31mVersion cannot be empty.\x1B[0m');
          continue;
        }
        try {
          return PubspecVersion.parse(customStr);
        } catch (e) {
          print('\x1B[31mError: ${e.toString()}\x1B[0m');
        }
      }
    }
    print('\x1B[31mInvalid choice. Please select 1, 2, 3, 4, or 5.\x1B[0m');
  }
}

/// Print formatted CLI usage instructions.
void _printHelp(ArgParser parser) {
  print('🚀 Flutter Version Bumper (FVB)');
  print('A lightning-fast tool to automate versioning in Flutter projects.');
  print('\nUsage: fvb [options]');
  print(parser.usage);
  print('\nExamples:');
  print('  fvb                        # Bumps patch (1.0.0+1 -> 1.0.1+2)');
  print('  fvb -b minor               # Bumps minor (1.0.1+2 -> 1.1.0+3)');
  print('  fvb -s 2.0.0-beta.1        # Sets version to 2.0.0-beta.1+build');
  print('  fvb --keep-build           # Bumps patch but keeps same build number');
  print('  fvb --pre beta             # Bumps to next beta prerelease (e.g. 1.0.1-beta.1)');
  print('  fvb -g -t --git-push       # Commits, tags and pushes to Git remote origin');
  print('  fvb -i                     # Runs interactive selection CLI menu');
}

/// Output informative messages.
void _logInfo(String msg, bool quiet, bool jsonMode, {String? colorCode}) {
  if (jsonMode) {
    stderr.writeln(msg);
  } else if (!quiet) {
    if (colorCode != null) {
      print('$colorCode$msg\x1B[0m');
    } else {
      print(msg);
    }
  }
}

/// Output warning logs.
void _logWarning(String msg, bool quiet, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[33m[Warning] $msg\x1B[0m');
  } else if (!quiet) {
    print('\x1B[33m[Warning] $msg\x1B[0m');
  }
}

/// Output error messages.
void _logError(String msg, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[31mERROR: $msg\x1B[0m');
  } else {
    print('\x1B[31mERROR: $msg\x1B[0m');
  }
}

/// Standard print error function.
void _printError(String msg) {
  print('\x1B[31mERROR: $msg\x1B[0m');
}
