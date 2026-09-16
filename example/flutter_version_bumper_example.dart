import 'package:flutter_version_bumper/flutter_version_bumper.dart';

void main() {
  print('--- 1. Programmatic CLI Command Execution ---');
  // You can execute FVB CLI commands directly from Dart code:
  bumpVersion(['--dry-run', '--bump', 'patch']);

  print('\n--- 2. Direct Version Parsing & Bumping ---');
  // Parse a Semantic Version string
  final version = PubspecVersion.parse('1.2.3-beta.1+42');
  print('Current parsed version: $version');
  print(
      'Major: ${version.major}, Minor: ${version.minor}, Patch: ${version.patch}');
  print('Pre-release: ${version.preRelease}, Build: ${version.build}');

  // Bump version segments programmatically
  final nextMinor =
      version.bump('minor', incrementBuild: true, removeBuild: false);
  print('Next minor version: $nextMinor'); // 1.3.0+43

  final nextBeta = version.bump('patch',
      incrementBuild: true, removeBuild: false, preReleaseLabel: 'beta');
  print('Next beta prerelease: $nextBeta'); // 1.2.3-beta.2+43

  // Promote pre-release to stable release
  final nextStable = version.promote(incrementBuild: true, removeBuild: false);
  print('Promoted stable release: $nextStable'); // 1.2.3+43

  print('\n--- 3. Configuration Model ---');
  // Load or construct FVB configuration
  final config = FvbConfig(
    bump: 'patch',
    git: true,
    gitTag: true,
    tagPrefix: 'v',
  );
  print('Configured bump type: ${config.bump}');
  print('Git automation enabled: ${config.git}');
}
