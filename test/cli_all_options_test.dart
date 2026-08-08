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
    tempDir = Directory.systemTemp.createTempSync('fvb_cli_all_options_test_');
    pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
    pubspecFile.writeAsStringSync('name: test_cli_all_options\nversion: 1.0.0+1\n');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('CLI All Options Verification Tests (fvb -h)', () {
    test('--install-hook without value defaults to pre-commit', () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'));
      gitHooksDir.createSync(recursive: true);

      bumpVersion(['-p', pubspecFile.path, '--install-hook', '-q']);

      final defaultHookFile = File(path.join(gitHooksDir.path, 'pre-commit'));
      expect(defaultHookFile.existsSync(), isTrue);
      expect(defaultHookFile.readAsStringSync(), contains('FVB Git Hook'));
    });

    test('--install-hook pre-push installs pre-push hook', () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'));
      gitHooksDir.createSync(recursive: true);

      bumpVersion(['-p', pubspecFile.path, '--install-hook', 'pre-push', '-q']);

      final prePushHookFile = File(path.join(gitHooksDir.path, 'pre-push'));
      expect(prePushHookFile.existsSync(), isTrue);
    });

    test('--remove-hook without value removes default pre-commit hook', () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'));
      gitHooksDir.createSync(recursive: true);
      final hookFile = File(path.join(gitHooksDir.path, 'pre-commit'));
      hookFile.writeAsStringSync('script');

      bumpVersion(['-p', pubspecFile.path, '--remove-hook', '-q']);

      expect(hookFile.existsSync(), isFalse);
    });

    test('--remove-hook pre-push removes pre-push hook', () {
      final gitHooksDir = Directory(path.join(tempDir.path, '.git', 'hooks'));
      gitHooksDir.createSync(recursive: true);
      final prePushFile = File(path.join(gitHooksDir.path, 'pre-push'));
      prePushFile.writeAsStringSync('script');

      bumpVersion(['-p', pubspecFile.path, '--remove-hook', 'pre-push', '-q']);

      expect(prePushFile.existsSync(), isFalse);
    });

    test('git flags: -g, -t, --git-push, -m, --tag-prefix in dry-run json mode', () {
      Process.runSync('git', ['init'], workingDirectory: tempDir.path);
      final prints = <String>[];
      final spec = ZoneSpecification(print: (self, parent, zone, line) {
        prints.add(line);
      });

      Zone.current.fork(specification: spec).run(() {
        bumpVersion([
          '-p', pubspecFile.path,
          '-g',
          '-t',
          '--git-push',
          '-m', 'release: v{version}',
          '--tag-prefix', 'v',
          '-d',
          '--json'
        ]);
      });

      expect(prints.length, equals(1));
      final jsonResult = jsonDecode(prints.first);
      expect(jsonResult['success'], isTrue);
      expect(jsonResult['git_committed'], isTrue);
      expect(jsonResult['git_tagged'], isTrue);
      expect(jsonResult['git_pushed'], isTrue);
      expect(jsonResult['dry_run'], isTrue);
    });

    test('changelog options: -c, --changelog-msg', () {
      bumpVersion([
        '-p', pubspecFile.path,
        '-c',
        '--changelog-msg', 'Added new authentication module',
        '-q'
      ]);

      final changelogFile = File(path.join(tempDir.path, 'CHANGELOG.md'));
      expect(changelogFile.existsSync(), isTrue);
      final content = changelogFile.readAsStringSync();
      expect(content, contains('## [1.0.1+2]'));
      expect(content, contains('- Added new authentication module'));
    });

    test('bump options: -b major/minor/patch/build', () {
      bumpVersion(['-p', pubspecFile.path, '-b', 'major', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 2.0.0+2'));

      bumpVersion(['-p', pubspecFile.path, '-b', 'minor', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 2.1.0+3'));

      bumpVersion(['-p', pubspecFile.path, '-b', 'patch', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 2.1.1+4'));

      bumpVersion(['-p', pubspecFile.path, '-b', 'build', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 2.1.1+5'));
    });

    test('build number overrides: -n, -k, --no-build', () {
      bumpVersion(['-p', pubspecFile.path, '-n', '999', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.1+999'));

      bumpVersion(['-p', pubspecFile.path, '-k', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.2+999'));

      bumpVersion(['-p', pubspecFile.path, '--no-build', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.3\n'));
    });

    test('pre-release option: --pre', () {
      bumpVersion(['-p', pubspecFile.path, '--pre', 'rc', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 1.0.1-rc.1+2'));
    });

    test('set option: -s', () {
      bumpVersion(['-p', pubspecFile.path, '-s', '5.0.0', '-q']);
      expect(pubspecFile.readAsStringSync(), contains('version: 5.0.0+2'));
    });
  });
}
