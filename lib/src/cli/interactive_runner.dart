import 'dart:io';
import '../models/pubspec_version.dart';

/// Provides a standard terminal-based selection flow.
PubspecVersion runInteractive(PubspecVersion current, bool keepBuild, int? explicitBuild, bool removeBuild) {
  print('🚀 \x1B[36mFlutter Version Bumper - Interactive Mode\x1B[0m');
  print('Current Version: \x1B[33m$current\x1B[0m\n');
  print('Select the part to bump:');

  final patchPreview = current.bump('patch', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final minorPreview = current.bump('minor', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final majorPreview = current.bump('major', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);
  final buildPreview = current.bump('build', incrementBuild: !keepBuild, explicitBuild: explicitBuild, removeBuild: removeBuild);

  print('  1. Patch  (-> \x1B[32m$patchPreview\x1B[0m)');
  print('  2. Minor  (-> \x1B[32m$minorPreview\x1B[0m)');
  print('  3. Major  (-> \x1B[32m$majorPreview\x1B[0m)');
  print('  4. Build  (-> \x1B[32m$buildPreview\x1B[0m)');
  print('  5. Custom Version String');

  int nullAttempts = 0;
  while (true) {
    stdout.write('\nEnter choice (1-5): ');
    final choice = stdin.readLineSync()?.trim();
    if (choice == null) {
      nullAttempts++;
      if (nullAttempts > 3) {
        throw StateError('No standard input stream. Cannot run in interactive mode.');
      }
      continue;
    }
    nullAttempts = 0;

    if (choice == '1') return patchPreview;
    if (choice == '2') return minorPreview;
    if (choice == '3') return majorPreview;
    if (choice == '4') return buildPreview;
    if (choice == '5') {
      while (true) {
        stdout.write('Enter custom version (e.g., 2.0.0-beta.1+3): ');
        final customStr = stdin.readLineSync()?.trim();
        if (customStr == null) {
          throw StateError('No standard input stream. Cannot run in interactive mode.');
        }
        if (customStr.isEmpty) {
          print('\x1B[31mVersion cannot be empty.\x1B[0m');
          continue;
        }
        try {
          return PubspecVersion.parse(customStr);
        } catch (e) {
          print('\x1B[31mError: ${e.toString()}\x1B[0m');
        }
      }
    }
    print('\x1B[31mInvalid choice. Please select 1, 2, 3, 4, or 5.\x1B[0m');
  }
}
