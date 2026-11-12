import 'dart:io';

import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_issue_4_verify_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: issue_4_test\nversion: 1.0.0+1\n');
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
    Process.runSync('git', ['config', 'user.name', 'Platform Tester'],
        workingDirectory: tempDir.path);
    Process.runSync('git', ['config', 'user.email', 'tester@issue4.org'],
        workingDirectory: tempDir.path);
    Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
    Process.runSync('git', ['commit', '-m', 'Initial commit'],
        workingDirectory: tempDir.path);
  }

  group('GitHub Issue #4 Regression Tests (Windows & macOS Hardening)', () {
    test(
        'W-1 & M-1: Git hook script uses Unix LF line endings and exports macOS/Homebrew PATH',
        () {
      initGit();
      final installed = GitHooksManager.installHook(
        projectDir: tempDir.path,
        hookType: 'pre-commit',
        quiet: true,
        jsonMode: false,
      );
      expect(installed, isTrue);

      final hookFile =
          File(path.join(tempDir.path, '.git', 'hooks', 'pre-commit'));
      expect(hookFile.existsSync(), isTrue);

      final content = hookFile.readAsStringSync();
      // W-1: Must not contain CRLF to prevent /bin/sh^M bad interpreter on Windows MSYS2
      expect(content.contains('\r\n'), isFalse,
          reason: 'Git hook must strictly use Unix LF line endings');
      expect(content.startsWith('#!/bin/sh\n'), isTrue);

      // M-1: Must export common macOS binary paths for GUI Git clients
      expect(
          content,
          contains(
              'export PATH="/opt/homebrew/bin:/usr/local/bin:\$HOME/.pub-cache/bin:\$PATH"'));
    });

    test(
        'W-2: CHANGELOG.md preserves CRLF line endings throughout when updating',
        () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync(
          '# Changelog\r\n\r\nAll notable changes to this project will be documented in this file.\r\n');

      final updated = ChangelogUpdater.updateChangelog(
        pubspecPath: pubspecFile.path,
        newVersion: '1.0.1+2',
        customChangelogPath: changelogFile.path,
        customMsg: 'CRLF line ending preservation test',
        dryRun: false,
        quiet: true,
        jsonMode: false,
      );
      expect(updated, isTrue);

      final content = changelogFile.readAsStringSync();
      expect(content, contains('## [1.0.1+2]'));
      expect(content, contains('- CRLF line ending preservation test'));
      // Verify all newlines are CRLF (no isolated LF)
      final withoutCRLF = content.replaceAll('\r\n', '');
      expect(withoutCRLF.contains('\n'), isFalse,
          reason:
              'CHANGELOG.md must not contain mixed LF line endings when original was CRLF');
    });

    test(
        'W-4: Git automation normalizes nested changelog relative path to forward slashes',
        () {
      initGit();
      final nestedDir = Directory(path.join(tempDir.path, 'docs'))
        ..createSync(recursive: true);
      final customChangelog = File(path.join(nestedDir.path, 'CHANGELOG.md'));
      customChangelog.writeAsStringSync('# Docs Changelog\n');

      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Add docs changelog'],
          workingDirectory: tempDir.path);

      final exitCode = bumpVersion([
        '-p',
        pubspecFile.path,
        '-c',
        '--changelog-path',
        customChangelog.path,
        '-g',
        '-q',
      ]);
      expect(exitCode, equals(ExitCode.success.code));

      // Verify Git working tree is completely clean after committing nested changelog
      final statusRes = Process.runSync('git', ['status', '--porcelain'],
          workingDirectory: tempDir.path);
      expect((statusRes.stdout as String).trim(), isEmpty);
    });

    test(
        'U-1: TransactionManager resolves backup file inside gitdir for Git worktrees',
        () {
      // Simulate Git worktree where .git is a text file containing "gitdir: <path>"
      final realGitDir = Directory(
          path.join(tempDir.path, 'common_repo', '.git', 'worktrees', 'wt1'))
        ..createSync(recursive: true);

      final worktreeDir = Directory(path.join(tempDir.path, 'wt_project'))
        ..createSync(recursive: true);
      final dotGitFile = File(path.join(worktreeDir.path, '.git'));
      dotGitFile.writeAsStringSync('gitdir: ${realGitDir.path}\n');

      final backupFile = TransactionManager.resolveBackupFile(worktreeDir.path);
      expect(
          path.canonicalize(backupFile.path),
          equals(path
              .canonicalize(path.join(realGitDir.path, 'fvb_backup.json'))));
      // Root of worktree must NOT have backup file
      expect(backupFile.path.startsWith(worktreeDir.path), isFalse,
          reason:
              'Backup file should be stored inside the gitdir, not in the worktree root');
    });
  });
}
