import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;
import 'package:flutter_version_bumper/flutter_version_bumper.dart';

void main() {
  late Directory tempDir;
  late File pubspecFile;
  late String originalDir;

  setUp(() {
    originalDir = Directory.current.path;
    tempDir = Directory.systemTemp.createTempSync('fvb_test_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    Directory.current = tempDir.path;
  });

  tearDown(() {
    Directory.current = originalDir;
    tempDir.deleteSync(recursive: true);
  });

  test('default bump (patch)', () {
    bumpVersion([]);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1+2'));
  });

  test('minor bump', () {
    bumpVersion(['-b', 'minor']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.1.0+2'));
  });

  test('major bump', () {
    bumpVersion(['-b', 'major']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 2.0.0+2'));
  });

  test('build only bump', () {
    bumpVersion(['-b', 'build']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.0+2'));
  });

  test('explicit set version', () {
    bumpVersion(['-s', '3.5.2']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 3.5.2+2'));
  });

  test('version without build number', () {
    pubspecFile.writeAsStringSync('name: no_build_test\nversion: 1.2.3\n');
    bumpVersion([]);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.2.4+1'));
  });

  test('version with extra spacing', () {
    pubspecFile.writeAsStringSync('name: spacing_test\nversion:   2.3.4+5 \n');
    bumpVersion([]);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 2.3.5+6'));
  });

  test('version in middle of pubspec', () {
    pubspecFile.writeAsStringSync(
        'name: middle_test\ndescription: "A test project"\nversion: 1.0.0+1\ndependencies:\n  flutter: sdk: flutter\n');
    bumpVersion(['-b', 'minor']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('name: middle_test'));
    expect(content, contains('version: 1.1.0+2'));
    expect(content, contains('dependencies:'));
  });

  test('multiple bumps', () {
    bumpVersion([]); // 1.0.0+1 -> 1.0.1+2
    bumpVersion(['-b', 'minor']); // 1.0.1+2 -> 1.1.0+3
    bumpVersion(['-b', 'major']); // 1.1.0+3 -> 2.0.0+4
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 2.0.0+4'));
  });

  test('help flag', () {
    // Should return without exiting or crashing
    expect(() => bumpVersion(['--help']), returnsNormally);
  });

  test('pre-release and metadata version parsing', () {
    pubspecFile
        .writeAsStringSync('name: test_project\nversion: 1.0.0-beta.1+12\n');
    bumpVersion(
        []); // should increment patch, clearing pre-release, incrementing build
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1+13'));
  });

  test('keep build number', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    bumpVersion(['--keep-build']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1+1'));
  });

  test('explicit build number', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    bumpVersion(['-n', '42']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1+42'));
  });

  test('no build number', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    bumpVersion(['--no-build']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1'));
    expect(content, isNot(contains('+')));
  });

  test('dry-run mode', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    bumpVersion(['--dry-run']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.0+1')); // Should not change on disk
  });

  test('custom path support (directory)', () {
    final subDir = Directory(path.join(tempDir.path, 'my_package'));
    subDir.createSync();
    final subPubspec = File(path.join(subDir.path, 'pubspec.yaml'));
    subPubspec.writeAsStringSync('name: sub_package\nversion: 2.0.0+1\n');

    bumpVersion(['--path', subDir.path]);
    final content = subPubspec.readAsStringSync();
    expect(content, contains('version: 2.0.1+2'));
  });

  test('custom path support (direct file)', () {
    final otherFile = File(path.join(tempDir.path, 'other_pubspec.yaml'));
    otherFile.writeAsStringSync('name: other_package\nversion: 3.0.0+1\n');

    bumpVersion(['--path', otherFile.path]);
    final content = otherFile.readAsStringSync();
    expect(content, contains('version: 3.0.1+2'));
  });

  test('json output format', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    final prints = <String>[];
    final spec = ZoneSpecification(print: (self, parent, zone, line) {
      prints.add(line);
    });

    Zone.current.fork(specification: spec).run(() {
      bumpVersion(['--json']);
    });

    expect(prints.length, equals(1));
    final decoded = jsonDecode(prints.first);
    expect(decoded['success'], isTrue);
    expect(decoded['previous_version'], equals('1.0.0+1'));
    expect(decoded['new_version'], equals('1.0.1+2'));
    expect(decoded['dry_run'], isFalse);
  });

  test('transition to new pre-release beta', () {
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    bumpVersion(['--pre', 'beta']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1-beta.1+2'));
  });

  test('increment existing pre-release beta', () {
    pubspecFile
        .writeAsStringSync('name: test_project\nversion: 1.0.1-beta.1+2\n');
    bumpVersion(['--pre', 'beta']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1-beta.2+3'));
  });

  test('change pre-release label from beta to rc', () {
    pubspecFile
        .writeAsStringSync('name: test_project\nversion: 1.0.1-beta.2+3\n');
    bumpVersion(['--pre', 'rc']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1-rc.1+4'));
  });

  test('stable release promotion (removing pre-release label)', () {
    pubspecFile
        .writeAsStringSync('name: test_project\nversion: 1.0.1-beta.2+3\n');
    bumpVersion([]);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.2+4'));
  });

  test('non-numeric pre-release segment fallback', () {
    pubspecFile
        .writeAsStringSync('name: test_project\nversion: 1.0.1-beta+2\n');
    bumpVersion(['--pre', 'beta']);
    final content = pubspecFile.readAsStringSync();
    expect(content, contains('version: 1.0.1-beta.1+3'));
  });

  test('git push option parsing & dry-run simulation output', () {
    Process.runSync('git', ['init'], workingDirectory: tempDir.path);
    pubspecFile.writeAsStringSync('name: test_project\nversion: 1.0.0+1\n');
    final prints = <String>[];
    final spec = ZoneSpecification(print: (self, parent, zone, line) {
      prints.add(line);
    });

    Zone.current.fork(specification: spec).run(() {
      bumpVersion(['--dry-run', '--git-push', '--json']);
    });

    expect(prints.length, equals(1));
    final decoded = jsonDecode(prints.first);
    expect(decoded['success'], isTrue);
    expect(decoded['git_pushed'], isTrue);
    expect(decoded['dry_run'], isTrue);
  });
}
