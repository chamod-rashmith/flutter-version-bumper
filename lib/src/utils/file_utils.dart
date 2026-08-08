import 'dart:io';
import 'package:path/path.dart' as path;

/// The regex pattern used to locate the version line in pubspec.yaml.
/// It matches 'version:' at the start of a line, followed by optional spaces,
/// and captures the version string up to the first space or comment character.
final RegExp versionRegex = RegExp(r'^version:\s*([^\s#]+)', multiLine: true);

/// Resolves standard or custom path to pubspec.yaml.
File resolvePubspecFile(String? customPath) {
  if (customPath == null) {
    return File(path.join(Directory.current.path, 'pubspec.yaml'));
  }

  if (FileSystemEntity.isDirectorySync(customPath)) {
    return File(path.join(customPath, 'pubspec.yaml'));
  }
  return File(customPath);
}
