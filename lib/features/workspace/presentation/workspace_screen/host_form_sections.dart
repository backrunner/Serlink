part of '../workspace_screen.dart';

const _kNewGroupSentinel = '__new_group__';

class _HostGroupField extends StatelessWidget {
  const _HostGroupField({
    required this.groupOptions,
    required this.selectedGroup,
    required this.creatingNewGroup,
    required this.newGroupController,
    required this.fieldGap,
    required this.onChanged,
  });

  final List<String> groupOptions;
  final String? selectedGroup;
  final bool creatingNewGroup;
  final TextEditingController newGroupController;
  final double fieldGap;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectValue = creatingNewGroup
        ? _kNewGroupSentinel
        : (selectedGroup ?? '');
    return Column(
      children: [
        SerlinkSelect<String>(
          key: const ValueKey('host-group-select'),
          value: selectValue,
          hintText: l10n.hostGroupLabel,
          items: [
            SerlinkSelectItem(
              value: '',
              label: l10n.hostGroupNone,
              icon: Icons.block,
            ),
            for (final group in groupOptions)
              SerlinkSelectItem(
                value: group,
                label: group,
                icon: Icons.folder_outlined,
              ),
            SerlinkSelectItem(
              value: _kNewGroupSentinel,
              label: l10n.hostGroupNew,
              icon: Icons.create_new_folder_outlined,
            ),
          ],
          onChanged: onChanged,
        ),
        if (creatingNewGroup) ...[
          SizedBox(height: fieldGap),
          SerlinkTextField(
            key: const ValueKey('host-new-group-field'),
            controller: newGroupController,
            decoration: InputDecoration(hintText: l10n.hostGroupNewHint),
            textInputAction: TextInputAction.next,
            autofocus: true,
          ),
        ],
      ],
    );
  }
}

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
    final fieldGap = compact ? 10.0 : 14.0;
    final inlineGap = compact ? 8.0 : 12.0;
    return _HostCollapsibleSection(
      title: l10n.hostAdvancedConnectionTitle,
      icon: Icons.tune_rounded,
      expanded: expanded,
      compact: compact,
      onToggle: onToggle,
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
    );
  }
}

class _HostCollapsibleSection extends StatelessWidget {
  const _HostCollapsibleSection({
    required this.title,
    required this.icon,
    required this.expanded,
    required this.compact,
    required this.onToggle,
    required this.child,
  });

  final String title;
  final IconData icon;
  final bool expanded;
  final bool compact;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inset = Theme.of(context).platform == TargetPlatform.iOS
        ? 16.0
        : (compact ? 12.0 : 16.0);
    return _HostSectionFrame(
      padding: EdgeInsets.all(inset),
      header: Semantics(
        expanded: expanded,
        child: SerlinkPressable(
          onTap: onToggle,
          borderRadius: expanded
              ? const BorderRadius.vertical(top: SerlinkRadii.dialogR)
              : SerlinkRadii.dialog,
          hoverColor: t.surfaceOverlay,
          pressedColor: t.textPrimary.withValues(alpha: 0.12),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
            child: _HostSectionHeading(
              title: title,
              icon: icon,
              trailing: AnimatedRotation(
                turns: expanded ? 0.25 : 0,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 13,
                  color: t.textMuted,
                ),
              ),
            ),
          ),
        ),
      ),
      child: expanded ? child : null,
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

class _RemoteSessionSection extends StatelessWidget {
  const _RemoteSessionSection({
    required this.enabled,
    required this.manager,
    required this.sessionNameController,
    required this.createIfMissing,
    required this.fallbackToShell,
    required this.compact,
    required this.onEnabledChanged,
    required this.onManagerChanged,
    required this.onCreateIfMissingChanged,
    required this.onFallbackToShellChanged,
  });

  final bool enabled;
  final HostRemoteSessionManager manager;
  final TextEditingController sessionNameController;
  final bool createIfMissing;
  final bool fallbackToShell;
  final bool compact;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<HostRemoteSessionManager> onManagerChanged;
  final ValueChanged<bool> onCreateIfMissingChanged;
  final ValueChanged<bool> onFallbackToShellChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fieldGap = compact ? 10.0 : 14.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SerlinkSwitchListTile(
          value: enabled,
          onChanged: onEnabledChanged,
          title: Text(l10n.hostRemoteSessionEnableTitle),
          contentPadding: EdgeInsets.zero,
        ),
        SizedBox(height: fieldGap),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SerlinkSegmentedControl<HostRemoteSessionManager>(
            value: manager,
            enabled: enabled,
            compact: compact,
            onChanged: onManagerChanged,
            segments: [
              SerlinkSegment(
                value: HostRemoteSessionManager.auto,
                label: l10n.hostRemoteSessionManagerAuto,
                icon: Icons.auto_awesome_outlined,
              ),
              SerlinkSegment(
                value: HostRemoteSessionManager.tmux,
                label: l10n.hostRemoteSessionManagerTmux,
                icon: Icons.view_column_outlined,
              ),
              SerlinkSegment(
                value: HostRemoteSessionManager.screen,
                label: l10n.hostRemoteSessionManagerScreen,
                icon: Icons.screenshot_monitor_outlined,
              ),
            ],
          ),
        ),
        SizedBox(height: fieldGap),
        SerlinkTextField(
          key: const ValueKey('host-remote-session-name-field'),
          controller: sessionNameController,
          enabled: enabled,
          maxLength: 64,
          decoration: InputDecoration(
            labelText: l10n.hostRemoteSessionNameLabel,
            counterText: '',
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9_.-]')),
          ],
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: fieldGap),
        SerlinkSwitchListTile(
          value: createIfMissing,
          onChanged: enabled ? onCreateIfMissingChanged : null,
          title: Text(l10n.hostRemoteSessionCreateIfMissing),
          contentPadding: EdgeInsets.zero,
        ),
        SizedBox(height: fieldGap),
        SerlinkSwitchListTile(
          value: fallbackToShell,
          onChanged: enabled ? onFallbackToShellChanged : null,
          title: Text(l10n.hostRemoteSessionFallbackToShell),
          contentPadding: EdgeInsets.zero,
        ),
      ],
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
    required this.icon,
    required this.child,
    required this.padding,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final insets = padding.resolve(Directionality.of(context));
    return _HostSectionFrame(
      padding: padding,
      header: Padding(
        padding: EdgeInsets.fromLTRB(insets.left, 12, insets.right, 12),
        child: _HostSectionHeading(title: title, icon: icon),
      ),
      child: child,
    );
  }
}

/// Keep the title and its fields in one visibly bounded group, including when
/// the surrounding dialog uses the same raised surface as the form body.
class _HostSectionFrame extends StatelessWidget {
  const _HostSectionFrame({
    required this.header,
    required this.padding,
    this.child,
  });

  final Widget header;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surfaceRaised,
        border: Border.all(color: t.borderSubtle),
        borderRadius: SerlinkRadii.dialog,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: Color.alphaBlend(
              t.surfaceBase.withValues(alpha: 0.7),
              t.surfaceRaised,
            ),
            child: header,
          ),
          if (child != null) ...[
            Divider(height: 1, color: t.borderSubtle),
            Padding(padding: padding, child: child),
          ],
        ],
      ),
    );
  }
}

class _HostSectionHeading extends StatelessWidget {
  const _HostSectionHeading({
    required this.title,
    required this.icon,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 18, color: t.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
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
    required this.onDeleteIdentity,
    required this.onAddIdentity,
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
  final ValueChanged<IdentityConfig> onDeleteIdentity;
  final VoidCallback onAddIdentity;
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
        onDeleteIdentity: onDeleteIdentity,
        onAddIdentity: onAddIdentity,
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
            onDeleteIdentity: onDeleteIdentity,
            onAddIdentity: onAddIdentity,
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
    required this.onDeleteIdentity,
    required this.onAddIdentity,
  });

  final List<IdentityConfig> identityOptions;
  final Set<IdentityId> selectedIdentityIds;
  final bool loadingOptions;
  final ValueChanged<IdentityId> onToggleIdentity;
  final ValueChanged<IdentityConfig> onEditIdentity;
  final ValueChanged<IdentityConfig> onDeleteIdentity;
  final VoidCallback onAddIdentity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (identityOptions.isEmpty)
          const _CredentialsEmptyState()
        else
          AnimatedOpacity(
            duration: const Duration(milliseconds: 130),
            opacity: loadingOptions ? 0.54 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (
                  var index = 0;
                  index < identityOptions.length;
                  index += 1
                ) ...[
                  if (index > 0) const SizedBox(height: 8),
                  _CredentialSelectionRow(
                    identity: identityOptions[index],
                    selected: selectedIdentityIds.contains(
                      identityOptions[index].id,
                    ),
                    enabled: !loadingOptions,
                    onToggle: onToggleIdentity,
                    onEdit: onEditIdentity,
                    onDelete: onDeleteIdentity,
                  ),
                ],
                const SizedBox(height: 8),
                const _CredentialOptionalNote(),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: SerlinkOutlinedButton.icon(
            key: const ValueKey('credential-add-button'),
            onPressed: loadingOptions ? null : onAddIdentity,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(context.l10n.hostAddCredentialAction),
          ),
        ),
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

class _CredentialsEmptyState extends StatelessWidget {
  const _CredentialsEmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: t.surfaceSunken,
        borderRadius: SerlinkRadii.control,
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.badge_outlined, size: 20, color: t.textMuted),
          const SizedBox(height: 8),
          Text(
            l10n.hostNoSavedCredentials,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            l10n.hostCredentialOptionalNote,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: t.textMuted),
          ),
        ],
      ),
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
    required this.onDelete,
  });

  final IdentityConfig identity;
  final bool selected;
  final bool enabled;
  final ValueChanged<IdentityId> onToggle;
  final ValueChanged<IdentityConfig> onEdit;
  final ValueChanged<IdentityConfig> onDelete;

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
    return SerlinkContextMenu(
      enabled: enabled,
      actions: [
        SerlinkMenuAction(
          label: l10n.hostEditCredentialTooltip,
          icon: Icons.edit_outlined,
          onPressed: () => onEdit(identity),
        ),
        SerlinkMenuAction(
          label: l10n.credentialsDeleteTooltip,
          icon: Icons.delete_outline,
          onPressed: () => onDelete(identity),
        ),
      ],
      child: ListRow(
        selected: selected,
        onTap: enabled ? () => onToggle(identity.id) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: selected
                    ? t.accentPrimary.withValues(alpha: 0.16)
                    : t.surfaceSunken,
                borderRadius: SerlinkRadii.control,
              ),
              child: Icon(
                _identityKindIcon(identity.kind),
                size: 18,
                color: selected ? t.accentPrimary : t.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
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
            const SizedBox(width: 4),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 130),
              opacity: selected ? 1 : 0,
              child: Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: t.accentPrimary,
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
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        context.l10n.hostCredentialOptionalNote,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: context.tokens.textMuted),
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
