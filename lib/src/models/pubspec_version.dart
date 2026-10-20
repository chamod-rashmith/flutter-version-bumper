/// A parsed version model conforming to Semantic Versioning (SemVer).
///
/// Represents a Semantic Version with an optional pre-release identifier
/// (e.g., `"beta.1"`) and build number (e.g., `"45"`).
class PubspecVersion {
  /// The major version segment.
  final int major;

  /// The minor version segment.
  final int minor;

  /// The patch version segment.
  final int patch;

  /// The optional pre-release identifier string (e.g., `"beta.1"`).
  final String? preRelease;

  /// The optional build number or metadata string (e.g., `"45"`).
  final String? build;

  /// Creates a [PubspecVersion] instance with the specified version components.
  PubspecVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.build,
  });

  /// Parses a raw version string into a [PubspecVersion] instance.
  ///
  /// Accepts standard Semantic Versioning formats with optional pre-release
  /// identifiers and build numbers (e.g., `"1.0.0"`, `"1.0.0+1"`, `"1.2.3-beta.1+42"`).
  ///
  /// Throws a [FormatException] if [versionStr] does not contain at least
  /// three dot-separated integer segments (major, minor, and patch).
  static PubspecVersion parse(String versionStr) {
    final cleaned = versionStr.trim();

    // Split by '+' to separate build number/metadata
    final mainParts = cleaned.split('+');
    final versionAndPre = mainParts[0];
    final buildPart = mainParts.length > 1 ? mainParts[1] : null;

    // Split by '-' to separate pre-release identifier
    final preParts = versionAndPre.split('-');
    final numbersPart = preParts[0];
    final preReleasePart =
        preParts.length > 1 ? preParts.sublist(1).join('-') : null;

    // Parse major, minor, patch numbers using Dart 3 pattern matching
    final (major, minor, patch) = switch (numbersPart.split('.')) {
      [final majStr, final minStr, final patStr] => (
          int.tryParse(majStr),
          int.tryParse(minStr),
          int.tryParse(patStr),
        ),
      _ => throw FormatException(
          'Invalid version format: "$versionStr". Expected X.Y.Z format.',
        ),
    };

    if (major == null || minor == null || patch == null) {
      throw FormatException(
          'Invalid integer version segments in: "$versionStr".');
    }

    return PubspecVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preReleasePart,
      build: buildPart,
    );
  }

  /// Generates a new bumped version based on the target segment.
  ///
  /// The [bumpType] specifies which segment to increment and must be one of
  /// `'major'`, `'minor'`, `'patch'`, or `'build'`.
  ///
  /// If [incrementBuild] is `true`, the build number segment is incremented by 1.
  /// If [removeBuild] is `true`, any build number metadata is stripped from the version.
  /// Providing an [explicitBuild] overrides any auto-incremented build number.
  ///
  /// When [preReleaseLabel] is provided (e.g., `'beta'`), this transitions the
  /// version to or increments within that pre-release track.
  ///
  /// Throws an [ArgumentError] if [bumpType] is not a recognized segment.
  PubspecVersion bump(
    String bumpType, {
    required bool incrementBuild,
    int? explicitBuild,
    required bool removeBuild,
    String? preReleaseLabel,
  }) {
    int newMajor = major;
    int newMinor = minor;
    int newPatch = patch;
    String? newPre = preRelease;

    if (preReleaseLabel != null) {
      if (preRelease != null) {
        final parts = preRelease!.split('.');
        final existingLabel = parts[0];
        if (existingLabel == preReleaseLabel) {
          switch (bumpType) {
            case 'major':
              newMajor++;
              newMinor = 0;
              newPatch = 0;
              newPre = '$preReleaseLabel.1';
            case 'minor':
              newMinor++;
              newPatch = 0;
              newPre = '$preReleaseLabel.1';
            case _:
              // Keep major, minor, patch same, bump pre-release suffix
              int existingNum = 0;
              if (parts.length > 1) {
                existingNum = int.tryParse(parts[1]) ?? 0;
              }
              newPre = '$preReleaseLabel.${existingNum + 1}';
          }
        } else {
          // Label changed (e.g. beta -> rc). Keep version same, start new pre-release sequence
          newPre = '$preReleaseLabel.1';
        }
      } else {
        // No pre-release currently. Bump standard segment, and set pre-release to label.1
        final (bMajor, bMinor, bPatch) = switch (bumpType) {
          'major' => (major + 1, 0, 0),
          'minor' => (major, minor + 1, 0),
          'patch' => (major, minor, patch + 1),
          'build' => (major, minor, patch),
          _ => throw ArgumentError('Unknown bump type: "$bumpType".'),
        };
        newMajor = bMajor;
        newMinor = bMinor;
        newPatch = bPatch;
        newPre = '$preReleaseLabel.1';
      }
    } else {
      // Standard bump
      final (bMajor, bMinor, bPatch) = switch (bumpType) {
        'major' => (major + 1, 0, 0),
        'minor' => (major, minor + 1, 0),
        'patch' => (major, minor, patch + 1),
        'build' => (major, minor, patch),
        _ => throw ArgumentError('Unknown bump type: "$bumpType".'),
      };
      newMajor = bMajor;
      newMinor = bMinor;
      newPatch = bPatch;
      if (bumpType != 'build') {
        newPre = null; // Clear pre-release on major/minor/patch bump
      }
    }

    String? newBuildStr;
    if (!removeBuild) {
      if (explicitBuild != null) {
        newBuildStr = explicitBuild.toString();
      } else if (incrementBuild) {
        final currentBuildInt = build != null ? (int.tryParse(build!) ?? 0) : 0;
        newBuildStr = (currentBuildInt + 1).toString();
      } else {
        newBuildStr = build;
      }
    }

    return PubspecVersion(
      major: newMajor,
      minor: newMinor,
      patch: newPatch,
      preRelease: newPre,
      build: newBuildStr,
    );
  }

  /// Promotes a pre-release version to a stable release.
  ///
  /// Strips the pre-release identifier while preserving major, minor, and patch
  /// segments (e.g. `1.2.0-beta.1+2` -> `1.2.0+3`).
  ///
  /// If [incrementBuild] is `true`, increments the build number.
  /// If [removeBuild] is `true`, removes the build metadata.
  /// If [explicitBuild] is specified, overrides the build number.
  PubspecVersion promote({
    required bool incrementBuild,
    int? explicitBuild,
    required bool removeBuild,
  }) {
    String? newBuildStr;
    if (!removeBuild) {
      if (explicitBuild != null) {
        newBuildStr = explicitBuild.toString();
      } else if (incrementBuild) {
        final currentBuildInt = build != null ? (int.tryParse(build!) ?? 0) : 0;
        newBuildStr = (currentBuildInt + 1).toString();
      } else {
        newBuildStr = build;
      }
    }

    return PubspecVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: null,
      build: newBuildStr,
    );
  }

  /// Returns standard SemVer formatted version string (e.g., `"1.2.3-beta.1+45"`).
  @override
  String toString() {
    final sb = StringBuffer('$major.$minor.$patch');
    if (preRelease != null && preRelease!.isNotEmpty) {
      sb.write('-$preRelease');
    }
    if (build != null && build!.isNotEmpty) {
      sb.write('+$build');
    }
    return sb.toString();
  }
}
