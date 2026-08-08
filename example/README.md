# Flutter Version Bumper Example

This example demonstrates how to use the `flutter_version_bumper` package programmatically in your Dart scripts or tools.

## Basic Usage

```dart
import 'package:flutter_version_bumper/flutter_version_bumper.dart';

void main() {
  // Parse a version string
  final version = PubspecVersion.parse('1.2.3-beta.1+42');
  print('Current: $version');

  // Bump minor version
  final nextMinor = version.bump('minor', incrementBuild: true, removeBuild: false);
  print('Next Minor: $nextMinor'); // 1.3.0+43
}
```

For full CLI documentation, check the main package [README.md](../README.md).
