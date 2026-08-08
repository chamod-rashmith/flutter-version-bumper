# Flutter Version Bumper Examples

`flutter_version_bumper` (FVB) can be used both as a Command-Line Tool (CLI) and as a Dart package in your automation scripts.

---

## 1. CLI Usage Examples

Run these commands in your Flutter/Dart project directory:

```bash
# Default patch bump (e.g., 1.0.0+1 -> 1.0.1+2)
fvb

# Bump minor version (e.g., 1.0.1+2 -> 1.1.0+3)
fvb -b minor

# Bump major version (e.g., 1.1.0+3 -> 2.0.0+4)
fvb -b major

# Explicitly set version string
fvb -s 2.0.0-beta.1+42

# Bump patch and start beta prerelease (e.g., 1.0.0+1 -> 1.0.1-beta.1+2)
fvb --pre beta

# Keep current build number without incrementing
fvb -k

# Bump patch, update CHANGELOG.md, commit, tag, and push to Git remote
fvb -c -g -t --git-push

# Dry run simulation (no files modified)
fvb -d

# Interactive CLI selection menu
fvb -i
```

---

## 2. Programmatic Usage in Dart

You can also call FVB programmatically in custom build scripts:

```dart
import 'package:flutter_version_bumper/flutter_version_bumper.dart';

void main() {
  // 1. Run FVB CLI command logic programmatically
  bumpVersion(['--bump', 'patch', '--dry-run']);

  // 2. Parse SemVer strings
  final version = PubspecVersion.parse('1.2.3-beta.1+42');
  print('Parsed version: $version');

  // 3. Bump version segments
  final nextMinor = version.bump('minor', incrementBuild: true, removeBuild: false);
  print('Next Minor: $nextMinor'); // 1.3.0+43
}
```
