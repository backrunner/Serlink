/// A semantic judgment augments local rules; it never grants SSH access.
enum CommandDecision { safe, dangerous, uncertain }

abstract interface class CommandDecisionModel {
  Future<CommandDecision> assess({
    required String command,
    required String model,
    required String apiKey,
  });
}
