/// A compensating action step registered during a release transaction.
///
/// Encapsulates a human-readable [description] of the action and an executable
/// [action] callback invoked if the transaction fails and needs to be undone.
class RollbackStep {
  /// A human-readable description of this rollback step (e.g., `"Restore pubspec.yaml"`).
  final String description;

  /// The closure to execute when reverting this step.
  final void Function() action;

  /// Creates a [RollbackStep] with the specified [description] and [action].
  RollbackStep({
    required this.description,
    required this.action,
  });
}
