import 'dart:io';

import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_issue_3_verify_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: issue_3_test\nversion: 1.0.0+1\n');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  void initGit() {
    Process.runSync('git', ['init'], workingDirectory: tempDir.path);
    Process.runSync('git', ['config', 'user.name', 'Issue Tester'],
        workingDirectory: tempDir.path);
    Process.runSync('git', ['config', 'user.email', 'tester@issue3.org'],
        workingDirectory: tempDir.path);
    Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
    Process.runSync('git', ['commit', '-m', 'Initial commit'],
        workingDirectory: tempDir.path);
  }

  group('GitHub Issue #3 Regression Tests', () {
    test(
        'Bug 1: rollback does not reset HEAD when FVB never created a commit, preserving user commits',
        () {
      initGit();
      final initialHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();

      // 1. Run fvb WITHOUT -g (creates local backup, mutates pubspec, but NO git commit)
      final exitCode = bumpVersion(['-p', pubspecFile.path, '-q']);
      expect(exitCode, equals(ExitCode.success.code));
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.1+2'));

      // 2. User creates an intermediate commit C2
      final userFile = File(path.join(tempDir.path, 'user_work.txt'));
      userFile.writeAsStringSync('my own work');
      Process.runSync('git', ['add', userFile.path],
          workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'User commit C2'],
          workingDirectory: tempDir.path);

      final userCommitHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(userCommitHead, isNot(equals(initialHead)));

      // 3. User runs fvb rollback to revert pubspec.yaml
      final rollbackCode =
          bumpVersion(['-p', pubspecFile.path, '--rollback', '-q']);
      expect(rollbackCode, equals(ExitCode.success.code));

      // Pubspec is restored
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.0+1'));

      // User commit C2 is strictly preserved; HEAD was NOT forcefully reset back to C1
      final headAfterRollback = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(headAfterRollback, equals(userCommitHead));
      expect(userFile.existsSync(), isTrue);
    });

    test(
        'Bug 2: uncommitted changes without --allow-dirty aborts with failure code and triggers rollback',
        () {
      initGit();
      // Create a dirty untracked file
      final dirtyFile = File(path.join(tempDir.path, 'dirty_work.txt'));
      dirtyFile.writeAsStringSync('dirty untracked file');

      // Attempt fvb -g without --allow-dirty
      final exitCode = bumpVersion(['-p', pubspecFile.path, '-g', '-q']);
      expect(exitCode, equals(ExitCode.software.code));

      // Pubspec should have been rolled back to original version
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.0+1'));
    });

    test(
        'Bug 3: rollback leaves Git index and working tree clean without staged MM state',
        () {
      initGit();
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync('# Changelog\n');
      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Add changelog'],
          workingDirectory: tempDir.path);

      // Bump with Git commit and tag
      final exitCode =
          bumpVersion(['-p', pubspecFile.path, '-c', '-g', '-t', '-q']);
      expect(exitCode, equals(ExitCode.success.code));

      // Rollback
      final rollbackCode =
          bumpVersion(['-p', pubspecFile.path, '--rollback', '-q']);
      expect(rollbackCode, equals(ExitCode.success.code));

      // Verify Git status is clean (no MM or staged discrepancies)
      final statusRes = Process.runSync('git', ['status', '--porcelain'],
          workingDirectory: tempDir.path);
      expect((statusRes.stdout as String).trim(), isEmpty);
    });

    test(
        'Bug 4: non-git directory with -g skips Git integrations gracefully with exit code 0',
        () {
      // tempDir is NOT a git repository
      final exitCode = bumpVersion(['-p', pubspecFile.path, '-g', '-q']);
      expect(exitCode, equals(ExitCode.success.code));
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.1+2'));
    });

    test(
        'Bug 5: GitHooksManager.removeHook restores original backed up hook (.fvb-backup)',
        () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'))
        ..createSync(recursive: true);
      final hookFile = File(path.join(gitHooksDir.path, 'pre-commit'));
      hookFile
          .writeAsStringSync('# Original developer pre-commit hook\nexit 0\n');

      // Install FVB hook (backs up original to pre-commit.fvb-backup)
      final installed = GitHooksManager.installHook(
        projectDir: tempDir.path,
        hookType: 'pre-commit',
        quiet: true,
        jsonMode: false,
      );
      expect(installed, isTrue);

      final backupFile = File('${hookFile.path}.fvb-backup');
      expect(backupFile.existsSync(), isTrue);
      expect(hookFile.readAsStringSync(), contains('FVB Git Hook'));

      // Remove FVB hook -> must restore original hook content from backup
      final removed = GitHooksManager.removeHook(
        projectDir: tempDir.path,
        hookType: 'pre-commit',
        quiet: true,
        jsonMode: false,
      );
      expect(removed, isTrue);
      expect(backupFile.existsSync(), isFalse);
      expect(hookFile.existsSync(), isTrue);
      expect(hookFile.readAsStringSync(),
          contains('# Original developer pre-commit hook'));
    });

    test(
        'Bug 6: --changelog-path option updates specified custom changelog file',
        () {
      final customChangelog =
          File(path.join(tempDir.path, 'docs', 'HISTORY.md'))
            ..createSync(recursive: true);
      customChangelog.writeAsStringSync('# History\n');

      final exitCode = bumpVersion([
        '-p',
        pubspecFile.path,
        '-c',
        '--changelog-path',
        customChangelog.path,
        '--changelog-msg',
        'Custom release note',
        '-q',
      ]);

      expect(exitCode, equals(ExitCode.success.code));
      expect(
          customChangelog.readAsStringSync(), contains('Custom release note'));
      expect(customChangelog.readAsStringSync(), contains('## [1.0.1+2]'));
    });

    test(
        'Bug 7: conflicting --keep-build and -n/--build-number returns exit code 64',
        () {
      final exitCode = bumpVersion(
          ['-p', pubspecFile.path, '--keep-build', '-n', '42', '-q']);
      expect(exitCode, equals(ExitCode.usage.code));
    });

    test(
        'Bug 8: ChangelogUpdater handles leading lines/badges before # Changelog header',
        () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync(
          '<!-- License and badges -->\n[![License](badge.png)](link)\n\n# Changelog\n\nAll notable changes to this project will be documented in this file.\n');

      final updated = ChangelogUpdater.updateChangelog(
        pubspecPath: pubspecFile.path,
        newVersion: '2.0.0+1',
        customChangelogPath: changelogFile.path,
        customMsg: 'Major overhaul',
        dryRun: false,
        quiet: true,
        jsonMode: false,
      );

      expect(updated, isTrue);
      final content = changelogFile.readAsStringSync();
      // Badges must stay on top before # Changelog
      expect(content.startsWith('<!-- License and badges -->'), isTrue);
      // New section must be placed below # Changelog and preamble
      expect(
          content,
          contains(
              'All notable changes to this project will be documented in this file.\n\n## [2.0.0+1]'));
    });
  });
}
