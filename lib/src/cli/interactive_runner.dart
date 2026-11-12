import 'dart:io';
import '../models/pubspec_version.dart';
import '../utils/logger.dart';

/// Runs a terminal-based interactive selection prompt for version bumping.
///
/// Prompts the user with previews for patch, minor, major, build, and promotion
/// increments based on [current].
///
/// The [keepBuild], [explicitBuild], and [removeBuild] flags dictate how the
/// build number segment is handled across the choices.
///
/// Throws a [StateError] if the standard input stream is unavailable or closed.
PubspecVersion runInteractive(PubspecVersion current, bool keepBuild,
    int? explicitBuild, bool removeBuild) {
  String cyan(String text) => useAnsi ? '\x1B[36m$text\x1B[0m' : text;
  String yellow(String text) => useAnsi ? '\x1B[33m$text\x1B[0m' : text;
  String green(String text) => useAnsi ? '\x1B[32m$text\x1B[0m' : text;
  String red(String text) => useAnsiErr ? '\x1B[31m$text\x1B[0m' : text;

  print('🚀 ${cyan("Flutter Version Bumper - Interactive Mode")}');
  print('Current Version: ${yellow(current.toString())}\n');
  print('Select the part to bump:');

  final patchPreview = current.bump('patch',
      incrementBuild: !keepBuild,
      explicitBuild: explicitBuild,
      removeBuild: removeBuild);
  final minorPreview = current.bump('minor',
      incrementBuild: !keepBuild,
      explicitBuild: explicitBuild,
      removeBuild: removeBuild);
  final majorPreview = current.bump('major',
      incrementBuild: !keepBuild,
      explicitBuild: explicitBuild,
      removeBuild: removeBuild);
  final buildPreview = current.bump('build',
      incrementBuild: !keepBuild,
      explicitBuild: explicitBuild,
      removeBuild: removeBuild);

  final releasePreview = current.preRelease != null
      ? current.promote(
          incrementBuild: !keepBuild,
          explicitBuild: explicitBuild,
          removeBuild: removeBuild)
      : null;

  if (releasePreview != null) {
    print(
        '  0. Promote to Stable Release (-> ${green(releasePreview.toString())})');
  }
  print('  1. Patch  (-> ${green(patchPreview.toString())})');
  print('  2. Minor  (-> ${green(minorPreview.toString())})');
  print('  3. Major  (-> ${green(majorPreview.toString())})');
  print('  4. Build  (-> ${green(buildPreview.toString())})');
  print('  5. Custom Version String');

  int nullAttempts = 0;
  while (true) {
    final prompt = releasePreview != null
        ? '\nEnter choice (0-5): '
        : '\nEnter choice (1-5): ';
    stdout.write(prompt);
    final choice = stdin.readLineSync()?.trim();
    if (choice == null) {
      nullAttempts++;
      if (nullAttempts > 3) {
        throw StateError(
            'No standard input stream. Cannot run in interactive mode.');
      }
      continue;
    }
    nullAttempts = 0;

    if (choice == '0' && releasePreview != null) return releasePreview;
    if (choice == '1') return patchPreview;
    if (choice == '2') return minorPreview;
    if (choice == '3') return majorPreview;
    if (choice == '4') return buildPreview;
    if (choice == '5') {
      while (true) {
        stdout.write('Enter custom version (e.g., 2.0.0-beta.1+3): ');
        final customStr = stdin.readLineSync()?.trim();
        if (customStr == null) {
          throw StateError(
              'No standard input stream. Cannot run in interactive mode.');
        }
        if (customStr.isEmpty) {
          stderr.writeln(red('Version cannot be empty.'));
          continue;
        }
        try {
          final parsed = PubspecVersion.parse(customStr);
          String? finalBuild;
          if (removeBuild) {
            finalBuild = null;
          } else if (explicitBuild != null) {
            finalBuild = explicitBuild.toString();
          } else if (parsed.build != null) {
            finalBuild = parsed.build;
          } else if (keepBuild) {
            finalBuild = current.build;
          } else {
            final int currentBuildInt =
                current.build != null ? (int.tryParse(current.build!) ?? 0) : 0;
            finalBuild = (currentBuildInt + 1).toString();
          }
          return PubspecVersion(
            major: parsed.major,
            minor: parsed.minor,
            patch: parsed.patch,
            preRelease: parsed.preRelease,
            build: finalBuild,
          );
        } catch (e) {
          stderr.writeln(red('Error: ${e.toString()}'));
        }
      }
    }
    stderr.writeln(red(
        'Invalid choice. Please select ${releasePreview != null ? "0, " : ""}1, 2, 3, 4, or 5.'));
  }
}
