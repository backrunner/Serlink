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

class _PrivateKeyFields extends ConsumerStatefulWidget {
  const _PrivateKeyFields({
    super.key,
    required this.privateKeyController,
    required this.passphraseController,
    this.onKeyChanged,
  });

  final TextEditingController privateKeyController;
  final TextEditingController passphraseController;
  final VoidCallback? onKeyChanged;

  @override
  ConsumerState<_PrivateKeyFields> createState() => _PrivateKeyFieldsState();
}

class _PrivateKeyFieldsState extends ConsumerState<_PrivateKeyFields> {
  bool _manualEntry = false;
  bool _importing = false;
  String? _fileName;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.privateKeyController.addListener(_keyChanged);
  }

  @override
  void didUpdateWidget(covariant _PrivateKeyFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.privateKeyController != widget.privateKeyController) {
      oldWidget.privateKeyController.removeListener(_keyChanged);
      widget.privateKeyController.addListener(_keyChanged);
      _fileName = null;
    }
  }

  @override
  void dispose() {
    widget.privateKeyController.removeListener(_keyChanged);
    super.dispose();
  }

  void _keyChanged() {
    setState(() {
      _fileName = null;
      _error = null;
    });
  }

  Future<void> _importKey() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final file = await ref
          .read(documentGatewayProvider)
          .pickTextFile(
            acceptedTypeGroups: [
              XTypeGroup(label: context.l10n.credentialSshPrivateKeyTypeLabel),
            ],
          );
      if (!mounted || file == null) return;
      if (file.contents.trim().isEmpty) {
        setState(() => _error = context.l10n.credentialPrivateKeyImportFailed);
        return;
      }
      widget.privateKeyController.text = file.contents;
      widget.onKeyChanged?.call();
      setState(() {
        _fileName = file.name;
        _manualEntry = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.credentialPrivateKeyImportFailed);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: SerlinkFilledButton.icon(
            key: const ValueKey('host-import-private-key-button'),
            onPressed: _importing ? null : _importKey,
            icon: const Icon(Icons.file_open_outlined, size: 18),
            label: Text(l10n.credentialImportPrivateKeyAction),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.privateKeyController.text.isEmpty
              ? l10n.credentialPrivateKeyFileHint
              : (_fileName ?? l10n.credentialPrivateKeyLoaded),
          key: const ValueKey('private-key-import-status'),
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.tokens.textSecondary),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          SerlinkAlert.danger(message: _error!, compact: true),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: SerlinkTextButton(
            key: const ValueKey('private-key-manual-entry-toggle'),
            onPressed: _importing
                ? null
                : () => setState(() {
                    _manualEntry = !_manualEntry;
                  }),
            child: Text(
              _manualEntry
                  ? l10n.credentialHidePrivateKeyInputAction
                  : l10n.credentialPastePrivateKeyAction,
            ),
          ),
        ),
        if (_manualEntry) ...[
          SerlinkTextField(
            key: const ValueKey('host-private-key-field'),
            controller: widget.privateKeyController,
            minLines: 5,
            maxLines: 8,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => widget.onKeyChanged?.call(),
            decoration: InputDecoration(labelText: l10n.hostPrivateKeyLabel),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        SerlinkTextField(
          key: const ValueKey('host-key-passphrase-field'),
          controller: widget.passphraseController,
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

class _HostCollapsibleSection extends StatefulWidget {
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
  State<_HostCollapsibleSection> createState() =>
      _HostCollapsibleSectionState();
}

class _HostCollapsibleSectionState extends State<_HostCollapsibleSection> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final inset = Theme.of(context).platform == TargetPlatform.iOS
        ? 16.0
        : (widget.compact ? 12.0 : 16.0);
    return _HostSectionFrame(
      padding: EdgeInsets.all(inset),
      borderColor: _hovered ? t.borderStrong : t.borderSubtle,
      header: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Semantics(
          expanded: widget.expanded,
          child: SerlinkPressable(
            onTap: widget.onToggle,
            borderRadius: widget.expanded
                ? const BorderRadius.vertical(top: SerlinkRadii.dialogR)
                : SerlinkRadii.dialog,
            hoverColor: t.surfaceOverlay,
            pressedColor: t.textPrimary.withValues(alpha: 0.12),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: inset, vertical: 12),
              child: _HostSectionHeading(
                title: widget.title,
                icon: widget.icon,
                trailing: AnimatedRotation(
                  turns: widget.expanded ? 0.25 : 0,
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
      ),
      child: widget.expanded ? widget.child : null,
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
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
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
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: t.textSecondary),
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
    this.borderColor,
  });

  final Widget header;
  final EdgeInsetsGeometry padding;
  final Widget? child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      // Paint one outline above the clipped header and hover fill, without an
      // inset that would give their rounded corners a second, mismatched edge.
      foregroundDecoration: BoxDecoration(
        border: Border.all(color: borderColor ?? t.borderSubtle),
        borderRadius: SerlinkRadii.dialog,
      ),
      child: ClipRRect(
        borderRadius: SerlinkRadii.dialog,
        child: ColoredBox(
          color: t.surfaceSunken,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: Color.alphaBlend(
                  t.surfaceBase.withValues(alpha: 0.7),
                  t.surfaceSunken,
                ),
                child: header,
              ),
              if (child != null) ...[
                Divider(height: 1, color: t.borderSubtle),
                Padding(padding: padding, child: child),
              ],
            ],
          ),
        ),
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
    required this.authMode,
    required this.loadingOptions,
    required this.passwordController,
    required this.passwordVisible,
    required this.privateKeyController,
    required this.keyPassphraseController,
    required this.agentSocketController,
    required this.agentPublicKeyController,
    required this.showSshAgent,
    required this.identityOptions,
    required this.selectedIdentityIds,
    required this.onAuthModeChanged,
    required this.onTogglePasswordVisible,
    required this.onToggleIdentity,
    required this.onEditIdentity,
    required this.onDeleteIdentity,
    required this.onSubmit,
    required this.compact,
  });

  final _HostAuthInputMode authMode;
  final bool loadingOptions;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final TextEditingController privateKeyController;
  final TextEditingController keyPassphraseController;
  final TextEditingController agentSocketController;
  final TextEditingController agentPublicKeyController;
  final bool showSshAgent;
  final List<IdentityConfig> identityOptions;
  final Set<IdentityId> selectedIdentityIds;
  final ValueChanged<_HostAuthInputMode> onAuthModeChanged;
  final VoidCallback onTogglePasswordVisible;
  final ValueChanged<IdentityId> onToggleIdentity;
  final ValueChanged<IdentityConfig> onEditIdentity;
  final ValueChanged<IdentityConfig> onDeleteIdentity;
  final VoidCallback onSubmit;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SerlinkScrollView(
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
          ),
          _HostAuthInputMode.sshAgent => _AgentFields(
            socketController: agentSocketController,
            publicKeyController: agentPublicKeyController,
          ),
          _HostAuthInputMode.savedOrNone => _SavedCredentialFields(
            identityOptions: identityOptions,
            selectedIdentityIds: selectedIdentityIds,
            loadingOptions: loadingOptions,
            onToggleIdentity: onToggleIdentity,
            onEditIdentity: onEditIdentity,
            onDeleteIdentity: onDeleteIdentity,
          ),
        },
      ],
    );
  }
}

IdentityAgentConfig _agentConfig(
  TextEditingController socket,
  TextEditingController publicKey,
) => IdentityAgentConfig(
  socketPath: socket.text.trim().isEmpty ? null : socket.text.trim(),
  publicKey: publicKey.text.trim().isEmpty ? null : publicKey.text.trim(),
);

class _AgentFields extends ConsumerStatefulWidget {
  const _AgentFields({
    required this.socketController,
    required this.publicKeyController,
    this.hardwareKey = false,
  });

  final TextEditingController socketController;
  final TextEditingController publicKeyController;
  final bool hardwareKey;

  @override
  ConsumerState<_AgentFields> createState() => _AgentFieldsState();
}

class _AgentFieldsState extends ConsumerState<_AgentFields> {
  bool _importing = false;
  bool _findingEndpoint = false;
  bool _customEndpoint = false;
  DiscoveredSshAgent? _chosenProvider;
  bool _manualPublicKey = false;
  String? _selectedLabel;
  String? _selectedFingerprint;
  String? _error;

  Future<void> _findEndpoint() async {
    if (_importing) return;
    var refresh = false;
    setState(() {
      _importing = true;
      _findingEndpoint = true;
      _error = null;
    });
    try {
      final endpoints =
          (await ref.read(sshAgentEndpointLoaderProvider)()).toList()..sort((
            a,
            b,
          ) {
            final byKeys = b.identities.length.compareTo(a.identities.length);
            return byKeys == 0 ? a.socketPath.compareTo(b.socketPath) : byKeys;
          });
      if (!mounted) return;
      setState(() => _findingEndpoint = false);
      final selected = await showSerlinkDialog<DiscoveredSshAgent>(
        context: context,
        builder: (dialogContext) => SerlinkDialog(
          maxWidth: _adaptiveDialogWidth(dialogContext, _dialogWidthMedium),
          title: Text(dialogContext.l10n.agentChooseEndpointTitle),
          content: SizedBox(
            width: 560,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SerlinkScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (endpoints.isEmpty)
                      SerlinkAlert.info(
                        message: dialogContext.l10n.agentDiscoveryEmptyMessage,
                        compact: true,
                      ),
                    for (final endpoint in endpoints)
                      ListRow(
                        onTap: () => Navigator.of(dialogContext).pop(endpoint),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        selected:
                            widget.socketController.text.trim() ==
                            endpoint.socketPath,
                        child: Row(
                          children: [
                            const Icon(Icons.hub_outlined, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${endpoint.providerHint ?? (endpoint.isSystem ? dialogContext.l10n.agentSystemTitle : dialogContext.l10n.agentLocalTitle)} · ${dialogContext.l10n.agentDiscoveredKeysCount(endpoint.identities.length)}',
                                  ),
                                  const SizedBox(height: 4),
                                  _endpointText(
                                    dialogContext,
                                    endpoint.socketPath,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            SerlinkTextButton(
              key: const ValueKey('agent-refresh-providers-button'),
              onPressed: () {
                refresh = true;
                Navigator.of(dialogContext).pop();
              },
              child: Text(dialogContext.l10n.agentRefreshProvidersAction),
            ),
            SerlinkTextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(dialogContext.l10n.cancelAction),
            ),
          ],
        ),
      );
      if (mounted && selected != null) {
        final changed =
            widget.socketController.text.trim() != selected.socketPath;
        widget.socketController.text = selected.socketPath;
        if (changed) widget.publicKeyController.clear();
        setState(() {
          _chosenProvider = selected;
          _customEndpoint = false;
          if (changed) {
            _selectedLabel = null;
            _selectedFingerprint = null;
            _manualPublicKey = false;
          }
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.agentDiscoveryEmptyMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _findingEndpoint = false;
        });
      }
    }
    if (mounted && refresh) await _findEndpoint();
  }

  Future<void> _selectAgentKey() async {
    if (_importing) return;
    if (widget.socketController.text.trim().isEmpty) {
      await _findEndpoint();
      if (!mounted || widget.socketController.text.trim().isEmpty) return;
    }
    setState(() => _importing = true);
    final endpoint = widget.socketController.text.trim();
    final choices = ref.read(sshAgentIdentityLoaderProvider)(
      endpoint.isEmpty ? null : endpoint,
    );
    unawaited(choices.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    final selected = await showSerlinkDialog<SshAgentIdentityChoice>(
      context: context,
      builder: (dialogContext) => SerlinkDialog(
        maxWidth: _adaptiveDialogWidth(dialogContext, _dialogWidthMedium),
        title: Text(dialogContext.l10n.agentSelectKeyAction),
        content: SizedBox(
          width: 560,
          height: 320,
          child: FutureBuilder<List<SshAgentIdentityChoice>>(
            future: choices,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return SerlinkAlert.danger(
                  message: context.l10n.sshAuthAgentUnavailableMessage,
                  compact: true,
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: SerlinkLoadingIndicator());
              }
              final keys = snapshot.data!;
              if (keys.isEmpty) {
                return SerlinkAlert.info(
                  message: context.l10n.sshAuthAgentEmptyMessage,
                  compact: true,
                );
              }
              return SerlinkScrollView(
                child: Column(
                  children: [
                    for (final key in keys)
                      ListRow(
                        onTap: () => Navigator.of(dialogContext).pop(key),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.key_outlined, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SerlinkTooltip(
                                    message: key.label,
                                    child: Text(
                                      key.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    key.fingerprint,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                  if (key.socketPath case final endpoint?)
                                    SerlinkTooltip(
                                      message: endpoint,
                                      child: Text(
                                        endpoint,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  context.tokens.textSecondary,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          SerlinkTextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.cancelAction),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _importing = false);
    if (selected == null) return;
    widget.publicKeyController.text = selected.publicKey;
    if (selected.socketPath case final endpoint?) {
      widget.socketController.text = endpoint;
    }
    setState(() {
      _selectedLabel = selected.label;
      _selectedFingerprint = selected.fingerprint;
      _manualPublicKey = false;
      _error = null;
    });
  }

  Future<void> _importPublicKey() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final file = await ref.read(documentGatewayProvider).pickTextFile();
      if (!mounted || file == null) return;
      final parts = file.contents.trim().split(RegExp(r'\s+'));
      if (parts.length < 2 ||
          !(parts.first.startsWith('ssh-') ||
              parts.first.startsWith('ecdsa-') ||
              parts.first.startsWith('sk-'))) {
        throw const FormatException('Expected a public key');
      }
      base64Decode(parts[1]);
      widget.publicKeyController.text = file.contents.trim();
      setState(() {
        _selectedLabel = file.name;
        _selectedFingerprint = null;
        _manualPublicKey = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.agentPublicKeyImportFailed);
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  void _clearSelection() {
    widget.publicKeyController.clear();
    setState(() {
      _selectedLabel = null;
      _selectedFingerprint = null;
      _manualPublicKey = false;
      _error = null;
    });
  }

  Widget _keySelection(TextEditingValue value) {
    final l10n = context.l10n;
    final t = context.tokens;
    final publicKey = value.text.trim();
    final selected = publicKey.isNotEmpty;
    final comment = publicKey.split(RegExp(r'\s+')).skip(2).join(' ');
    final title = selected
        ? (_selectedLabel ??
              (comment.isEmpty ? l10n.agentPublicKeySelected : comment))
        : l10n.agentAllKeysTitle;
    final fingerprint = selected
        ? (_selectedFingerprint ?? sshAgentPublicKeyFingerprint(publicKey))
        : null;
    final subtitle = fingerprint ?? l10n.agentPublicKeyHint;
    final selectButton = SerlinkOutlinedButton.icon(
      key: const ValueKey('agent-select-key-button'),
      onPressed: _importing ? null : _selectAgentKey,
      icon: const Icon(Icons.key_outlined, size: 16),
      label: Text(
        selected ? l10n.agentChangeKeyAction : l10n.agentChooseKeyAction,
      ),
    );
    final options = SerlinkMenuButton(
      key: const ValueKey('agent-key-options-button'),
      tooltip: l10n.agentKeyOptionsTooltip,
      enabled: !_importing,
      icon: const Icon(Icons.more_horiz, size: 20),
      actions: [
        SerlinkMenuAction(
          label: l10n.agentImportPublicKeyAction,
          icon: Icons.file_open_outlined,
          onPressed: _importPublicKey,
        ),
        SerlinkMenuAction(
          label: _manualPublicKey
              ? l10n.agentHidePublicKeyInputAction
              : l10n.agentEnterPublicKeyAction,
          icon: Icons.edit_outlined,
          onPressed: () => setState(() => _manualPublicKey = !_manualPublicKey),
        ),
        if (selected)
          SerlinkMenuAction(
            label: l10n.agentUseAllKeysAction,
            icon: Icons.layers_clear_outlined,
            onPressed: _clearSelection,
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.agentAuthenticationKeyLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('agent-selected-key-summary'),
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: selected ? 12 : 4,
          ),
          decoration: BoxDecoration(
            color: t.surfaceSunken,
            borderRadius: SerlinkRadii.control,
            border: Border.all(color: t.borderSubtle),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 420;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: selected ? 36 : 20,
                        height: selected ? 36 : 20,
                        decoration: BoxDecoration(
                          color: selected
                              ? t.accentPrimary.withValues(alpha: 0.12)
                              : t.surfaceSunken,
                          borderRadius: SerlinkRadii.control,
                        ),
                        child: Icon(
                          selected ? Icons.key_rounded : Icons.layers_outlined,
                          size: 18,
                          color: selected ? t.accentPrimary : t.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SerlinkTooltip(
                              message: title,
                              child: Text(
                                title,
                                key: const ValueKey('agent-selected-key-name'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (selected) ...[
                              const SizedBox(height: 4),
                              SerlinkTooltip(
                                message: subtitle,
                                child: Text(
                                  subtitle,
                                  key: const ValueKey(
                                    'agent-selected-key-fingerprint',
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: t.textSecondary,
                                        fontFamily: fingerprint == null
                                            ? null
                                            : 'monospace',
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!compact) ...[selectButton, const SizedBox(width: 4)],
                      if (compact && !selected)
                        SerlinkIconButton(
                          key: const ValueKey('agent-select-key-button'),
                          onPressed: _importing ? null : _selectAgentKey,
                          icon: const Icon(Icons.key_outlined, size: 18),
                          tooltip: l10n.agentChooseKeyAction,
                        ),
                      options,
                    ],
                  ),
                  if (compact && selected) ...[
                    const SizedBox(height: 12),
                    selectButton,
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _endpointText(BuildContext context, String endpoint, {Key? textKey}) {
    final style = Theme.of(context).textTheme.bodySmall
        ?.copyWith(color: context.tokens.textSecondary);
    return LayoutBuilder(
      builder: (context, constraints) {
        final text = Text(
          endpoint,
          key: textKey,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        );
        final painter = TextPainter(
          text: TextSpan(text: endpoint, style: style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final truncated = painter.didExceedMaxLines;
        painter.dispose();
        return truncated
            ? SerlinkTooltip(message: endpoint, preferBelow: true, child: text)
            : text;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              l10n.agentProviderLabel,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(width: 6),
            SerlinkTooltip(
              message: widget.hardwareKey
                  ? l10n.agentHardwareKeyNote
                  : l10n.hostSshAgentNote,
              child: Icon(
                Icons.info_outline,
                size: 15,
                color: context.tokens.textSecondary,
              ),
            ),
            const Spacer(),
            SerlinkMenuButton(
              key: const ValueKey('agent-provider-options-button'),
              tooltip: l10n.agentProviderOptionsTooltip,
              enabled: !_importing,
              icon: const Icon(Icons.more_horiz, size: 20),
              actions: [
                SerlinkMenuAction(
                  label: l10n.agentRefreshProvidersAction,
                  icon: Icons.refresh,
                  onPressed: _findEndpoint,
                ),
                SerlinkMenuAction(
                  label: _customEndpoint
                      ? l10n.agentHideEndpointAction
                      : l10n.agentManualEndpointAction,
                  icon: Icons.tune,
                  onPressed: () =>
                      setState(() => _customEndpoint = !_customEndpoint),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.socketController,
          builder: (context, value, _) {
            final endpoint = value.text.trim();
            final provider = _chosenProvider?.socketPath == endpoint
                ? _chosenProvider
                : null;
            final label = endpoint.isEmpty
                ? l10n.agentChooseEndpointTitle
                : (provider?.providerHint ??
                      sshAgentProviderHint(endpoint) ??
                      (endpoint.contains('com.apple.launchd')
                          ? l10n.agentSystemTitle
                          : l10n.agentLocalTitle));
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SerlinkOutlinedButton(
                  key: const ValueKey('agent-discover-endpoint-button'),
                  onPressed: _importing ? null : _findEndpoint,
                  child: Row(
                    children: [
                      Icon(
                        Icons.key_outlined,
                        size: 17,
                        color: context.tokens.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          provider == null
                              ? label
                              : '$label · ${l10n.agentDiscoveredKeysCount(provider.identities.length)}',
                          key: const ValueKey('agent-selected-provider-name'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (_findingEndpoint)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: SerlinkLoadingIndicator(),
                        )
                      else
                        const Icon(Icons.expand_more, size: 18),
                    ],
                  ),
                ),
                if (endpoint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _endpointText(
                    context,
                    endpoint,
                    textKey: const ValueKey('agent-selected-provider-path'),
                  ),
                ],
              ],
            );
          },
        ),
        if (_customEndpoint) ...[
          const SizedBox(height: 10),
          SerlinkTextField(
            key: const ValueKey('agent-socket-field'),
            controller: widget.socketController,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l10n.agentManualEndpointAction,
              hintText: l10n.agentSocketHint,
            ),
          ),
        ],
        const SizedBox(height: 16),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.publicKeyController,
          builder: (context, value, _) => _keySelection(value),
        ),
        if (_manualPublicKey) ...[
          const SizedBox(height: 12),
          SerlinkTextField(
            key: const ValueKey('agent-public-key-field'),
            controller: widget.publicKeyController,
            autocorrect: false,
            enableSuggestions: false,
            minLines: 2,
            maxLines: 3,
            onChanged: (_) => setState(() {
              _selectedLabel = null;
              _selectedFingerprint = null;
            }),
            decoration: InputDecoration(
              labelText: l10n.agentPublicKeyLabel,
              hintText: l10n.agentPublicKeyHint,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          SerlinkAlert.danger(message: _error!, compact: true),
        ],
      ],
    );
  }
}

class _SavedCredentialFields extends StatefulWidget {
  const _SavedCredentialFields({
    required this.identityOptions,
    required this.selectedIdentityIds,
    required this.loadingOptions,
    required this.onToggleIdentity,
    required this.onEditIdentity,
    required this.onDeleteIdentity,
  });

  final List<IdentityConfig> identityOptions;
  final Set<IdentityId> selectedIdentityIds;
  final bool loadingOptions;
  final ValueChanged<IdentityId> onToggleIdentity;
  final ValueChanged<IdentityConfig> onEditIdentity;
  final ValueChanged<IdentityConfig> onDeleteIdentity;

  @override
  State<_SavedCredentialFields> createState() => _SavedCredentialFieldsState();
}

class _SavedCredentialFieldsState extends State<_SavedCredentialFields> {
  static const _pageSize = 3;
  int _page = 0;

  @override
  void didUpdateWidget(covariant _SavedCredentialFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final remaining = widget.identityOptions
        .where((identity) => !widget.selectedIdentityIds.contains(identity.id))
        .length;
    _page = math.min(_page, math.max(0, (remaining - 1) ~/ _pageSize));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final byId = {
      for (final identity in widget.identityOptions) identity.id: identity,
    };
    // Preserve the host's configured identity order; sorting is presentation
    // only and must not change the order in which SSH tries its credentials.
    final selected = [for (final id in widget.selectedIdentityIds) ?byId[id]];
    final remaining = widget.identityOptions
        .where((identity) => !widget.selectedIdentityIds.contains(identity.id))
        .toList();
    final pageCount = math.max(
      1,
      (remaining.length + _pageSize - 1) ~/ _pageSize,
    );
    final visible = remaining.skip(_page * _pageSize).take(_pageSize).toList();
    final buttonSide = Theme.of(context).platform == TargetPlatform.iOS
        ? 44.0
        : 32.0;

    Widget row(IdentityConfig identity) => _CredentialSelectionRow(
      key: ValueKey('credential-row-${identity.id.value}'),
      identity: identity,
      selected: widget.selectedIdentityIds.contains(identity.id),
      enabled: !widget.loadingOptions,
      onToggle: widget.onToggleIdentity,
      onEdit: widget.onEditIdentity,
      onDelete: widget.onDeleteIdentity,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.identityOptions.isEmpty)
          const _CredentialsEmptyState()
        else
          AnimatedOpacity(
            duration: const Duration(milliseconds: 130),
            opacity: widget.loadingOptions ? 0.54 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < selected.length; index += 1) ...[
                  if (index > 0) const SizedBox(height: 8),
                  row(selected[index]),
                ],
                if (remaining.isNotEmpty &&
                    (selected.isNotEmpty || pageCount > 1)) ...[
                  if (selected.isNotEmpty) const SizedBox(height: 12),
                  Wrap(
                    key: const ValueKey('credential-pagination'),
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        selected.isEmpty
                            ? l10n.credentialsDialogTitle
                            : l10n.hostOtherCredentialsTitle,
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: context.tokens.textSecondary),
                      ),
                      if (pageCount > 1)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              l10n.hostCredentialPage(_page + 1, pageCount),
                              key: const ValueKey('credential-page-label'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: 8),
                            SerlinkIconButton(
                              key: const ValueKey('credential-previous-page'),
                              tooltip: l10n.hostCredentialPreviousPage,
                              constraints: BoxConstraints.tightFor(
                                width: buttonSide,
                                height: buttonSide,
                              ),
                              onPressed: widget.loadingOptions || _page == 0
                                  ? null
                                  : () => setState(() {
                                      _page = math.max(0, _page - 1);
                                    }),
                              icon: const Icon(Icons.chevron_left, size: 18),
                            ),
                            SerlinkIconButton(
                              key: const ValueKey('credential-next-page'),
                              tooltip: l10n.hostCredentialNextPage,
                              constraints: BoxConstraints.tightFor(
                                width: buttonSide,
                                height: buttonSide,
                              ),
                              onPressed:
                                  widget.loadingOptions ||
                                      _page >= pageCount - 1
                                  ? null
                                  : () => setState(() {
                                      _page = math.min(
                                        pageCount - 1,
                                        _page + 1,
                                      );
                                    }),
                              icon: const Icon(Icons.chevron_right, size: 18),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                for (var index = 0; index < visible.length; index += 1) ...[
                  if (index > 0) const SizedBox(height: 8),
                  row(visible[index]),
                ],
              ],
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
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CredentialSelectionRow extends StatelessWidget {
  const _CredentialSelectionRow({
    super.key,
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
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: t.textSecondary),
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
