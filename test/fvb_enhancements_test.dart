import 'dart:io';
import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_enhancements_test_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: test_enhancements\nversion: 1.0.0+1\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('ChangelogUpdater Tests', () {
    test('updates existing CHANGELOG.md with release section', () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync('# Changelog\n\nInitial notes.\n');

      bumpVersion(['-p', pubspecFile.path, '-c', '--changelog-msg', 'Fixed login authentication bug']);

      final content = changelogFile.readAsStringSync();
      expect(content, contains('## [1.0.1+2]'));
      expect(content, contains('- Fixed login authentication bug'));
    });

    test('creates new CHANGELOG.md if not existing', () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      expect(changelogFile.existsSync(), isFalse);

      bumpVersion(['-p', pubspecFile.path, '-c']);

      expect(changelogFile.existsSync(), isTrue);
      final content = changelogFile.readAsStringSync();
      expect(content, contains('# Changelog'));
      expect(content, contains('## [1.0.1+2]'));
    });

    test('dry run does not modify CHANGELOG.md on disk', () {
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync('# Changelog\n');

      bumpVersion(['-p', pubspecFile.path, '-c', '--dry-run']);

      final content = changelogFile.readAsStringSync();
      expect(content, equals('# Changelog\n'));
    });
  });

  group('FvbConfig Tests', () {
    test('loads settings from .fvb.yaml', () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  tag_prefix: "release-v"
  keep_build: true
''');

      final config = FvbConfig.load(targetPubspecPath: pubspecFile.path);
      expect(config.tagPrefix, equals('release-v'));
      expect(config.keepBuild, isTrue);
    });

    test('loads settings from pubspec.yaml fvb section', () {
      pubspecFile.writeAsStringSync('''
name: test_project
version: 1.0.0+1
fvb:
  tag_prefix: "v-custom"
  commit_msg: "release: {version}"
''');

      final config = FvbConfig.load(targetPubspecPath: pubspecFile.path);
      expect(config.tagPrefix, equals('v-custom'));
      expect(config.commitMsg, equals('release: {version}'));
    });

    test('config automatically enables changelog updating if configured in .fvb.yaml', () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  changelog: true
''');

      bumpVersion(['-p', pubspecFile.path]);

      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      expect(changelogFile.existsSync(), isTrue);
      expect(changelogFile.readAsStringSync(), contains('## [1.0.1+2]'));
    });
  });

  group('GitHooksManager Tests', () {
    test('installs and removes pre-commit git hook', () {
      final gitDir = Directory(path.join(tempDir.path, '.git', 'hooks'));
      gitDir.createSync(recursive: true);

      bumpVersion(['-p', pubspecFile.path, '--install-hook', 'pre-commit']);
      final hookFile = File(path.join(gitDir.path, 'pre-commit'));
      expect(hookFile.existsSync(), isTrue);
      expect(hookFile.readAsStringSync(), contains('FVB Git Hook'));

      bumpVersion(['-p', pubspecFile.path, '--remove-hook', 'pre-commit']);
      expect(hookFile.existsSync(), isFalse);
    });
  });
}
