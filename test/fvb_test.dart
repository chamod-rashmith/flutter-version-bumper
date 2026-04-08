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
}
