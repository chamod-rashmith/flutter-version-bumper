import 'dart:io';
import 'package:args/args.dart';

/// Whether the standard output stream supports ANSI escape color codes.
bool get useAnsi =>
    stdout.hasTerminal &&
    stdout.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');

/// Whether the standard error stream supports ANSI escape color codes.
bool get useAnsiErr =>
    stderr.hasTerminal &&
    stderr.supportsAnsiEscapes &&
    !Platform.environment.containsKey('NO_COLOR');

/// Prints formatted CLI usage instructions and command recipes.
///
/// Writes available flags, option descriptions, and examples configured
/// in [parser] to [stdout].
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

/// Outputs an informational message to the console.
///
/// If [jsonMode] is `true`, writes [msg] to [stderr] to avoid contaminating
/// the machine-readable [stdout] JSON stream.
///
/// If [quiet] is `true`, the message is suppressed. If [colorCode] is specified
/// and [useAnsi] is `true`, colorizes the message before outputting.
void logInfo(String msg, bool quiet, bool jsonMode, {String? colorCode}) {
  if (jsonMode) {
    stderr.writeln(msg);
  } else if (!quiet) {
    if (colorCode != null && useAnsi) {
      print('$colorCode$msg\x1B[0m');
    } else {
      print(msg);
    }
  }
}

/// Outputs a warning message to standard error.
///
/// If [quiet] is `true` and [jsonMode] is `false`, the warning is suppressed.
/// If [useAnsiErr] is `true`, colorizes the warning with yellow ANSI escape codes.
void logWarning(String msg, bool quiet, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[33m[Warning] $msg\x1B[0m');
  } else if (!quiet) {
    if (useAnsiErr) {
      stderr.writeln('\x1B[33m[Warning] $msg\x1B[0m');
    } else {
      stderr.writeln('[Warning] $msg');
    }
  }
}

/// Outputs an error message to standard error.
///
/// Always writes to [stderr]. If [useAnsiErr] is `true` and [jsonMode] is `false`,
/// colorizes the error with red ANSI escape codes.
void logError(String msg, bool jsonMode) {
  if (jsonMode) {
    stderr.writeln('\x1B[31mERROR: $msg\x1B[0m');
  } else {
    if (useAnsiErr) {
      stderr.writeln('\x1B[31mERROR: $msg\x1B[0m');
    } else {
      stderr.writeln('ERROR: $msg');
    }
  }
}

/// Prints an error message directly to standard error.
///
/// Always formats the output prefixed with `ERROR:` and writes to [stderr].
void printError(String msg) {
  if (useAnsiErr) {
    stderr.writeln('\x1B[31mERROR: $msg\x1B[0m');
  } else {
    stderr.writeln('ERROR: $msg');
  }
}
