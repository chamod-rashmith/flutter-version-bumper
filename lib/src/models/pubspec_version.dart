/// Represents a parsed version string conforming to Semantic Versioning (SemVer)
/// with an optional build number (e.g., "1.2.3-beta.1+45").
class PubspecVersion {
  final int major;
  final int minor;
  final int patch;
  final String? preRelease;
  final String? build;

  PubspecVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preRelease,
    this.build,
  });

  /// Parses a raw version string like "1.0.0", "1.0.0+1", "1.0.0-beta.1+12".
  static PubspecVersion parse(String versionStr) {
    final cleaned = versionStr.trim();

    // Split by '+' to separate build number/metadata
    final mainParts = cleaned.split('+');
    final versionAndPre = mainParts[0];
    final buildPart = mainParts.length > 1 ? mainParts[1] : null;

    // Split by '-' to separate pre-release identifier
    final preParts = versionAndPre.split('-');
    final numbersPart = preParts[0];
    final preReleasePart = preParts.length > 1 ? preParts.sublist(1).join('-') : null;

    // Parse major, minor, patch numbers
    final versionNumbers = numbersPart.split('.');
    if (versionNumbers.length < 3) {
      throw FormatException('Invalid version format: "$versionStr". Expected X.Y.Z format.');
    }

    final major = int.tryParse(versionNumbers[0]);
    final minor = int.tryParse(versionNumbers[1]);
    final patch = int.tryParse(versionNumbers[2]);

    if (major == null || minor == null || patch == null) {
      throw FormatException('Invalid integer version segments in: "$versionStr".');
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
          if (bumpType == 'major') {
            newMajor++;
            newMinor = 0;
            newPatch = 0;
            newPre = '$preReleaseLabel.1';
          } else if (bumpType == 'minor') {
            newMinor++;
            newPatch = 0;
            newPre = '$preReleaseLabel.1';
          } else {
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
            break;
        }
        newPre = '$preReleaseLabel.1';
      }
    } else {
      // Standard bump (original logic)
      switch (bumpType) {
        case 'major':
          newMajor++;
          newMinor = 0;
          newPatch = 0;
          newPre = null; // Clear pre-release on major bump
          break;
        case 'minor':
          newMinor++;
          newPatch = 0;
          newPre = null; // Clear pre-release on minor bump
          break;
        case 'patch':
          newPatch++;
          newPre = null; // Clear pre-release on patch bump
          break;
        case 'build':
          // Standard semver parts remain the same, only the build is bumped
          break;
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
