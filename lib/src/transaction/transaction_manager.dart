import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../utils/logger.dart';
import 'rollback_step.dart';
import 'transaction_snapshot.dart';

export 'rollback_step.dart';
export 'transaction_snapshot.dart';

/// Coordinates transactional release execution and failure rollbacks.
///
/// Records pre-bump filesystem and Git state, maintains a LIFO stack of compensating
/// actions, and restores the repository if any stage fails.
class TransactionManager {
  /// The root directory of the project undergoing a version bump.
  final String projectDir;

  /// Whether automated rollback is enabled if an operational step fails.
  final bool rollbackOnFailure;

  /// Whether console output should be suppressed.
  final bool quiet;

  /// Whether console output should be formatted as JSON.
  final bool jsonMode;

  final List<RollbackStep> _steps = [];
  TransactionSnapshot? _snapshot;

  /// Creates a [TransactionManager] instance for [projectDir].
  TransactionManager({
    required this.projectDir,
    this.rollbackOnFailure = true,
    this.quiet = false,
    this.jsonMode = false,
  });

  /// The active transaction snapshot capturing pre-bump state, if initialized.
  TransactionSnapshot? get snapshot => _snapshot;

  /// An unmodifiable list of registered compensating rollback steps.
  List<RollbackStep> get steps => List.unmodifiable(_steps);

  /// Resolves the storage location for `.fvb_backup.json`.
  ///
  /// Prefers `.git/fvb_backup.json` to keep working directory clean,
  /// falling back to `.fvb_backup.json` in [projectDir] if `.git` does not exist.
  static File resolveBackupFile(String projectDir) {
    final gitDir = Directory(path.join(projectDir, '.git'));
    if (gitDir.existsSync()) {
      return File(path.join(gitDir.path, 'fvb_backup.json'));
    }
    return File(path.join(projectDir, '.fvb_backup.json'));
  }

  /// Initializes the transaction by capturing the initial state before any mutations.
  ///
  /// Records [previousVersion], intended [newVersion], original [pubspecFile] content,
  /// optional [changelogPath] content and existence, and current Git `HEAD` commit SHA.
  void captureInitialState({
    required String previousVersion,
    required String newVersion,
    required File pubspecFile,
    required String originalPubspecContent,
    String? changelogPath,
  }) {
    String? originalChangelog;
    bool changelogExists = false;

    if (changelogPath != null) {
      final changelogFile = File(changelogPath);
      if (changelogFile.existsSync()) {
        changelogExists = true;
        try {
          originalChangelog = changelogFile.readAsStringSync();
        } catch (_) {}
      }
    }

    String? currentHead;
    try {
      final res = Process.runSync(
        'git',
        ['rev-parse', 'HEAD'],
        workingDirectory: projectDir,
      );
      if (res.exitCode == 0) {
        currentHead = (res.stdout as String).trim();
      }
    } catch (_) {}

    _snapshot = TransactionSnapshot(
      previousVersion: previousVersion,
      newVersion: newVersion,
      pubspecPath: pubspecFile.path,
      originalPubspecContent: originalPubspecContent,
      changelogPath: changelogPath,
      originalChangelogContent: originalChangelog,
      changelogExisted: changelogExists,
      initialGitHead: currentHead,
      timestamp: DateTime.now().toIso8601String(),
    );
  }

  /// Records the Git commit SHA created during this version bump transaction.
  void recordGitCommit(String commitSha) {
    if (_snapshot != null) {
      _snapshot = _snapshot!.copyWith(createdGitCommit: commitSha);
    }
  }

  /// Records the Git tag name created during this version bump transaction.
  void recordGitTag(String tagName) {
    if (_snapshot != null) {
      _snapshot = _snapshot!.copyWith(createdGitTag: tagName);
    }
  }

  /// Registers a compensating rollback action to be run if subsequent steps fail.
  ///
  /// [description] provides a human-readable title for logging, and [action]
  /// is executed in reverse registration order (LIFO).
  void registerRollbackStep({
    required String description,
    required void Function() action,
  }) {
    _steps.add(RollbackStep(description: description, action: action));
  }

  /// Persists the transaction snapshot to disk for manual `fvb --rollback` recovery.
  void persistBackup() {
    if (_snapshot == null) return;
    try {
      final file = resolveBackupFile(projectDir);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(json.encode(_snapshot!.toJson()));
    } catch (_) {}
  }

  /// Removes the persisted backup file upon successful completion and remote push.
  void clearBackup() {
    try {
      final file = resolveBackupFile(projectDir);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}

    // Also remove legacy root backup file if present
    try {
      final rootFile = File(path.join(projectDir, '.fvb_backup.json'));
      if (rootFile.existsSync()) {
        rootFile.deleteSync();
      }
    } catch (_) {}
  }

  /// Executes all registered rollback steps in LIFO order to revert changes cleanly.
  ///
  /// Returns `true` if rollback succeeded.
  bool rollback() {
    if (_steps.isEmpty) return true;

    logWarning(
      'Transaction failed. Rolling back ${_steps.length} operation(s) cleanly...',
      quiet,
      jsonMode,
    );

    var allSucceeded = true;
    for (final step in _steps.reversed) {
      try {
        step.action();
      } catch (e) {
        allSucceeded = false;
        logWarning(
          'Failed during rollback step "${step.description}": $e',
          quiet,
          jsonMode,
        );
      }
    }

    clearBackup();
    logInfo(
      '[Transaction] Rollback complete. Repository restored to previous state.',
      quiet,
      jsonMode,
      colorCode: '\x1B[33m',
    );

    return allSucceeded;
  }

  /// Manually reverts the most recent local version bump from a saved backup snapshot.
  ///
  /// Returns `true` if a transaction snapshot was found and successfully restored.
  static bool performManualRollback({
    required String projectDir,
    required bool quiet,
    required bool jsonMode,
  }) {
    final backupFile = resolveBackupFile(projectDir);
    File? targetFile;

    if (backupFile.existsSync()) {
      targetFile = backupFile;
    } else {
      final rootBackup = File(path.join(projectDir, '.fvb_backup.json'));
      if (rootBackup.existsSync()) {
        targetFile = rootBackup;
      }
    }

    if (targetFile == null) {
      logError(
        'No recent version bump transaction found to rollback.',
        jsonMode,
      );
      return false;
    }

    TransactionSnapshot snapshot;
    try {
      final content = targetFile.readAsStringSync();
      final Map<String, dynamic> decoded =
          json.decode(content) as Map<String, dynamic>;
      snapshot = TransactionSnapshot.fromJson(decoded);
    } catch (e) {
      logError(
        'Failed to read transaction backup file: ${e.toString()}',
        jsonMode,
      );
      return false;
    }

    logInfo(
      'Rolling back version bump: ${snapshot.newVersion} -> ${snapshot.previousVersion}...',
      quiet,
      jsonMode,
      colorCode: '\x1B[36m',
    );

    // 1. Delete created Git tag if present
    if (snapshot.createdGitTag != null) {
      try {
        Process.runSync(
          'git',
          ['tag', '-d', snapshot.createdGitTag!],
          workingDirectory: projectDir,
        );
      } catch (_) {}
    }

    // 2. Revert Git commit if created and initial Git HEAD is known
    if (snapshot.initialGitHead != null) {
      try {
        Process.runSync(
          'git',
          ['reset', '--soft', snapshot.initialGitHead!],
          workingDirectory: projectDir,
        );
      } catch (_) {}
    }

    // 3. Restore CHANGELOG.md
    if (snapshot.changelogPath != null) {
      final changelogFile = File(snapshot.changelogPath!);
      try {
        if (snapshot.changelogExisted &&
            snapshot.originalChangelogContent != null) {
          changelogFile.writeAsStringSync(snapshot.originalChangelogContent!);
        } else if (!snapshot.changelogExisted && changelogFile.existsSync()) {
          changelogFile.deleteSync();
        }
      } catch (_) {}
    }

    // 4. Restore pubspec.yaml
    final pubspecFile = File(snapshot.pubspecPath);
    try {
      pubspecFile.writeAsStringSync(snapshot.originalPubspecContent);
    } catch (e) {
      logError(
        'Failed to restore pubspec.yaml during rollback: ${e.toString()}',
        jsonMode,
      );
      return false;
    }

    // Clean up backup file
    try {
      if (targetFile.existsSync()) targetFile.deleteSync();
    } catch (_) {}

    logInfo(
      '[OK] Successfully rolled back to version ${snapshot.previousVersion}.',
      quiet,
      jsonMode,
      colorCode: '\x1B[32m',
    );

    return true;
  }
}
