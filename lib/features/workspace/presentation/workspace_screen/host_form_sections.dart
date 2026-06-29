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
    final l10n = context.l10n;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SerlinkTextField(
                key: const ValueKey('host-private-key-field'),
                controller: privateKeyController,
                minLines: 5,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: l10n.hostPrivateKeyLabel,
                ),
              ),
            ),
            const SizedBox(width: 8),
            SerlinkTooltip(
              message: l10n.hostImportPrivateKeyTooltip,
              child: SerlinkIconButton(
                key: const ValueKey('host-import-private-key-button'),
                onPressed: onImportKey,
                icon: const Icon(Icons.file_open_outlined),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SerlinkTextField(
          key: const ValueKey('host-key-passphrase-field'),
          controller: passphraseController,
          decoration: InputDecoration(labelText: l10n.hostKeyPassphraseLabel),
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
    required this.compact,
    required this.onToggle,
  });

  final bool expanded;
  final TextEditingController connectTimeoutController;
  final TextEditingController keepAliveIntervalController;
  final TextEditingController reconnectAttemptsController;
  final TextEditingController reconnectBackoffController;
  final bool compact;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final headerPadding = compact
        ? const EdgeInsets.fromLTRB(12, 10, 10, 10)
        : const EdgeInsets.fromLTRB(14, 12, 12, 12);
    final contentPadding = EdgeInsets.all(compact ? 10 : 14);
    final fieldGap = compact ? 10.0 : 14.0;
    final inlineGap = compact ? 8.0 : 12.0;
    return SurfacePanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SerlinkPressable(
            onTap: onToggle,
            borderRadius: SerlinkRadii.control,
            child: Padding(
              padding: headerPadding,
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 18, color: t.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.hostAdvancedConnectionTitle,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                    color: t.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            Divider(height: 1, color: t.borderSubtle),
            Padding(
              padding: contentPadding,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _ConnectionNumberField(
                          key: const ValueKey('host-connect-timeout-field'),
                          controller: connectTimeoutController,
                          label: l10n.hostTimeoutLabel,
                        ),
                      ),
                      SizedBox(width: inlineGap),
                      Expanded(
                        child: _ConnectionNumberField(
                          key: const ValueKey('host-keepalive-interval-field'),
                          controller: keepAliveIntervalController,
                          label: l10n.hostKeepaliveLabel,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: fieldGap),
                  Row(
                    children: [
                      Expanded(
                        child: _ConnectionNumberField(
                          key: const ValueKey('host-reconnect-attempts-field'),
                          controller: reconnectAttemptsController,
                          label: l10n.hostAutoReconnectLabel,
                        ),
                      ),
                      SizedBox(width: inlineGap),
                      Expanded(
                        child: _ConnectionNumberField(
                          key: const ValueKey('host-reconnect-backoff-field'),
                          controller: reconnectBackoffController,
                          label: l10n.hostBackoffLabel,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
    return SerlinkTextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
    );
  }
}

class _HostPortForwardingSection extends StatelessWidget {
  const _HostPortForwardingSection({
    required this.localForwards,
    required this.remoteForwards,
    required this.dynamicForwards,
    required this.localPortController,
    required this.localRemoteHostController,
    required this.localRemotePortController,
    required this.remoteBindHostController,
    required this.remoteBindPortController,
    required this.remoteLocalHostController,
    required this.remoteLocalPortController,
    required this.dynamicBindHostController,
    required this.dynamicBindPortController,
    required this.onAddLocal,
    required this.onRemoveLocal,
    required this.onAddRemote,
    required this.onRemoveRemote,
    required this.onAddDynamic,
    required this.onRemoveDynamic,
  });

  final List<HostLocalPortForward> localForwards;
  final List<HostRemotePortForward> remoteForwards;
  final List<HostDynamicPortForward> dynamicForwards;
  final TextEditingController localPortController;
  final TextEditingController localRemoteHostController;
  final TextEditingController localRemotePortController;
  final TextEditingController remoteBindHostController;
  final TextEditingController remoteBindPortController;
  final TextEditingController remoteLocalHostController;
  final TextEditingController remoteLocalPortController;
  final TextEditingController dynamicBindHostController;
  final TextEditingController dynamicBindPortController;
  final VoidCallback onAddLocal;
  final ValueChanged<int> onRemoveLocal;
  final VoidCallback onAddRemote;
  final ValueChanged<int> onRemoveRemote;
  final VoidCallback onAddDynamic;
  final ValueChanged<int> onRemoveDynamic;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HostForwardingRuleEditor(
          title: l10n.forwardingLocalTitle,
          subtitle: l10n.hostPortForwardingLocalHint,
          buttonLabel: l10n.createAction,
          onAdd: onAddLocal,
          fields: [
            _HostForwardingField(
              controller: localPortController,
              label: l10n.forwardingLocalPortLabel,
              number: true,
            ),
            _HostForwardingField(
              controller: localRemoteHostController,
              label: l10n.forwardingRemoteHostLabel,
              flex: 2,
            ),
            _HostForwardingField(
              controller: localRemotePortController,
              label: l10n.forwardingRemotePortLabel,
              number: true,
            ),
          ],
        ),
        _HostForwardingRuleList(
          entries: [
            for (final forward in localForwards)
              '127.0.0.1:${forward.localPort} -> '
                  '${forward.remoteHost}:${forward.remotePort}',
          ],
          onRemove: onRemoveLocal,
        ),
        const SizedBox(height: 16),
        _HostForwardingRuleEditor(
          title: l10n.forwardingRemoteTitle,
          subtitle: l10n.hostPortForwardingRemoteHint,
          buttonLabel: l10n.createAction,
          onAdd: onAddRemote,
          fields: [
            _HostForwardingField(
              controller: remoteBindHostController,
              label: l10n.forwardingBindHostLabel,
              flex: 2,
            ),
            _HostForwardingField(
              controller: remoteBindPortController,
              label: l10n.forwardingBindPortLabel,
              number: true,
            ),
            _HostForwardingField(
              controller: remoteLocalHostController,
              label: l10n.forwardingLocalHostLabel,
              flex: 2,
            ),
            _HostForwardingField(
              controller: remoteLocalPortController,
              label: l10n.forwardingLocalPortLabel,
              number: true,
            ),
          ],
        ),
        _HostForwardingRuleList(
          entries: [
            for (final forward in remoteForwards)
              '${forward.bindHost}:${forward.bindPort} -> '
                  '${forward.localHost}:${forward.localPort}',
          ],
          onRemove: onRemoveRemote,
        ),
        const SizedBox(height: 16),
        _HostForwardingRuleEditor(
          title: l10n.forwardingSocksTitle,
          subtitle: l10n.hostPortForwardingDynamicHint,
          buttonLabel: l10n.createAction,
          onAdd: onAddDynamic,
          fields: [
            _HostForwardingField(
              controller: dynamicBindHostController,
              label: l10n.forwardingBindHostLabel,
              flex: 2,
            ),
            _HostForwardingField(
              controller: dynamicBindPortController,
              label: l10n.forwardingBindPortLabel,
              number: true,
            ),
          ],
        ),
        _HostForwardingRuleList(
          entries: [
            for (final forward in dynamicForwards)
              '${forward.bindHost}:${forward.bindPort}',
          ],
          onRemove: onRemoveDynamic,
        ),
      ],
    );
  }
}

class _HostForwardingRuleEditor extends StatelessWidget {
  const _HostForwardingRuleEditor({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.fields,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final List<_HostForwardingField> fields;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SerlinkFilledButton.tonal(
              onPressed: onAdd,
              child: Text(buttonLabel),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final field in fields)
              SizedBox(width: field.flex == 1 ? 130 : 210, child: field),
          ],
        ),
      ],
    );
  }
}

class _HostForwardingField extends StatelessWidget {
  const _HostForwardingField({
    required this.controller,
    required this.label,
    this.flex = 1,
    this.number = false,
  });

  final TextEditingController controller;
  final String label;
  final int flex;
  final bool number;

  @override
  Widget build(BuildContext context) {
    return SerlinkTextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: number ? TextInputType.number : TextInputType.text,
      textInputAction: TextInputAction.next,
    );
  }
}

class _HostForwardingRuleList extends StatelessWidget {
  const _HostForwardingRuleList({
    required this.entries,
    required this.onRemove,
  });

  final List<String> entries;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surfaceSunken,
          borderRadius: SerlinkRadii.control,
          border: Border.all(color: t.borderSubtle),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < entries.length; index += 1) ...[
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entries[index],
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                      ),
                    ),
                    SerlinkTooltip(
                      message: context.l10n.removeAction,
                      child: SerlinkIconButton(
                        onPressed: () => onRemove(index),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              if (index < entries.length - 1)
                Divider(height: 1, color: t.borderSubtle),
            ],
          ],
        ),
      ),
    );
  }
}

class _HostFormSection extends StatelessWidget {
  const _HostFormSection({
    required this.title,
    required this.child,
    required this.padding,
  });

  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              color: t.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        SurfacePanel(
          borderRadius: SerlinkRadii.dialog,
          padding: padding,
          child: child,
        ),
      ],
    );
  }
}

class _HostAuthenticationFields extends StatelessWidget {
  const _HostAuthenticationFields({
    required this.useSavedCredentialPicker,
    required this.authMode,
    required this.loadingOptions,
    required this.passwordController,
    required this.passwordVisible,
    required this.privateKeyController,
    required this.keyPassphraseController,
    required this.showSshAgent,
    required this.identityOptions,
    required this.selectedIdentityIds,
    required this.onAuthModeChanged,
    required this.onImportPrivateKey,
    required this.onTogglePasswordVisible,
    required this.onToggleIdentity,
    required this.onEditIdentity,
    required this.onSubmit,
    required this.compact,
  });

  final bool useSavedCredentialPicker;
  final _HostAuthInputMode authMode;
  final bool loadingOptions;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final TextEditingController privateKeyController;
  final TextEditingController keyPassphraseController;
  final bool showSshAgent;
  final List<IdentityConfig> identityOptions;
  final Set<IdentityId> selectedIdentityIds;
  final ValueChanged<_HostAuthInputMode> onAuthModeChanged;
  final VoidCallback onImportPrivateKey;
  final VoidCallback onTogglePasswordVisible;
  final ValueChanged<IdentityId> onToggleIdentity;
  final ValueChanged<IdentityConfig> onEditIdentity;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (useSavedCredentialPicker) {
      return _SavedCredentialFields(
        identityOptions: identityOptions,
        selectedIdentityIds: selectedIdentityIds,
        loadingOptions: loadingOptions,
        onToggleIdentity: onToggleIdentity,
        onEditIdentity: onEditIdentity,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SerlinkSegmentedControl<_HostAuthInputMode>(
              value: authMode,
              segments: [
                SerlinkSegment(
                  value: _HostAuthInputMode.password,
                  icon: Icons.password,
                  label: l10n.hostAuthPasswordSegment,
                ),
                SerlinkSegment(
                  value: _HostAuthInputMode.privateKey,
                  icon: Icons.key,
                  label: l10n.hostAuthKeySegment,
                ),
                if (showSshAgent)
                  SerlinkSegment(
                    value: _HostAuthInputMode.sshAgent,
                    icon: Icons.vpn_key_outlined,
                    label: l10n.hostAuthAgentSegment,
                  ),
                SerlinkSegment(
                  value: _HostAuthInputMode.savedOrNone,
                  icon: Icons.badge_outlined,
                  label: l10n.hostAuthSavedSegment,
                ),
              ],
              onChanged: onAuthModeChanged,
              compact: compact,
            ),
          ),
        ),
        SizedBox(height: compact ? 10 : 14),
        switch (authMode) {
          _HostAuthInputMode.password => SerlinkTextField(
            key: const ValueKey('host-password-field'),
            controller: passwordController,
            decoration: InputDecoration(
              labelText: l10n.hostPasswordLabel,
              suffixIcon: SerlinkIconButton(
                key: const ValueKey('host-password-visibility-toggle'),
                tooltip: passwordVisible
                    ? l10n.hostHidePasswordTooltip
                    : l10n.hostShowPasswordTooltip,
                onPressed: onTogglePasswordVisible,
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                ),
              ),
            ),
            obscureText: !passwordVisible,
            onSubmitted: (_) => onSubmit(),
          ),
          _HostAuthInputMode.privateKey => _PrivateKeyFields(
            privateKeyController: privateKeyController,
            passphraseController: keyPassphraseController,
            onImportKey: onImportPrivateKey,
          ),
          _HostAuthInputMode.sshAgent => const _SshAgentAuthNote(),
          _HostAuthInputMode.savedOrNone => _SavedCredentialFields(
            identityOptions: identityOptions,
            selectedIdentityIds: selectedIdentityIds,
            loadingOptions: loadingOptions,
            onToggleIdentity: onToggleIdentity,
            onEditIdentity: onEditIdentity,
          ),
        },
      ],
    );
  }
}

class _SshAgentAuthNote extends StatelessWidget {
  const _SshAgentAuthNote();

  @override
  Widget build(BuildContext context) {
    return SerlinkAlert.info(
      message: context.l10n.hostSshAgentNote,
      compact: true,
    );
  }
}

class _SavedCredentialFields extends StatelessWidget {
  const _SavedCredentialFields({
    required this.identityOptions,
    required this.selectedIdentityIds,
    required this.loadingOptions,
    required this.onToggleIdentity,
    required this.onEditIdentity,
  });

  final List<IdentityConfig> identityOptions;
  final Set<IdentityId> selectedIdentityIds;
  final bool loadingOptions;
  final ValueChanged<IdentityId> onToggleIdentity;
  final ValueChanged<IdentityConfig> onEditIdentity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _IdentitySelectionSection(
          identities: identityOptions,
          selectedIdentityIds: selectedIdentityIds,
          enabled: !loadingOptions,
          onToggle: onToggleIdentity,
          onEdit: onEditIdentity,
        ),
        const SizedBox(height: 8),
        const _CredentialOptionalNote(),
      ],
    );
  }
}

class _HostFormError extends StatelessWidget {
  const _HostFormError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SerlinkAlert.danger(message: message, compact: true);
  }
}

class _IdentitySelectionSection extends StatelessWidget {
  const _IdentitySelectionSection({
    required this.identities,
    required this.selectedIdentityIds,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
  });

  final List<IdentityConfig> identities;
  final Set<IdentityId> selectedIdentityIds;
  final bool enabled;
  final ValueChanged<IdentityId> onToggle;
  final ValueChanged<IdentityConfig> onEdit;

  @override
  Widget build(BuildContext context) {
    if (identities.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(context.l10n.hostNoSavedCredentials),
      );
    }
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.hostCredentialsHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: SerlinkRadii.control,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: t.surfaceSunken,
              borderRadius: SerlinkRadii.control,
              border: Border.all(color: t.borderSubtle),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < identities.length; index += 1) ...[
                  _CredentialSelectionRow(
                    identity: identities[index],
                    selected: selectedIdentityIds.contains(
                      identities[index].id,
                    ),
                    enabled: enabled,
                    onToggle: onToggle,
                    onEdit: onEdit,
                  ),
                  if (index < identities.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: t.borderSubtle,
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CredentialSelectionRow extends StatelessWidget {
  const _CredentialSelectionRow({
    required this.identity,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    required this.onEdit,
  });

  final IdentityConfig identity;
  final bool selected;
  final bool enabled;
  final ValueChanged<IdentityId> onToggle;
  final ValueChanged<IdentityConfig> onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    final subtitle = [
      _identityKindLabel(l10n, identity.kind),
      if (identity.usernameHint case final username?)
        l10n.identityUserLabel(username),
      if (identity.certificatePrincipal case final principal?)
        l10n.identityPrincipalLabel(principal),
    ].join(' · ');
    return Opacity(
      opacity: enabled ? 1 : 0.54,
      child: SerlinkPressable(
        onTap: enabled ? () => onToggle(identity.id) : null,
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.only(left: 8, right: 4, top: 8, bottom: 8),
        child: Row(
          children: [
            SerlinkCheckbox(
              value: selected,
              onChanged: enabled ? (_) => onToggle(identity.id) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            SerlinkTooltip(
              message: l10n.hostEditCredentialTooltip,
              child: SerlinkIconButton(
                key: ValueKey('credential-edit-${identity.id.value}'),
                onPressed: enabled ? () => onEdit(identity) : null,
                icon: const Icon(Icons.edit_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialOptionalNote extends StatelessWidget {
  const _CredentialOptionalNote();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        context.l10n.hostCredentialOptionalNote,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.tokens.textSecondary),
      ),
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
        Text(
          context.l10n.hostJumpHostsHeading,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final host in hosts)
              SerlinkChoiceChip(
                label: host.displayName,
                selected: selectedHostIds.contains(host.id),
                onSelected: enabled ? (_) => onToggle(host.id) : null,
                enabled: enabled,
              ),
          ],
        ),
      ],
    );
  }
}
