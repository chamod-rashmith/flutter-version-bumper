import 'dart:io';

import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_rollback_test_');
    Process.runSync('git', ['init'], workingDirectory: tempDir.path);
    Process.runSync(
        'git', ['config', 'user.email', 'test@flutter-version-bumper.org'],
        workingDirectory: tempDir.path);
    Process.runSync('git', ['config', 'user.name', 'FVB Rollback Tester'],
        workingDirectory: tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('TransactionSnapshot & RollbackStep Unit Tests', () {
    test('TransactionSnapshot serializes to JSON and deserializes correctly',
        () {
      final snapshot = TransactionSnapshot(
        previousVersion: '1.0.0+1',
        newVersion: '1.0.1+2',
        pubspecPath: '/path/to/pubspec.yaml',
        originalPubspecContent: 'name: sample\nversion: 1.0.0+1\n',
        changelogPath: '/path/to/CHANGELOG.md',
        originalChangelogContent: '## 1.0.0+1\n- Initial release\n',
        changelogExisted: true,
        initialGitHead: 'abcdef1234567890',
        createdGitCommit: '123456abcdef7890',
        createdGitTag: 'v1.0.1+2',
        timestamp: '2026-11-12T00:00:00Z',
      );

      final jsonMap = snapshot.toJson();
      expect(jsonMap['previous_version'], '1.0.0+1');
      expect(jsonMap['new_version'], '1.0.1+2');
      expect(jsonMap['pubspec_path'], '/path/to/pubspec.yaml');
      expect(jsonMap['changelog_existed'], true);
      expect(jsonMap['created_git_tag'], 'v1.0.1+2');

      final restored = TransactionSnapshot.fromJson(jsonMap);
      expect(restored.previousVersion, snapshot.previousVersion);
      expect(restored.newVersion, snapshot.newVersion);
      expect(restored.pubspecPath, snapshot.pubspecPath);
      expect(restored.originalPubspecContent, snapshot.originalPubspecContent);
      expect(restored.changelogPath, snapshot.changelogPath);
      expect(
          restored.originalChangelogContent, snapshot.originalChangelogContent);
      expect(restored.changelogExisted, snapshot.changelogExisted);
      expect(restored.initialGitHead, snapshot.initialGitHead);
      expect(restored.createdGitCommit, snapshot.createdGitCommit);
      expect(restored.createdGitTag, snapshot.createdGitTag);
      expect(restored.timestamp, snapshot.timestamp);
    });

    test('TransactionSnapshot copyWith updates specified fields', () {
      final snapshot = TransactionSnapshot(
        previousVersion: '1.0.0+1',
        newVersion: '1.0.1+2',
        pubspecPath: '/path/pubspec.yaml',
        originalPubspecContent: 'content',
        changelogExisted: false,
        timestamp: '2026-11-12T00:00:00Z',
      );

      final updated = snapshot.copyWith(
        createdGitCommit: 'sha123',
        createdGitTag: 'v1.0.1+2',
      );

      expect(updated.createdGitCommit, 'sha123');
      expect(updated.createdGitTag, 'v1.0.1+2');
      expect(updated.previousVersion, '1.0.0+1');
      expect(updated.changelogExisted, false);
    });

    test('RollbackStep holds description and invokes closure', () {
      var executed = false;
      final step = RollbackStep(
        description: 'Revert test action',
        action: () => executed = true,
      );

      expect(step.description, 'Revert test action');
      expect(executed, false);
      step.action();
      expect(executed, true);
    });
  });

  group('TransactionManager Unit Tests', () {
    test('Rollback executes registered steps in reverse LIFO order', () {
      final tm = TransactionManager(
        projectDir: tempDir.path,
        quiet: true,
      );

      final executionOrder = <int>[];
      tm.registerRollbackStep(
        description: 'Step 1',
        action: () => executionOrder.add(1),
      );
      tm.registerRollbackStep(
        description: 'Step 2',
        action: () => executionOrder.add(2),
      );
      tm.registerRollbackStep(
        description: 'Step 3',
        action: () => executionOrder.add(3),
      );

      expect(tm.steps.length, 3);
      final ok = tm.rollback();
      expect(ok, true);
      expect(executionOrder, [3, 2, 1]);
    });

    test('Persists and clears backup file inside .git directory', () {
      final tm = TransactionManager(
        projectDir: tempDir.path,
        quiet: true,
      );

      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      tm.captureInitialState(
        previousVersion: '1.0.0+1',
        newVersion: '1.0.1+2',
        pubspecFile: pubspec,
        originalPubspecContent: pubspec.readAsStringSync(),
      );

      tm.persistBackup();
      final backupFile = TransactionManager.resolveBackupFile(tempDir.path);
      expect(backupFile.existsSync(), true);

      tm.clearBackup();
      expect(backupFile.existsSync(), false);
    });

    test('performManualRollback restores pubspec and changelog and Git state',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      final changelog = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelog.writeAsStringSync('## 1.0.0+1\n- Initial release\n');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);
      final initialHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();

      // Bump version locally
      final tm = TransactionManager(projectDir: tempDir.path, quiet: true);
      tm.captureInitialState(
        previousVersion: '1.0.0+1',
        newVersion: '1.1.0+2',
        pubspecFile: pubspec,
        originalPubspecContent: pubspec.readAsStringSync(),
        changelogPath: changelog.path,
      );

      pubspec.writeAsStringSync('name: test_app\nversion: 1.1.0+2\n');
      final prevChangelog = changelog.readAsStringSync();
      changelog
          .writeAsStringSync('## 1.1.0+2\n- New feature\n\n$prevChangelog');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'chore: release 1.1.0+2'],
          workingDirectory: tempDir.path);
      final createdSha = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      Process.runSync('git', ['tag', 'v1.1.0+2'],
          workingDirectory: tempDir.path);

      tm.recordGitCommit(createdSha);
      tm.recordGitTag('v1.1.0+2');
      tm.persistBackup();

      expect(TransactionManager.resolveBackupFile(tempDir.path).existsSync(),
          true);

      // Now invoke manual rollback
      final rolledBack = TransactionManager.performManualRollback(
        projectDir: tempDir.path,
        quiet: true,
        jsonMode: false,
      );
      expect(rolledBack, true);

      // Verify Git tag deleted
      final tagCheck = Process.runSync('git', ['tag', '-l', 'v1.1.0+2'],
          workingDirectory: tempDir.path);
      expect((tagCheck.stdout as String).trim(), isEmpty);

      // Verify Git commit reset back to initial HEAD
      final currentHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(currentHead, initialHead);

      // Verify files restored verbatim
      expect(pubspec.readAsStringSync(), contains('version: 1.0.0+1'));
      expect(changelog.readAsStringSync(), isNot(contains('## 1.1.0+2')));
      expect(changelog.readAsStringSync(), contains('## 1.0.0+1'));

      // Verify backup file cleaned up
      expect(TransactionManager.resolveBackupFile(tempDir.path).existsSync(),
          false);
    });
  });

  group('CLI Transactional Rollback Integration Tests', () {
    test(
        'Automatic rollback on failure reverts pubspec.yaml when Git operation fails',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Intentionally create a tag v1.0.1+2 to cause a collision when tagging
      Process.runSync('git', ['tag', 'v1.0.1+2'],
          workingDirectory: tempDir.path);

      // Running bump with --git and --git-tag will fail on tag creation
      // With --rollback-on-failure (default), pubspec.yaml must be reverted
      final code = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-g',
        '-t',
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
      expect(pubspec.readAsStringSync(), originalContent);
    });

    test(
        '--no-rollback disables auto-rollback and leaves modified files on disk',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Create tag collision
      Process.runSync('git', ['tag', 'v1.0.1+2'],
          workingDirectory: tempDir.path);

      // With --no-rollback, failure to tag should NOT revert pubspec.yaml
      final code = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-g',
        '-t',
        '--no-rollback',
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
      // Filesystem changes remain preserved
      expect(pubspec.readAsStringSync(), contains('version: 1.0.1+2'));
    });

    test(
        'fvb rollback command successfully undoes a previous local version bump',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      final changelog = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelog.writeAsStringSync('## 1.0.0+1\n- Initial release\n');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);
      final initialHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();

      // 1. Perform a normal local bump with commit and tag and changelog
      final bumpCode = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'minor',
        '-g',
        '-t',
        '-c',
        '-q',
      ]);
      expect(bumpCode, ExitCode.success.code);
      expect(pubspec.readAsStringSync(), contains('version: 1.1.0+2'));
      expect(changelog.readAsStringSync(), contains('1.1.0+2'));

      final tagBeforeRollback = (Process.runSync(
                  'git', ['tag', '-l', 'v1.1.0+2'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(tagBeforeRollback, 'v1.1.0+2');

      // 2. Perform `fvb rollback` command
      final rollbackCode = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);
      expect(rollbackCode, ExitCode.success.code);

      // Verify tag deleted
      final tagAfterRollback = (Process.runSync(
                  'git', ['tag', '-l', 'v1.1.0+2'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(tagAfterRollback, isEmpty);

      // Verify commit reverted to initial HEAD
      final currentHead = (Process.runSync('git', ['rev-parse', 'HEAD'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(currentHead, initialHead);

      // Verify pubspec.yaml and CHANGELOG.md restored
      expect(pubspec.readAsStringSync(), originalContent);
      expect(changelog.readAsStringSync(), isNot(contains('1.1.0+2')));
      expect(changelog.readAsStringSync(), contains('1.0.0+1'));
    });

    test(
        'fvb --rollback flag undoes version bump even when changelog did not exist before',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 2.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      final changelog = File(path.join(tempDir.path, 'CHANGELOG.md'));
      expect(changelog.existsSync(), false);

      // Bump with -c (creates CHANGELOG.md)
      final bumpCode = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-c',
        '-q',
      ]);
      expect(bumpCode, ExitCode.success.code);
      expect(changelog.existsSync(), true);

      // Rollback via --rollback
      final rollbackCode = bumpVersion([
        '--rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);
      expect(rollbackCode, ExitCode.success.code);

      // pubspec restored
      expect(pubspec.readAsStringSync(), originalContent);
      // changelog deleted since it did not exist before
      expect(changelog.existsSync(), false);
    });

    test('fvb rollback when no backup exists returns failure code gracefully',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      final code = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
    });

    test('fvb rollback with corrupted backup JSON file handles error cleanly',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      final backupFile = TransactionManager.resolveBackupFile(tempDir.path);
      backupFile.parent.createSync(recursive: true);
      backupFile.writeAsStringSync('{corrupted_invalid_json:');

      final code = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
    });

    test(
        '.fvb.yaml configuration with rollback_on_failure: false disables rollback',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('fvb:\n  rollback_on_failure: false\n');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Force tag collision
      Process.runSync('git', ['tag', 'v1.0.1+2'],
          workingDirectory: tempDir.path);

      final code = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-g',
        '-t',
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
      // With config rollback_on_failure: false, changes remain preserved
      expect(pubspec.readAsStringSync(), contains('version: 1.0.1+2'));
    });

    test('pre-commit hook failure triggers automatic rollback of files', () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Install a failing pre-commit hook
      final hookFile =
          File(path.join(tempDir.path, '.git', 'hooks', 'pre-commit'));
      hookFile.parent.createSync(recursive: true);
      hookFile.writeAsStringSync('#!/bin/sh\nexit 1\n');
      if (!Platform.isWindows) {
        Process.runSync('chmod', ['+x', hookFile.path]);
      }

      // Version bump with Git commit should be rejected by hook and rolled back
      final code = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-g',
        '-q',
      ]);

      expect(code, isNot(ExitCode.success.code));
      // Files must be cleanly restored to initial state
      expect(pubspec.readAsStringSync(), originalContent);
    });

    test(
        'Non-git directory creates root .fvb_backup.json and can be rolled back',
        () {
      final nonGitDir = Directory.systemTemp.createTempSync('fvb_nongit_test_');
      try {
        final pubspec = File(path.join(nonGitDir.path, 'pubspec.yaml'));
        final originalContent = 'name: nongit_app\nversion: 1.0.0+1\n';
        pubspec.writeAsStringSync(originalContent);

        // Bump in non-git directory
        final bumpCode = bumpVersion([
          '--path',
          pubspec.path,
          '-b',
          'minor',
          '-q',
        ]);
        expect(bumpCode, ExitCode.success.code);
        expect(pubspec.readAsStringSync(), contains('version: 1.1.0+2'));

        // Check root backup was created
        final rootBackup = File(path.join(nonGitDir.path, '.fvb_backup.json'));
        expect(rootBackup.existsSync(), true);

        // Manual rollback
        final rollbackCode = bumpVersion([
          'rollback',
          '--path',
          pubspec.path,
          '-q',
        ]);
        expect(rollbackCode, ExitCode.success.code);
        expect(pubspec.readAsStringSync(), originalContent);
        expect(rootBackup.existsSync(), false);
      } finally {
        if (nonGitDir.existsSync()) {
          try {
            nonGitDir.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    });

    test('Custom tag prefix is accurately recorded and removed on rollback',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      final originalContent = 'name: test_app\nversion: 1.0.0+1\n';
      pubspec.writeAsStringSync(originalContent);

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      final bumpCode = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-g',
        '-t',
        '--tag-prefix',
        'release-',
        '-q',
      ]);
      expect(bumpCode, ExitCode.success.code);

      // Verify custom tag release-1.0.1+2 exists
      final tagCheck = (Process.runSync('git', ['tag', '-l', 'release-1.0.1+2'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(tagCheck, 'release-1.0.1+2');

      // Rollback
      final rollbackCode = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);
      expect(rollbackCode, ExitCode.success.code);

      // Verify custom tag deleted
      final tagAfter = (Process.runSync('git', ['tag', '-l', 'release-1.0.1+2'],
                  workingDirectory: tempDir.path)
              .stdout as String)
          .trim();
      expect(tagAfter, isEmpty);
      expect(pubspec.readAsStringSync(), originalContent);
    });

    test(
        'Consecutive fvb rollback calls are safe and report no backup to rollback',
        () {
      final pubspec = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspec.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      Process.runSync('git', ['add', '.'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Bump
      final bumpCode = bumpVersion([
        '--path',
        pubspec.path,
        '-b',
        'patch',
        '-q',
      ]);
      expect(bumpCode, ExitCode.success.code);

      // First rollback succeeds
      final firstRollback = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);
      expect(firstRollback, ExitCode.success.code);

      // Second rollback fails gracefully because backup was already consumed
      final secondRollback = bumpVersion([
        'rollback',
        '--path',
        pubspec.path,
        '-q',
      ]);
      expect(secondRollback, isNot(ExitCode.success.code));
    });
  });
}
