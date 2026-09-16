import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_enhancements_suite_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile
        .writeAsStringSync('name: suite_test\nversion: 1.2.0-beta.1+2\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('Standard POSIX Exit Codes (package:io ExitCode)', () {
    test('ExitCode.usage.code (64) for unknown CLI argument', () {
      final res =
          Process.runSync('dart', ['bin/fvb.dart', '--completely-unknown-arg']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(), contains('ERROR: Argument parsing error'));
    });

    test('ExitCode.usage.code (64) for invalid build-number', () {
      final res = Process.runSync('dart',
          ['bin/fvb.dart', '-p', pubspecFile.path, '-n', 'not-a-number']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('build-number must be a valid integer'));
    });

    test('ExitCode.usage.code (64) for conflicting --release and --pre flags',
        () {
      final res = Process.runSync('dart', [
        'bin/fvb.dart',
        '-p',
        pubspecFile.path,
        '--release',
        '--pre',
        'beta'
      ]);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('Cannot use --release/--promote together with --pre'));
    });

    test('ExitCode.usage.code (64) for conflicting --release and -b flags', () {
      final res = Process.runSync('dart',
          ['bin/fvb.dart', '-p', pubspecFile.path, '--release', '-b', 'minor']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('Cannot use --release/--promote together with -b/--bump'));
    });

    test('ExitCode.usage.code (64) for conflicting --release and -s flags', () {
      final res = Process.runSync('dart',
          ['bin/fvb.dart', '-p', pubspecFile.path, '--release', '-s', '2.0.0']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('Cannot use --release/--promote together with -s/--set'));
    });

    test('ExitCode.usage.code (64) for conflicting --keep-build and --no-build',
        () {
      final res = Process.runSync('dart', [
        'bin/fvb.dart',
        '-p',
        pubspecFile.path,
        '--keep-build',
        '--no-build'
      ]);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('Cannot use --keep-build together with --no-build'));
    });

    test(
        'ExitCode.usage.code (64) for conflicting -n/--build-number and --no-build',
        () {
      final res = Process.runSync('dart',
          ['bin/fvb.dart', '-p', pubspecFile.path, '-n', '42', '--no-build']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('Cannot use -n/--build-number together with --no-build'));
    });

    test('ExitCode.usage.code (64) for negative build-number (-n -1)', () {
      final res = Process.runSync(
          'dart', ['bin/fvb.dart', '-p', pubspecFile.path, '-n', '-1']);
      expect(res.exitCode, equals(ExitCode.usage.code));
      expect(res.stdout.toString(),
          contains('build-number must be a valid non-negative integer'));
    });

    test('ExitCode.config.code (78) for non-existent explicit config-path', () {
      final nonExistentConfig = path.join(tempDir.path, 'missing_config.yaml');
      final res = Process.runSync('dart', [
        'bin/fvb.dart',
        '-p',
        pubspecFile.path,
        '--config-path',
        nonExistentConfig
      ]);
      expect(res.exitCode, equals(ExitCode.config.code));
      expect(res.stdout.toString(), contains('Configuration file not found'));
    });

    test('ExitCode.config.code (78) for malformed YAML in explicit config-path',
        () {
      final malformedConfig = path.join(tempDir.path, 'malformed_config.yaml');
      File(malformedConfig).writeAsStringSync('fvb:\n  git: [unclosed list\n');
      final res = Process.runSync('dart', [
        'bin/fvb.dart',
        '-p',
        pubspecFile.path,
        '--config-path',
        malformedConfig
      ]);
      expect(res.exitCode, equals(ExitCode.config.code));
      expect(res.stdout.toString(),
          contains('Failed to parse configuration file'));
    });

    test('ExitCode.ioError.code (74) for non-existent pubspec.yaml file', () {
      final nonExistentPubspec =
          path.join(tempDir.path, 'does_not_exist', 'pubspec.yaml');
      final res =
          Process.runSync('dart', ['bin/fvb.dart', '-p', nonExistentPubspec]);
      expect(res.exitCode, equals(ExitCode.ioError.code));
      expect(res.stdout.toString(), contains('pubspec.yaml not found'));
    });

    test('ExitCode.data.code (65) for invalid version in pubspec.yaml', () {
      pubspecFile
          .writeAsStringSync('name: malformed_test\nversion: invalid-semver\n');
      final res =
          Process.runSync('dart', ['bin/fvb.dart', '-p', pubspecFile.path]);
      expect(res.exitCode, equals(ExitCode.data.code));
      expect(
          res.stdout.toString(), contains('Failed to parse current version'));
    });

    test('ExitCode.data.code (65) for invalid version in -s/--set argument',
        () {
      final res = Process.runSync('dart',
          ['bin/fvb.dart', '-p', pubspecFile.path, '-s', 'bad.version']);
      expect(res.exitCode, equals(ExitCode.data.code));
      expect(res.stdout.toString(),
          contains('Failed to parse set version string'));
    });

    test('ExitCode.success.code (0) on successful CLI bump', () {
      final res = Process.runSync(
          'dart', ['bin/fvb.dart', '-p', pubspecFile.path, '-q']);
      expect(res.exitCode, equals(ExitCode.success.code));
      expect(pubspecFile.readAsStringSync(), contains('version: 1.2.1+3'));
    });
  });

  group('Git Working Tree Dirty Safety Guard', () {
    test(
        'blocks Git operations if working directory has uncommitted files without --allow-dirty',
        () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      // Create an uncommitted file
      final dirtyFile = File(path.join(tempDir.path, 'dirty_changes.txt'));
      dirtyFile.writeAsStringSync('uncommitted work');

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(['-p', pubspecFile.path, '-g', '-d', '--json']);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      // Git commit blocked by safety guard
      expect(jsonResult['git_committed'], isFalse);
    });

    test('allows Git operations when --allow-dirty flag is provided', () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      final dirtyFile = File(path.join(tempDir.path, 'dirty_changes.txt'));
      dirtyFile.writeAsStringSync('uncommitted work');

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(
            ['-p', pubspecFile.path, '-g', '--allow-dirty', '-d', '--json']);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      // Git commit allowed
      expect(jsonResult['git_committed'], isTrue);
    });

    test('allows Git operations when allow_dirty is set in .fvb.yaml', () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      final dirtyFile = File(path.join(tempDir.path, 'dirty_changes.txt'));
      dirtyFile.writeAsStringSync('uncommitted work');

      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  git: true
  allow_dirty: true
''');

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(['-p', pubspecFile.path, '-d', '--json']);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      expect(jsonResult['git_committed'], isTrue);
    });

    test(
        'blocks Git operations if CHANGELOG.md has uncommitted changes and --changelog is not enabled',
        () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      changelogFile.writeAsStringSync('# Changelog\n\nInitial\n');
      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      // Add manual uncommitted change to CHANGELOG.md
      changelogFile.writeAsStringSync('Uncommitted changelog notes\n',
          mode: FileMode.append);

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(['-p', pubspecFile.path, '-g', '-d', '--json']);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      // Safety guard MUST catch dirty CHANGELOG.md when -c is not used
      expect(jsonResult['git_committed'], isFalse);
    });

    test(
        'allows Git operations and correctly handles custom changelog_path with -c and -g',
        () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      final docsDir = Directory(path.join(tempDir.path, 'docs'))..createSync();
      final customChangelog = File(path.join(docsDir.path, 'CHANGELOG.md'));
      customChangelog.writeAsStringSync('# Changelog\n\nInitial notes\n');

      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  changelog_path: docs/CHANGELOG.md
''');

      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(['-p', pubspecFile.path, '-c', '-g', '-d', '--json']);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      expect(jsonResult['git_committed'], isTrue);
    });

    test('dry run with tag only does not output git add', () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      Process.runSync('git', ['add', '-A'], workingDirectory: tempDir.path);
      Process.runSync('git', ['commit', '-m', 'Initial commit'],
          workingDirectory: tempDir.path);

      final prints = <String>[];
      final spec = ZoneSpecification(
          print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion(['-p', pubspecFile.path, '-t', '-d']);
      });

      expect(prints.any((p) => p.contains('Would run: git add')), isFalse);
      expect(prints.any((p) => p.contains('Would run: git tag')), isTrue);
    });
  });

  group('Pre-release Promotion / Release Flag (--release / --promote)', () {
    test(
        'promotes pre-release to stable version (1.2.0-beta.1+2 -> 1.2.0+3) with --release',
        () {
      bumpVersion(['-p', pubspecFile.path, '--release', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0+3'));
    });

    test('promotes pre-release to stable version with alias --promote', () {
      bumpVersion(['-p', pubspecFile.path, '--promote', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0+3'));
    });

    test(
        '--release with --keep-build preserves current build number (1.2.0-beta.1+2 -> 1.2.0+2)',
        () {
      bumpVersion(['-p', pubspecFile.path, '--release', '--keep-build', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0+2'));
    });

    test(
        '--release with --no-build removes build number segment (1.2.0-beta.1+2 -> 1.2.0)',
        () {
      bumpVersion(['-p', pubspecFile.path, '--release', '--no-build', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0\n'));
      expect(content, isNot(contains('+')));
    });

    test(
        '--release with explicit build number override -n (1.2.0-beta.1+2 -> 1.2.0+100)',
        () {
      bumpVersion(['-p', pubspecFile.path, '--release', '-n', '100', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0+100'));
    });

    test(
        '--release on already stable version keeps version intact and increments build',
        () {
      pubspecFile.writeAsStringSync('name: stable_test\nversion: 2.5.0+10\n');
      bumpVersion(['-p', pubspecFile.path, '--release', '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 2.5.0+11'));
    });

    test('release: true configured in .fvb.yaml promotes pre-release', () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  release: true
''');

      bumpVersion(['-p', pubspecFile.path, '-q']);
      final content = pubspecFile.readAsStringSync();
      expect(content, contains('version: 1.2.0+3'));
    });

    test(
        'CLI bump flag overrides release: true in .fvb.yaml without conflict error',
        () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  release: true
''');

      bumpVersion(['-p', pubspecFile.path, '-b', 'minor', '-q']);
      final content = pubspecFile.readAsStringSync();
      // Increments minor to 1.3.0+3 instead of promoting to 1.2.0+3
      expect(content, contains('version: 1.3.0+3'));
    });

    test('PubspecVersion.promote unit tests', () {
      final v1 = PubspecVersion.parse('1.0.0-rc.1+5');
      final p1 = v1.promote(incrementBuild: true, removeBuild: false);
      expect(p1.toString(), equals('1.0.0+6'));

      final p2 = v1.promote(incrementBuild: false, removeBuild: false);
      expect(p2.toString(), equals('1.0.0+5'));

      final p3 = v1.promote(incrementBuild: false, removeBuild: true);
      expect(p3.toString(), equals('1.0.0'));

      final p4 = v1.promote(
          incrementBuild: false, explicitBuild: 99, removeBuild: false);
      expect(p4.toString(), equals('1.0.0+99'));
    });
  });

  group('FvbConfig & Interactive Runner Enhancements', () {
    test('FvbConfig parses kebab-case configuration keys correctly', () {
      final dotFvb = File(path.join(tempDir.path, '.fvb.yaml'));
      dotFvb.writeAsStringSync('''
fvb:
  allow-dirty: true
  git-tag: true
  git-push: true
  keep-build: true
  no-build: false
  commit-msg: "release: {version}"
  tag-prefix: "release-"
  changelog-path: "docs/CHANGELOG.md"
  changelog-msg: "Updated notes"
''');

      final config = FvbConfig.load(targetPubspecPath: pubspecFile.path);
      expect(config.allowDirty, isTrue);
      expect(config.gitTag, isTrue);
      expect(config.gitPush, isTrue);
      expect(config.keepBuild, isTrue);
      expect(config.noBuild, isFalse);
      expect(config.commitMsg, equals('release: {version}'));
      expect(config.tagPrefix, equals('release-'));
      expect(config.changelogPath, equals('docs/CHANGELOG.md'));
      expect(config.changelogMsg, equals('Updated notes'));
    });
  });
}
