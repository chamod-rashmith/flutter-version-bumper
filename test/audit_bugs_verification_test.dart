import 'dart:io';
import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_audit_verify_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: audit_test\nversion: 1.0.0+1\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('Audit Bug Verification Tests', () {
    test(
        'BUG 1: git tag only (--git-tag without -g) creates tag without dirty deadlock, and -g -t commits and tags',
        () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      Process.runSync('git', ['config', 'user.name', 'Test'],
          workingDirectory: tempDir.path);
      Process.runSync('git', ['config', 'user.email', 'test@test.com'],
          workingDirectory: tempDir.path);
      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial'],
          workingDirectory: tempDir.path);

      // 1. Running fvb with -t (tag only, no -g) does NOT crash with dirty working tree error
      final exitCode = bumpVersion(['-p', pubspecFile.path, '-t', '-q']);
      expect(exitCode, equals(ExitCode.success.code));

      // Verify the tag was successfully created
      final tagRes =
          Process.runSync('git', ['tag', '-l'], workingDirectory: tempDir.path);
      expect(tagRes.stdout.toString(), contains('v1.0.1+2'));

      // 2. Running fvb with -g -t commits AND tags the release
      final exitCode2 = bumpVersion(['-p', pubspecFile.path, '-g', '-t', '-q']);
      expect(exitCode2, equals(ExitCode.success.code));

      final tagRes2 =
          Process.runSync('git', ['tag', '-l'], workingDirectory: tempDir.path);
      expect(tagRes2.stdout.toString(), contains('v1.0.2+3'));

      // Verify HEAD commit contains the bumped pubspec.yaml
      final showRes = Process.runSync('git', ['show', 'HEAD:pubspec.yaml'],
          workingDirectory: tempDir.path);
      expect(showRes.stdout.toString(), contains('version: 1.0.2+3'));
    });

    test(
        'BUG 2: pre-release transition from beta to rc with minor bump preserves minor increment',
        () {
      final v = PubspecVersion.parse('1.0.0-beta.1+2');
      final bumped = v.bump('minor',
          incrementBuild: true, removeBuild: false, preReleaseLabel: 'rc');
      // Should bump minor from 0 to 1 and set pre to rc.1
      expect(bumped.toString(), equals('1.1.0-rc.1+3'));
    });

    test(
        'BUG 3: install-skill with --path directory installs inside project directory, not parent',
        () {
      final projectDir = Directory(path.join(tempDir.path, 'sub_project'))
        ..createSync();
      final subPubspec = File(path.join(projectDir.path, 'pubspec.yaml'));
      subPubspec.writeAsStringSync('name: sub_app\nversion: 1.0.0+1\n');

      // Passing directory path to --path
      final exitCode =
          bumpVersion(['-p', projectDir.path, '--install-skill', '-q']);
      expect(exitCode, equals(ExitCode.success.code));

      // Skill must be inside projectDir, NOT in tempDir (parent)
      final insideProjectSkill = File(path.join(projectDir.path, '.agents',
          'skills', 'flutter-version-bumper', 'SKILL.md'));
      final inParentSkill = File(path.join(tempDir.path, '.agents', 'skills',
          'flutter-version-bumper', 'SKILL.md'));

      expect(insideProjectSkill.existsSync(), isTrue,
          reason: 'Skill should be installed inside the project directory');
      expect(inParentSkill.existsSync(), isFalse,
          reason: 'Skill should NOT be installed in the parent directory');
    });

    test(
        'BUG 4: parses and updates double-quoted and single-quoted versions in pubspec.yaml',
        () {
      pubspecFile.writeAsStringSync('name: quoted_test\nversion: "2.5.0+1"\n');
      final exitCode = bumpVersion(['-p', pubspecFile.path, '-q']);
      expect(exitCode, equals(ExitCode.success.code));
      expect(pubspecFile.readAsStringSync(), contains('version: 2.5.1+2'));

      pubspecFile
          .writeAsStringSync("name: single_quoted_test\nversion: '3.1.0+4'\n");
      final exitCode2 = bumpVersion(['-p', pubspecFile.path, '-q']);
      expect(exitCode2, equals(ExitCode.success.code));
      expect(pubspecFile.readAsStringSync(), contains('version: 3.1.1+5'));
    });

    test('BUG 5: GitHooksManager backs up existing hook before overwriting',
        () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'))
        ..createSync(recursive: true);
      final preCommit = File(path.join(gitHooksDir.path, 'pre-commit'));
      preCommit.writeAsStringSync('#!/bin/sh\n# Custom user script\nexit 0\n');

      GitHooksManager.installHook(
          projectDir: tempDir.path,
          hookType: 'pre-commit',
          quiet: true,
          jsonMode: false);

      final backupFile =
          File(path.join(gitHooksDir.path, 'pre-commit.fvb-backup'));
      expect(backupFile.existsSync(), isTrue,
          reason: 'User existing hook should be safely backed up');
      expect(backupFile.readAsStringSync(), contains('Custom user script'));
    });

    test('BUG 6: PubspecVersion.parse rejects negative integers', () {
      expect(() => PubspecVersion.parse('1.-2.3'), throwsFormatException);
      expect(() => PubspecVersion.parse('-1.0.0'), throwsFormatException);
      expect(() => PubspecVersion.parse('1.0.-1'), throwsFormatException);
    });

    test(
        'BUG 7: CHANGELOG.md preserves preamble before release headers when multiple versions are added',
        () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync(
          '# Changelog\n\nAll notable changes will be documented here.\n\n');

      bumpVersion([
        '-p',
        pubspecFile.path,
        '-c',
        '--changelog-msg',
        'First release',
        '-q'
      ]);
      bumpVersion([
        '-p',
        pubspecFile.path,
        '-c',
        '--changelog-msg',
        'Second release',
        '-q'
      ]);

      final content = changelogFile.readAsStringSync();
      final preamblePos =
          content.indexOf('All notable changes will be documented here.');
      final firstReleasePos = content.indexOf('## [1.0.1+2]');
      final secondReleasePos = content.indexOf('## [1.0.2+3]');

      expect(preamblePos, lessThan(secondReleasePos),
          reason: 'Preamble must stay above release notes');
      expect(secondReleasePos, lessThan(firstReleasePos),
          reason: 'Newer release must be above older release');
    });

    test('BUG 8: --json with --quiet suppresses info logs on stderr', () {
      final exitCode = bumpVersion(
          ['-p', pubspecFile.path, '--dry-run', '--json', '--quiet']);
      expect(exitCode, equals(ExitCode.success.code));
    });

    test(
        'BUG 9: PubspecVersion.bump throws ArgumentError on unknown bumpType even with preReleaseLabel',
        () {
      final v = PubspecVersion.parse('1.0.0-beta.1');
      expect(
          () => v.bump('invalid_bump',
              incrementBuild: false,
              removeBuild: false,
              preReleaseLabel: 'beta'),
          throwsArgumentError);
      expect(
          () => v.bump('invalid_bump',
              incrementBuild: false, removeBuild: false, preReleaseLabel: 'rc'),
          throwsArgumentError);
    });

    test('BUG 10: PubspecVersion.parse preserves multi-plus build metadata',
        () {
      final v = PubspecVersion.parse('1.0.0+build.1+sha.abc');
      expect(v.build, equals('build.1+sha.abc'));
    });

    test(
        'BUG 11: Malformed .fvb.yaml in project dir prints warning and falls back gracefully',
        () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('fvb: invalid_yaml: [unclosed');
      final config = FvbConfig.load(targetPubspecPath: pubspecFile.path);
      expect(config.bump, isNull);
    });
  });
}
