import 'dart:io';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

/// The regex pattern used to find the version line in pubspec.yaml.
/// Matches "version: X.Y.Z+W"
const String versionRegex = r'^version:\s*(\d+)\.(\d+)\.(\d+)(?:\+(\d+))?';

/// Processes the command-line arguments and performs the version bump.
/// 
/// This is the main entry point for the logic, allowing it to be called from
/// both the binary and potentially other Dart libraries.
void bumpVersion(List<String> arguments) {
  final parser = ArgParser()
    ..addOption('bump',
        abbr: 'b',
        allowed: ['major', 'minor', 'patch', 'build'],
        defaultsTo: 'patch',
        help: 'Which semver part to bump')
    ..addOption('set', abbr: 's', help: 'Explicitly set a version string (e.g. 2.0.0)')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this information');

  final argResults = parser.parse(arguments);

  if (argResults['help'] as bool) {
    _printHelp(parser);
    return;
  }

  final pubspecFile = File(path.join(Directory.current.path, 'pubspec.yaml'));

  if (!pubspecFile.existsSync()) {
    _printError('pubspec.yaml not found in the current directory. Make sure you are in a Flutter project root.');
    exit(1);
  }

  String content = pubspecFile.readAsStringSync();
  final match = RegExp(versionRegex, multiLine: true).firstMatch(content);

  if (match == null) {
    _printError('Could not parse version line in pubspec.yaml.\nExpected format: version: X.Y.Z or version: X.Y.Z+W');
    exit(1);
  }

  int curMajor = int.parse(match.group(1)!);
  int curMinor = int.parse(match.group(2)!);
  int curPatch = int.parse(match.group(3)!);
  int curBuild = match.group(4) != null ? int.parse(match.group(4)!) : 0;

  final String oldVersion = '$curMajor.$curMinor.$curPatch+$curBuild';
  print('\x1B[36mCurrent version: $oldVersion\x1B[0m');

  int newMajor = curMajor;
  int newMinor = curMinor;
  int newPatch = curPatch;
  int newBuild = curBuild + 1;

  final setVer = argResults['set'] as String?;
  if (setVer != null) {
    if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(setVer)) {
      _printError('SetVersion must be in format X.Y.Z (e.g. 2.1.0)');
      exit(1);
    }
    final parts = setVer.split('.').map(int.parse).toList();
    newMajor = parts[0];
    newMinor = parts[1];
    newPatch = parts[2];
  } else {
    final bumpType = argResults['bump'] as String;
    switch (bumpType) {
      case 'major':
        newMajor++;
        newMinor = 0;
        newPatch = 0;
        break;
      case 'minor':
        newMinor++;
        newPatch = 0;
        break;
      case 'patch':
        newPatch++;
        break;
      case 'build':
        // Only increment build (already done)
        break;
    }
  }

  final String newFull = '$newMajor.$newMinor.$newPatch+$newBuild';
  print('\x1B[32mNew version:     $newFull\x1B[0m');

  content = content.replaceFirst(RegExp(versionRegex, multiLine: true), 'version: $newFull');
  pubspecFile.writeAsStringSync(content);

  print('\x1B[33m\n[OK] pubspec.yaml updated: $oldVersion -> $newFull\x1B[0m');
}

void _printHelp(ArgParser parser) {
  print('🚀 Flutter Version Bumper (FVB)');
  print('A lightning-fast tool to automate versioning in Flutter projects.');
  print('\nUsage: fvb [options]');
  print(parser.usage);
  print('\nExamples:');
  print('  fvb                # Bumps patch (1.0.0+1 -> 1.0.1+2)');
  print('  fvb -b minor       # Bumps minor (1.0.1+2 -> 1.1.0+3)');
  print('  fvb -s 2.0.0       # Sets version to 2.0.0+build');
}

void _printError(String msg) {
  print('\x1B[31mERROR: $msg\x1B[0m');
}
