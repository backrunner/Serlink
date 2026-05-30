part of '../workspace_screen.dart';

class _LocalForwardDraft {
  const _LocalForwardDraft({
    required this.localPort,
    required this.remoteHost,
    required this.remotePort,
  });

  final int localPort;
  final String remoteHost;
  final int remotePort;
}

class _RemoteForwardDraft {
  const _RemoteForwardDraft({
    required this.bindHost,
    required this.bindPort,
    required this.localHost,
    required this.localPort,
  });

  final String bindHost;
  final int bindPort;
  final String localHost;
  final int localPort;
}

class _DynamicForwardDraft {
  const _DynamicForwardDraft({required this.bindHost, required this.bindPort});

  final String bindHost;
  final int bindPort;
}

enum _ForwardDialogActionKind {
  startLocal,
  stopLocal,
  startRemote,
  stopRemote,
  startDynamic,
  stopDynamic,
}

class _ForwardDialogAction {
  const _ForwardDialogAction._({
    required this.kind,
    this.localDraft,
    this.remoteDraft,
    this.dynamicDraft,
  });

  const _ForwardDialogAction.startLocal(_LocalForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startLocal, localDraft: draft);

  const _ForwardDialogAction.stopLocal()
    : this._(kind: _ForwardDialogActionKind.stopLocal);

  const _ForwardDialogAction.startRemote(_RemoteForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startRemote, remoteDraft: draft);

  const _ForwardDialogAction.stopRemote()
    : this._(kind: _ForwardDialogActionKind.stopRemote);

  const _ForwardDialogAction.startDynamic(_DynamicForwardDraft draft)
    : this._(kind: _ForwardDialogActionKind.startDynamic, dynamicDraft: draft);

  const _ForwardDialogAction.stopDynamic()
    : this._(kind: _ForwardDialogActionKind.stopDynamic);

  final _ForwardDialogActionKind kind;
  final _LocalForwardDraft? localDraft;
  final _RemoteForwardDraft? remoteDraft;
  final _DynamicForwardDraft? dynamicDraft;
}

class _ForwardingDialog extends StatefulWidget {
  const _ForwardingDialog({
    required this.activeLocalForward,
    required this.activeRemoteForward,
    required this.activeDynamicForward,
  });

  final _LocalForwardDraft? activeLocalForward;
  final _RemoteForwardDraft? activeRemoteForward;
  final _DynamicForwardDraft? activeDynamicForward;

  @override
  State<_ForwardingDialog> createState() => _ForwardingDialogState();
}

class _ForwardingDialogState extends State<_ForwardingDialog> {
  final TextEditingController _localPortController = TextEditingController();
  final TextEditingController _remoteHostController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _remotePortController = TextEditingController();
  final TextEditingController _remoteBindHostController = TextEditingController(
    text: '127.0.0.1',
  );
  final TextEditingController _remoteBindPortController =
      TextEditingController();
  final TextEditingController _remoteLocalHostController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _remoteLocalPortController =
      TextEditingController();
  final TextEditingController _dynamicBindHostController =
      TextEditingController(text: '127.0.0.1');
  final TextEditingController _dynamicBindPortController =
      TextEditingController();
  String? _localErrorMessage;
  String? _remoteErrorMessage;
  String? _dynamicErrorMessage;

  @override
  void initState() {
    super.initState();
    final local = widget.activeLocalForward;
    if (local != null) {
      _localPortController.text = local.localPort.toString();
      _remoteHostController.text = local.remoteHost;
      _remotePortController.text = local.remotePort.toString();
    }
    final remote = widget.activeRemoteForward;
    if (remote != null) {
      _remoteBindHostController.text = remote.bindHost;
      _remoteBindPortController.text = remote.bindPort.toString();
      _remoteLocalHostController.text = remote.localHost;
      _remoteLocalPortController.text = remote.localPort.toString();
    }
    final dynamic = widget.activeDynamicForward;
    if (dynamic != null) {
      _dynamicBindHostController.text = dynamic.bindHost;
      _dynamicBindPortController.text = dynamic.bindPort.toString();
    }
  }

  @override
  void dispose() {
    _localPortController.dispose();
    _remoteHostController.dispose();
    _remotePortController.dispose();
    _remoteBindHostController.dispose();
    _remoteBindPortController.dispose();
    _remoteLocalHostController.dispose();
    _remoteLocalPortController.dispose();
    _dynamicBindHostController.dispose();
    _dynamicBindPortController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Port Forwarding'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ForwardSection(
                title: 'Local',
                subtitle: widget.activeLocalForward == null
                    ? 'Expose a remote service on this device.'
                    : '127.0.0.1:${widget.activeLocalForward!.localPort}'
                          ' -> ${widget.activeLocalForward!.remoteHost}'
                          ':${widget.activeLocalForward!.remotePort}',
                actionLabel: widget.activeLocalForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeLocalForward != null,
                onPressed: widget.activeLocalForward == null
                    ? _submitLocal
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopLocal()),
                child: widget.activeLocalForward != null
                    ? null
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'local-forward-local-port-field',
                                  ),
                                  controller: _localPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'local-forward-remote-host-field',
                                  ),
                                  controller: _remoteHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Remote host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            key: const ValueKey(
                              'local-forward-remote-port-field',
                            ),
                            controller: _remotePortController,
                            decoration: const InputDecoration(
                              labelText: 'Remote port',
                            ),
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _submitLocal(),
                          ),
                          if (_localErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _localErrorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _ForwardSection(
                title: 'Remote',
                subtitle: widget.activeRemoteForward == null
                    ? 'Expose a local service on the remote host.'
                    : '${widget.activeRemoteForward!.bindHost}'
                          ':${widget.activeRemoteForward!.bindPort}'
                          ' -> ${widget.activeRemoteForward!.localHost}'
                          ':${widget.activeRemoteForward!.localPort}',
                actionLabel: widget.activeRemoteForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeRemoteForward != null,
                onPressed: widget.activeRemoteForward == null
                    ? _submitRemote
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopRemote()),
                child: widget.activeRemoteForward != null
                    ? null
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-bind-host-field',
                                  ),
                                  controller: _remoteBindHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bind host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-bind-port-field',
                                  ),
                                  controller: _remoteBindPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bind port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-local-host-field',
                                  ),
                                  controller: _remoteLocalHostController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local host',
                                  ),
                                  textInputAction: TextInputAction.next,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  key: const ValueKey(
                                    'remote-forward-local-port-field',
                                  ),
                                  controller: _remoteLocalPortController,
                                  decoration: const InputDecoration(
                                    labelText: 'Local port',
                                  ),
                                  keyboardType: TextInputType.number,
                                  onSubmitted: (_) => _submitRemote(),
                                ),
                              ),
                            ],
                          ),
                          if (_remoteErrorMessage != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _remoteErrorMessage!,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              _ForwardSection(
                title: 'SOCKS Proxy',
                subtitle: widget.activeDynamicForward == null
                    ? 'Start a local dynamic proxy for this SSH session.'
                    : '${widget.activeDynamicForward!.bindHost}'
                          ':${widget.activeDynamicForward!.bindPort}',
                actionLabel: widget.activeDynamicForward == null
                    ? 'Start'
                    : 'Stop',
                destructive: widget.activeDynamicForward != null,
                onPressed: widget.activeDynamicForward == null
                    ? _submitDynamic
                    : () => Navigator.of(
                        context,
                      ).pop(const _ForwardDialogAction.stopDynamic()),
                child: widget.activeDynamicForward != null
                    ? null
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              key: const ValueKey(
                                'dynamic-forward-bind-host-field',
                              ),
                              controller: _dynamicBindHostController,
                              decoration: const InputDecoration(
                                labelText: 'Bind host',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              key: const ValueKey(
                                'dynamic-forward-bind-port-field',
                              ),
                              controller: _dynamicBindPortController,
                              decoration: const InputDecoration(
                                labelText: 'Bind port',
                              ),
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _submitDynamic(),
                            ),
                          ),
                        ],
                      ),
              ),
              if (_dynamicErrorMessage != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _dynamicErrorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  void _submitLocal() {
    final localPort = _parsePort(_localPortController.text);
    final remotePort = _parsePort(_remotePortController.text);
    final remoteHost = _remoteHostController.text.trim();
    if (localPort == null || remotePort == null || remoteHost.isEmpty) {
      setState(() {
        _localErrorMessage =
            'Ports must be 1-65535 and remote host is required.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startLocal(
        _LocalForwardDraft(
          localPort: localPort,
          remoteHost: remoteHost,
          remotePort: remotePort,
        ),
      ),
    );
  }

  void _submitRemote() {
    final bindHost = _remoteBindHostController.text.trim();
    final bindPort = _parsePort(_remoteBindPortController.text);
    final localHost = _remoteLocalHostController.text.trim();
    final localPort = _parsePort(_remoteLocalPortController.text);
    if (bindHost.isEmpty ||
        localHost.isEmpty ||
        bindPort == null ||
        localPort == null) {
      setState(() {
        _remoteErrorMessage = 'Bind host, local host, and ports must be valid.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startRemote(
        _RemoteForwardDraft(
          bindHost: bindHost,
          bindPort: bindPort,
          localHost: localHost,
          localPort: localPort,
        ),
      ),
    );
  }

  void _submitDynamic() {
    final bindHost = _dynamicBindHostController.text.trim();
    final bindPort = _parsePort(_dynamicBindPortController.text);
    if (bindHost.isEmpty || bindPort == null) {
      setState(() {
        _dynamicErrorMessage = 'Bind host and port must be valid.';
      });
      return;
    }
    Navigator.of(context).pop(
      _ForwardDialogAction.startDynamic(
        _DynamicForwardDraft(bindHost: bindHost, bindPort: bindPort),
      ),
    );
  }
}

class _ForwardSection extends StatelessWidget {
  const _ForwardSection({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.destructive,
    required this.onPressed,
    this.child,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final bool destructive;
  final VoidCallback onPressed;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            FilledButton.tonal(
              onPressed: onPressed,
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.errorContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onErrorContainer,
                    )
                  : null,
              child: Text(actionLabel),
            ),
          ],
        ),
        if (child != null) ...[const SizedBox(height: 12), child!],
      ],
    );
  }
}

int? _parsePort(String value) {
  final port = int.tryParse(value.trim());
  if (port == null || port < 1 || port > 65535) {
    return null;
  }
  return port;
}
