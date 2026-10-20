import 'dart:io';
import 'package:path/path.dart' as path;

/// The regular expression pattern used to locate the version line in `pubspec.yaml`.
///
/// Matches `'version:'` at the start of a line, captures the version string up
/// to the first whitespace or comment character (`#`).
final RegExp versionRegex = RegExp(r'^version:\s*([^\s#]+)', multiLine: true);

/// Resolves the file reference to `pubspec.yaml`.
///
/// If [customPath] is `null`, returns `pubspec.yaml` in the current working directory.
/// If [customPath] points to a directory, returns the `pubspec.yaml` inside that directory.
/// Otherwise, returns a [File] pointing to the canonicalized [customPath].
File resolvePubspecFile(String? customPath) {
  if (customPath == null) {
    return File(
        path.canonicalize(path.join(Directory.current.path, 'pubspec.yaml')));
  }

  final absPath = path.canonicalize(path.absolute(customPath));
  if (FileSystemEntity.isDirectorySync(absPath)) {
    return File(path.canonicalize(path.join(absPath, 'pubspec.yaml')));
  }
  return File(absPath);
}
