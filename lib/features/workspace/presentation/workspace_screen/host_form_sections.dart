part of '../workspace_screen.dart';

class _PrivateKeyFields extends StatelessWidget {
  const _PrivateKeyFields({
    required this.privateKeyController,
    required this.passphraseController,
    required this.onImportKey,
  });

  final TextEditingController privateKeyController;
  final TextEditingController passphraseController;
  final VoidCallback onImportKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('host-private-key-field'),
                controller: privateKeyController,
                minLines: 5,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Private key'),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'Import private key',
              child: IconButton(
                key: const ValueKey('host-import-private-key-button'),
                onPressed: onImportKey,
                icon: const Icon(Icons.file_open_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('host-key-passphrase-field'),
          controller: passphraseController,
          decoration: const InputDecoration(labelText: 'Key passphrase'),
          obscureText: true,
        ),
      ],
    );
  }
}

class _AdvancedConnectionSettingsSection extends StatelessWidget {
  const _AdvancedConnectionSettingsSection({
    required this.expanded,
    required this.connectTimeoutController,
    required this.keepAliveIntervalController,
    required this.reconnectAttemptsController,
    required this.reconnectBackoffController,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController connectTimeoutController;
  final TextEditingController keepAliveIntervalController;
  final TextEditingController reconnectAttemptsController;
  final TextEditingController reconnectBackoffController;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 18,
            ),
            label: const Text('Advanced connection'),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-connect-timeout-field'),
                  controller: connectTimeoutController,
                  label: 'Timeout (s)',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-keepalive-interval-field'),
                  controller: keepAliveIntervalController,
                  label: 'Keepalive (s)',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-reconnect-attempts-field'),
                  controller: reconnectAttemptsController,
                  label: 'Auto reconnect',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ConnectionNumberField(
                  key: const ValueKey('host-reconnect-backoff-field'),
                  controller: reconnectBackoffController,
                  label: 'Backoff (s)',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ConnectionNumberField extends StatelessWidget {
  const _ConnectionNumberField({
    super.key,
    required this.controller,
    required this.label,
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
    );
  }
}

class _IdentitySelectionSection extends StatelessWidget {
  const _IdentitySelectionSection({
    required this.identities,
    required this.selectedIdentityIds,
    required this.enabled,
    required this.onToggle,
  });

  final List<IdentityConfig> identities;
  final Set<IdentityId> selectedIdentityIds;
  final bool enabled;
  final ValueChanged<IdentityId> onToggle;

  @override
  Widget build(BuildContext context) {
    if (identities.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text('No imported identities are available yet.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credentials', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final identity in identities)
              FilterChip(
                label: Text(
                  '${identity.displayName} · ${_identityKindLabel(identity.kind)}',
                ),
                selected: selectedIdentityIds.contains(identity.id),
                onSelected: enabled ? (_) => onToggle(identity.id) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _JumpHostSelectionSection extends StatelessWidget {
  const _JumpHostSelectionSection({
    required this.hosts,
    required this.selectedHostIds,
    required this.enabled,
    required this.onToggle,
  });

  final List<HostSummary> hosts;
  final Set<HostId> selectedHostIds;
  final bool enabled;
  final ValueChanged<HostId> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Jump hosts', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final host in hosts)
              FilterChip(
                label: Text(host.displayName),
                selected: selectedHostIds.contains(host.id),
                onSelected: enabled ? (_) => onToggle(host.id) : null,
              ),
          ],
        ),
      ],
    );
  }
}
