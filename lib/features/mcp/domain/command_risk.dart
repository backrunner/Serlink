enum CommandRiskLevel { safe, needsConfirm, blocked }

/// Result of assessing one shell command against the risk policy.
class CommandRiskAssessment {
  const CommandRiskAssessment({
    required this.level,
    required this.command,
    this.matchedRule,
  });

  final CommandRiskLevel level;

  /// Identifier of the rule that matched, if any.
  final String? matchedRule;

  /// The command as it was assessed.
  final String command;
}
