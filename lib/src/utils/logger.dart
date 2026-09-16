import 'dart:io';
import 'package:args/args.dart';

/// Print formatted CLI usage instructions.
void printHelp(ArgParser parser) {
  print('🚀 Flutter Version Bumper (FVB)');
  print('A lightning-fast tool to automate versioning in Flutter projects.');
  print('\nUsage: fvb [options]');
  print(parser.usage);
  print('\nExamples:');
  print('  fvb                        # Bumps patch (1.0.0+1 -> 1.0.1+2)');
  print('  fvb -b minor               # Bumps minor (1.0.1+2 -> 1.1.0+3)');
  print('  fvb -s 2.0.0-beta.1        # Sets version to 2.0.0-beta.1+build');
  print(
      '  fvb --keep-build           # Bumps patch but keeps same build number');
  print(
      '  fvb --pre beta             # Bumps to next beta prerelease (e.g. 1.0.1-beta.1)');
  print(
      '  fvb --release              # Promotes pre-release to stable release (1.0.1-beta.1+2 -> 1.0.1+3)');
  print(
      '  fvb -g -t --git-push       # Commits, tags and pushes to Git remote origin');
  print(
      '  fvb -g --allow-dirty       # Commits version even with dirty Git working tree');
  print('  fvb -i                     # Runs interactive selection CLI menu');
}

/// Output informative messages.
void logInfo(String msg, bool quiet, bool jsonMode, {String? colorCode}) {
  if (jsonMode) {
    stderr.writeln(msg);
  } else if (!quiet) {
    if (colorCode != null) {
      print('$colorCode$msg\x1B[0m');
    } else {
      print(msg);
    }
  }
}

/// Output warning logs.
void logWarning(String msg, bool quiet, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[33m[Warning] $msg\x1B[0m');
  } else if (!quiet) {
    print('\x1B[33m[Warning] $msg\x1B[0m');
  }
}

/// Output error messages.
void logError(String msg, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[31mERROR: $msg\x1B[0m');
  } else {
    print('\x1B[31mERROR: $msg\x1B[0m');
  }
}

/// Standard print error function.
void printError(String msg) {
  print('\x1B[31mERROR: $msg\x1B[0m');
}
