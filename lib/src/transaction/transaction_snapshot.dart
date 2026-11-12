/// A persisted snapshot capturing filesystem and Git state prior to a release.
///
/// Enables atomic recovery either automatically upon operational failure,
/// or manually via the `fvb --rollback` CLI invocation.
class TransactionSnapshot {
  /// The SemVer string prior to the bump (e.g., `"1.0.0+1"`).
  final String previousVersion;

  /// The bumped SemVer string intended for this release (e.g., `"1.0.1+2"`).
  final String newVersion;

  /// The absolute or canonical path to the targeted `pubspec.yaml` file.
  final String pubspecPath;

  /// The exact verbatim content of `pubspec.yaml` before any modifications.
  final String originalPubspecContent;

  /// The path to the project's `CHANGELOG.md` file, if changelog tracking was active.
  final String? changelogPath;

  /// The verbatim content of `CHANGELOG.md` before updates were prepended.
  final String? originalChangelogContent;

  /// Whether `CHANGELOG.md` already existed on disk before the operation.
  final bool changelogExisted;

  /// The Git commit SHA pointing to `HEAD` prior to creating release commits.
  final String? initialGitHead;

  /// The Git commit SHA created during this version bump transaction, if any.
  final String? createdGitCommit;

  /// The annotated Git tag name created during this transaction (e.g., `"v1.0.1+2"`).
  final String? createdGitTag;

  /// An ISO-8601 formatted timestamp indicating when this snapshot was captured.
  final String timestamp;

  /// Creates a [TransactionSnapshot] with the specified state parameters.
  TransactionSnapshot({
    required this.previousVersion,
    required this.newVersion,
    required this.pubspecPath,
    required this.originalPubspecContent,
    this.changelogPath,
    this.originalChangelogContent,
    required this.changelogExisted,
    this.initialGitHead,
    this.createdGitCommit,
    this.createdGitTag,
    required this.timestamp,
  });

  /// Converts this snapshot instance into a JSON-encodable map.
  Map<String, dynamic> toJson() => {
        'previous_version': previousVersion,
        'new_version': newVersion,
        'pubspec_path': pubspecPath,
        'original_pubspec_content': originalPubspecContent,
        'changelog_path': changelogPath,
        'original_changelog_content': originalChangelogContent,
        'changelog_existed': changelogExisted,
        'initial_git_head': initialGitHead,
        'created_git_commit': createdGitCommit,
        'created_git_tag': createdGitTag,
        'timestamp': timestamp,
      };

  /// Constructs a [TransactionSnapshot] instance from a decoded [json] map.
  factory TransactionSnapshot.fromJson(Map<String, dynamic> json) =>
      TransactionSnapshot(
        previousVersion: json['previous_version'] as String,
        newVersion: json['new_version'] as String,
        pubspecPath: json['pubspec_path'] as String,
        originalPubspecContent: json['original_pubspec_content'] as String,
        changelogPath: json['changelog_path'] as String?,
        originalChangelogContent: json['original_changelog_content'] as String?,
        changelogExisted: json['changelog_existed'] as bool? ?? true,
        initialGitHead: json['initial_git_head'] as String?,
        createdGitCommit: json['created_git_commit'] as String?,
        createdGitTag: json['created_git_tag'] as String?,
        timestamp: json['timestamp'] as String? ?? '',
      );

  /// Creates a copy of this snapshot with updated Git references.
  TransactionSnapshot copyWith({
    String? previousVersion,
    String? newVersion,
    String? pubspecPath,
    String? originalPubspecContent,
    String? changelogPath,
    String? originalChangelogContent,
    bool? changelogExisted,
    String? initialGitHead,
    String? createdGitCommit,
    String? createdGitTag,
    String? timestamp,
  }) {
    return TransactionSnapshot(
      previousVersion: previousVersion ?? this.previousVersion,
      newVersion: newVersion ?? this.newVersion,
      pubspecPath: pubspecPath ?? this.pubspecPath,
      originalPubspecContent:
          originalPubspecContent ?? this.originalPubspecContent,
      changelogPath: changelogPath ?? this.changelogPath,
      originalChangelogContent:
          originalChangelogContent ?? this.originalChangelogContent,
      changelogExisted: changelogExisted ?? this.changelogExisted,
      initialGitHead: initialGitHead ?? this.initialGitHead,
      createdGitCommit: createdGitCommit ?? this.createdGitCommit,
      createdGitTag: createdGitTag ?? this.createdGitTag,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
