import 'dart:io';
import 'package:flutter_version_bumper/flutter_version_bumper.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('fvb_skill_manager_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('SkillManager Tests', () {
    test('installs SKILL.md into local .agents/skills and .skills directories', () {
      final success = SkillManager.installSkill(
        targetDir: tempDir.path,
        global: false,
        quiet: true,
      );

      expect(success, isTrue);

      final agentsSkillFile = File(path.join(tempDir.path, '.agents', 'skills', 'flutter-version-bumper', 'SKILL.md'));
      final skillsSkillFile = File(path.join(tempDir.path, '.skills', 'flutter-version-bumper', 'SKILL.md'));

      expect(agentsSkillFile.existsSync(), isTrue);
      expect(skillsSkillFile.existsSync(), isTrue);

      final content = agentsSkillFile.readAsStringSync();
      expect(content, contains('name: flutter-version-bumper'));
      expect(content, contains('# Flutter Version Bumper (FVB) Agent Skill'));
    });

    test('removes SKILL.md from local directories', () {
      SkillManager.installSkill(
        targetDir: tempDir.path,
        global: false,
        quiet: true,
      );

      final agentsSkillFile = File(path.join(tempDir.path, '.agents', 'skills', 'flutter-version-bumper', 'SKILL.md'));
      final skillsSkillFile = File(path.join(tempDir.path, '.skills', 'flutter-version-bumper', 'SKILL.md'));

      expect(agentsSkillFile.existsSync(), isTrue);

      final success = SkillManager.removeSkill(
        targetDir: tempDir.path,
        global: false,
        quiet: true,
      );

      expect(success, isTrue);
      expect(agentsSkillFile.existsSync(), isFalse);
      expect(skillsSkillFile.existsSync(), isFalse);
    });

    test('executes CLI bumpVersion with --install-skill flag', () {
      final pubspecFile = File(path.join(tempDir.path, 'pubspec.yaml'));
      pubspecFile.writeAsStringSync('name: test_app\nversion: 1.0.0+1\n');

      bumpVersion(['-p', pubspecFile.path, '--install-skill', '--quiet']);

      final agentsSkillFile = File(path.join(tempDir.path, '.agents', 'skills', 'flutter-version-bumper', 'SKILL.md'));
      expect(agentsSkillFile.existsSync(), isTrue);
    });
  });
}
