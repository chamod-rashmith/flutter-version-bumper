import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/logger.dart';

/// Runs standard Git commit, tagging, and push commands.
Map<String, bool> runGitAutomation({
  required String pubspecPath,
  required String version,
  required bool doCommit,
  required bool doTag,
  required bool doPush,
  required String commitMsgTemplate,
  required String tagPrefix,
  String? changelogPath,
  bool allowDirty = false,
  required bool dryRun,
  required bool quiet,
  required bool jsonMode,
}) {
  final dir = path.dirname(pubspecPath);
  if (!isGitRepository(dir)) {
    logWarning(
        'Not a Git repository. Skipping Git integrations.', quiet, jsonMode);
    return {'committed': false, 'tagged': false, 'pushed': false};
  }

  if (!allowDirty) {
    final uncommitted = getUncommittedChanges(
      dir,
      pubspecPath: pubspecPath,
      changelogPath: changelogPath,
      doCommit: doCommit,
    );
    if (uncommitted.isNotEmpty) {
      logError(
        'Git working tree has uncommitted changes:\n'
        '${uncommitted.map((f) => '  - $f').join('\n')}\n'
        'Aborting Git operations. Commit or stash your changes, or use --allow-dirty to bypass.',
        jsonMode,
      );
      return {'committed': false, 'tagged': false, 'pushed': false};
    }
  }

  final commitMsg = commitMsgTemplate.replaceAll('{version}', version);
  final tagName = '$tagPrefix$version';

  final filesToAdd = <String>[path.basename(pubspecPath)];
  if (changelogPath != null) {
    final relativeChangelog = path.relative(changelogPath, from: dir);
    filesToAdd.add(relativeChangelog);
  }

  if (dryRun) {
    if (doCommit) {
      for (final file in filesToAdd) {
        logInfo('[Dry Run] Would run: git add $file', quiet, jsonMode,
            colorCode: '\x1B[33m');
      }
      logInfo(
          '[Dry Run] Would run: git commit -m "$commitMsg"', quiet, jsonMode,
          colorCode: '\x1B[33m');
    }
    if (doTag) {
      logInfo('[Dry Run] Would run: git tag -a $tagName -m "Release $version"',
          quiet, jsonMode,
          colorCode: '\x1B[33m');
    }
    if (doPush) {
      logInfo('[Dry Run] Would run: git push origin HEAD', quiet, jsonMode,
          colorCode: '\x1B[33m');
      if (doTag) {
        logInfo(
            '[Dry Run] Would run: git push origin $tagName', quiet, jsonMode,
            colorCode: '\x1B[33m');
      }
    }
    return {'committed': doCommit, 'tagged': doTag, 'pushed': doPush};
  }

  bool committed = false;
  bool tagged = false;
  bool pushed = false;

  if (doCommit) {
    final addRes =
        Process.runSync('git', ['add', ...filesToAdd], workingDirectory: dir);
    if (addRes.exitCode != 0) {
      logWarning('git add failed: ${addRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }

    final commitRes = Process.runSync('git', ['commit', '-m', commitMsg],
        workingDirectory: dir);
    if (commitRes.exitCode != 0) {
      logWarning('git commit failed: ${commitRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }
    committed = true;
    logInfo('[Git] Committed change: "$commitMsg"', quiet, jsonMode,
        colorCode: '\x1B[32m');
  }

  if (doTag) {
    final tagRes = Process.runSync(
        'git', ['tag', '-a', tagName, '-m', 'Release $version'],
        workingDirectory: dir);
    if (tagRes.exitCode != 0) {
      logWarning('git tag failed: ${tagRes.stderr}', quiet, jsonMode);
    } else {
      tagged = true;
      logInfo('[Git] Created tag: $tagName', quiet, jsonMode,
          colorCode: '\x1B[32m');
    }
  }

  if (doPush) {
    logInfo('[Git] Pushing changes to remote origin...', quiet, jsonMode,
        colorCode: '\x1B[36m');
    final pushRes = Process.runSync('git', ['push', 'origin', 'HEAD'],
        workingDirectory: dir);
    if (pushRes.exitCode != 0) {
      logWarning(
          'git push origin HEAD failed: ${pushRes.stderr}', quiet, jsonMode);
    } else {
      pushed = true;
      logInfo('[Git] Pushed changes to remote origin (HEAD)', quiet, jsonMode,
          colorCode: '\x1B[32m');
    }

    if (doTag && tagged) {
      final pushTagRes = Process.runSync('git', ['push', 'origin', tagName],
          workingDirectory: dir);
      if (pushTagRes.exitCode != 0) {
        logWarning('git push origin $tagName failed: ${pushTagRes.stderr}',
            quiet, jsonMode);
      } else {
        logInfo('[Git] Pushed tag $tagName to remote origin', quiet, jsonMode,
            colorCode: '\x1B[32m');
      }
    }
  }

  return {'committed': committed, 'tagged': tagged, 'pushed': pushed};
}

/// Safe Git environment check helper.
bool isGitRepository(String workingDirectory) {
  try {
    final result = Process.runSync(
        'git', ['rev-parse', '--is-inside-work-tree'],
        workingDirectory: workingDirectory);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

/// Checks for uncommitted changes in the Git working tree.
/// Returns a list of dirty file paths.
List<String> getUncommittedChanges(
  String workingDirectory, {
  String? pubspecPath,
  String? changelogPath,
  bool doCommit = false,
}) {
  try {
    final result = Process.runSync(
      'git',
      ['status', '--porcelain'],
      workingDirectory: workingDirectory,
    );
    if (result.exitCode != 0) return [];

    final output = (result.stdout as String).trim();
    if (output.isEmpty) return [];

    String? repoRoot;
    final rootRes = Process.runSync(
      'git',
      ['rev-parse', '--show-toplevel'],
      workingDirectory: workingDirectory,
    );
    if (rootRes.exitCode == 0) {
      repoRoot = (rootRes.stdout as String).trim();
    }

    final lines = LineSplitter.split(output);
    final dirtyFiles = <String>[];

    for (final rawLine in lines) {
      if (rawLine.trim().isEmpty) continue;
      if (rawLine.length < 3) continue;

      var filePath = rawLine.substring(2).trim();
      if (filePath.contains(' -> ')) {
        filePath = filePath.split(' -> ').last.trim();
      }
      if (filePath.startsWith('"') &&
          filePath.endsWith('"') &&
          filePath.length >= 2) {
        filePath = filePath.substring(1, filePath.length - 1);
      }

      if (doCommit && pubspecPath != null) {
        final fullPath1 = repoRoot != null
            ? path.join(repoRoot, filePath)
            : path.join(workingDirectory, filePath);
        final fullPath2 = path.join(workingDirectory, filePath);

        if (_isSamePath(fullPath1, pubspecPath) ||
            _isSamePath(fullPath2, pubspecPath)) {
          continue;
        }

        if (changelogPath != null &&
            (_isSamePath(fullPath1, changelogPath) ||
                _isSamePath(fullPath2, changelogPath))) {
          continue;
        }
      }

      dirtyFiles.add(filePath);
    }

    return dirtyFiles;
  } catch (_) {
    return [];
  }
}

/// Helper to check if two file paths resolve to the same underlying file.
bool _isSamePath(String path1, String path2) {
  final abs1 = path.canonicalize(path.absolute(path1));
  final abs2 = path.canonicalize(path.absolute(path2));
  if (abs1.toLowerCase() == abs2.toLowerCase()) {
    return true;
  }
  try {
    final f1 = File(abs1);
    final f2 = File(abs2);
    if (f1.existsSync() && f2.existsSync()) {
      return f1.resolveSymbolicLinksSync().toLowerCase() ==
          f2.resolveSymbolicLinksSync().toLowerCase();
    }
  } catch (_) {}
  return false;
}
