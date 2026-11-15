/// A semantic judgment augments local rules; it never grants SSH access.
enum CommandDecision { safe, dangerous, uncertain }

enum CommandDecisionProvider {
  typesafe('jev-1.13.0'),
  gemini('gemini-decision-1'),
  cloudflare('clef'),
  local('clef');

  const CommandDecisionProvider(this.defaultModel);
  final String defaultModel;
  bool get requiresApiKey => this != local;
}

/// Connection metadata never includes credentials and is stored only on device.
class CommandDecisionConnection {
  const CommandDecisionConnection({
    this.provider = CommandDecisionProvider.typesafe,
    this.accountId = '',
    this.endpoint = '',
  });

  final CommandDecisionProvider provider;
  final String accountId;

  /// Full inference URL for a self-hosted System One service.
  final String endpoint;

  bool isValid({required bool enabled}) {
    switch (provider) {
      case CommandDecisionProvider.typesafe:
      case CommandDecisionProvider.gemini:
        return accountId.isEmpty && endpoint.isEmpty;
      case CommandDecisionProvider.cloudflare:
        return endpoint.isEmpty &&
            ((!enabled && accountId.isEmpty) ||
                RegExp(r'^[a-fA-F0-9]{32}$').hasMatch(accountId));
      case CommandDecisionProvider.local:
        final uri = Uri.tryParse(endpoint);
        return accountId.isEmpty &&
            endpoint.length <= 2048 &&
            uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty &&
            uri.userInfo.isEmpty &&
            !uri.hasQuery &&
            !uri.hasFragment &&
            !endpoint.contains(RegExp(r'\s'));
    }
  }

  bool isValidModel(String model) =>
      RegExp(r'^(?:@cf/cloudflare/)?[a-zA-Z0-9][a-zA-Z0-9._:/-]{0,127}$')
          .hasMatch(model) &&
      (provider != CommandDecisionProvider.cloudflare ||
          RegExp(r'^(?:@cf/cloudflare/)?[a-zA-Z0-9][a-zA-Z0-9._-]{0,100}$')
              .hasMatch(model));

  bool sameRecipient(CommandDecisionConnection other) =>
      provider == other.provider &&
      accountId == other.accountId &&
      endpoint == other.endpoint;
}

abstract interface class CommandDecisionModel {
  Future<CommandDecision> assess({
    required String command,
    required String model,
    required String apiKey,
    CommandDecisionConnection connection = const CommandDecisionConnection(),
  });
}
