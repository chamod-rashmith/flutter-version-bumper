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
  required bool dryRun,
  required bool quiet,
  required bool jsonMode,
}) {
  final dir = path.dirname(pubspecPath);
  if (!isGitRepository(dir)) {
    logWarning('Not a Git repository. Skipping Git integrations.', quiet, jsonMode);
    return {'committed': false, 'tagged': false, 'pushed': false};
  }

  final commitMsg = commitMsgTemplate.replaceAll('{version}', version);
  final tagName = '$tagPrefix$version';

  if (dryRun) {
    logInfo('[Dry Run] Would run: git add ${path.basename(pubspecPath)}', quiet, jsonMode, colorCode: '\x1B[33m');
    if (doCommit) {
      logInfo('[Dry Run] Would run: git commit -m "$commitMsg"', quiet, jsonMode, colorCode: '\x1B[33m');
    }
    if (doTag) {
      logInfo('[Dry Run] Would run: git tag -a $tagName -m "Release $version"', quiet, jsonMode, colorCode: '\x1B[33m');
    }
    if (doPush) {
      logInfo('[Dry Run] Would run: git push origin HEAD', quiet, jsonMode, colorCode: '\x1B[33m');
      if (doTag) {
        logInfo('[Dry Run] Would run: git push origin $tagName', quiet, jsonMode, colorCode: '\x1B[33m');
      }
    }
    return {'committed': doCommit, 'tagged': doTag, 'pushed': doPush};
  }

  bool committed = false;
  bool tagged = false;
  bool pushed = false;

  if (doCommit) {
    final filesToAdd = [path.basename(pubspecPath)];
    final changelogFile = File(path.join(dir, 'CHANGELOG.md'));
    if (changelogFile.existsSync()) {
      filesToAdd.add('CHANGELOG.md');
    }

    final addRes = Process.runSync('git', ['add', ...filesToAdd], workingDirectory: dir);
    if (addRes.exitCode != 0) {
      logWarning('git add failed: ${addRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }

    final commitRes = Process.runSync('git', ['commit', '-m', commitMsg], workingDirectory: dir);
    if (commitRes.exitCode != 0) {
      logWarning('git commit failed: ${commitRes.stderr}', quiet, jsonMode);
      return {'committed': false, 'tagged': false, 'pushed': false};
    }
    committed = true;
    logInfo('[Git] Committed change: "$commitMsg"', quiet, jsonMode, colorCode: '\x1B[32m');
  }

  if (doTag) {
    final tagRes = Process.runSync('git', ['tag', '-a', tagName, '-m', 'Release $version'], workingDirectory: dir);
    if (tagRes.exitCode != 0) {
      logWarning('git tag failed: ${tagRes.stderr}', quiet, jsonMode);
    } else {
      tagged = true;
      logInfo('[Git] Created tag: $tagName', quiet, jsonMode, colorCode: '\x1B[32m');
    }
  }

  if (doPush) {
    logInfo('[Git] Pushing changes to remote origin...', quiet, jsonMode, colorCode: '\x1B[36m');
    final pushRes = Process.runSync('git', ['push', 'origin', 'HEAD'], workingDirectory: dir);
    if (pushRes.exitCode != 0) {
      logWarning('git push origin HEAD failed: ${pushRes.stderr}', quiet, jsonMode);
    } else {
      pushed = true;
      logInfo('[Git] Pushed changes to remote origin (HEAD)', quiet, jsonMode, colorCode: '\x1B[32m');
    }

    if (doTag && tagged) {
      final pushTagRes = Process.runSync('git', ['push', 'origin', tagName], workingDirectory: dir);
      if (pushTagRes.exitCode != 0) {
        logWarning('git push origin $tagName failed: ${pushTagRes.stderr}', quiet, jsonMode);
      } else {
        logInfo('[Git] Pushed tag $tagName to remote origin', quiet, jsonMode, colorCode: '\x1B[32m');
      }
    }
  }

  return {'committed': committed, 'tagged': tagged, 'pushed': pushed};
}

/// Safe Git environment check helper.
bool isGitRepository(String workingDirectory) {
  try {
    final result = Process.runSync('git', ['rev-parse', '--is-inside-work-tree'], workingDirectory: workingDirectory);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}
