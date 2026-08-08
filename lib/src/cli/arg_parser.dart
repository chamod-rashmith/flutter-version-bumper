import 'package:args/args.dart';

/// Configures and returns the standard CLI argument parser for FVB.
ArgParser buildArgParser() {
  return ArgParser()
    ..addOption('bump',
        abbr: 'b',
        allowed: ['major', 'minor', 'patch', 'build'],
        defaultsTo: 'patch',
        help: 'Which SemVer part to bump (major, minor, patch, build)')
    ..addOption('set',
        abbr: 's',
        help: 'Explicitly set a full version string (e.g., 2.0.0, 2.0.0-beta.1+3)')
    ..addOption('build-number',
        abbr: 'n',
        help: 'Explicitly override the build number segment')
    ..addFlag('keep-build',
        abbr: 'k',
        negatable: false,
        help: 'Keep the current build number instead of incrementing')
    ..addFlag('no-build',
        negatable: false,
        help: 'Completely remove the build number segment')
    ..addFlag('git',
        abbr: 'g',
        negatable: false,
        help: 'Automatically commit the pubspec.yaml version changes')
    ..addFlag('git-tag',
        abbr: 't',
        negatable: false,
        help: 'Automatically create a git tag for the new version')
    ..addFlag('git-push',
        negatable: false,
        help: 'Automatically push committed changes and tags to git remote origin')
    ..addOption('commit-msg',
        abbr: 'm',
        defaultsTo: 'chore: bump version to {version}',
        help: 'Commit message template (use {version} as placeholder)')
    ..addOption('tag-prefix',
        defaultsTo: 'v',
        help: 'Git tag prefix')
    ..addOption('pre',
        help: 'Specify pre-release label and transition to/increment prerelease (e.g. beta, rc)')
    ..addFlag('dry-run',
        abbr: 'd',
        negatable: false,
        help: 'Simulate changes without modifying files or git status')
    ..addOption('path',
        abbr: 'p',
        help: 'Custom path to pubspec.yaml or its parent directory')
    ..addFlag('interactive',
        abbr: 'i',
        negatable: false,
        help: 'Launch a step-by-step interactive bumping workflow')
    ..addFlag('quiet',
        abbr: 'q',
        negatable: false,
        help: 'Mute all console outputs (errors will still print)')
    ..addFlag('json',
        negatable: false,
        help: 'Format output as a structured JSON string')
    ..addFlag('help',
        abbr: 'h',
        negatable: false,
        help: 'Show FVB command line usage instructions');
}
