import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_dependencies.dart';
import '../../app/serlink_app.dart';
import '../../design_system/design_system.dart';
import '../../l10n/l10n.dart';
import '../../platform/platform_capabilities.dart';
import '../settings/application/app_language_settings.dart';
import 'demo_workspace.dart';

/// A low-profile, documented entry available to everyone, including App Review.
class DemoEntry extends ConsumerWidget {
  const DemoEntry({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(platformCapabilitiesProvider);
    if (capabilities.isDemo) return child;
    return GestureDetector(
      key: const ValueKey('offline-demo-entry'),
      behavior: HitTestBehavior.opaque,
      onLongPress: () {
        final language =
            ref.read(appLanguageProvider).value ?? AppLanguage.system;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _DemoWorkspacePage(
              capabilities: capabilities,
              language: language,
            ),
            fullscreenDialog: true,
          ),
        );
      },
      child: child,
    );
  }
}

class _DemoWorkspacePage extends StatefulWidget {
  const _DemoWorkspacePage({
    required this.capabilities,
    required this.language,
  });
  final PlatformCapabilities capabilities;
  final AppLanguage language;
  @override
  State<_DemoWorkspacePage> createState() => _DemoWorkspacePageState();
}

class _DemoWorkspacePageState extends State<_DemoWorkspacePage> {
  late Future<DemoWorkspace> _future;
  DemoWorkspace? _workspace;
  var _generation = 0;
  @override
  void initState() {
    super.initState();
    _future = _create();
  }

  Future<DemoWorkspace> _create() async {
    final generation = ++_generation;
    final workspace = await DemoWorkspace.create(
      capabilities: widget.capabilities,
      language: widget.language,
    );
    if (!mounted || generation != _generation) {
      await workspace.dispose();
      throw StateError('Demo session ended');
    }
    _workspace = workspace;
    return workspace;
  }

  Future<void> _reset() async {
    final previous = _workspace;
    _workspace = null;
    setState(() {
      _future = _create();
    });
    await WidgetsBinding.instance.endOfFrame;
    await previous?.dispose();
  }

  @override
  void dispose() {
    _generation++;
    final workspace = _workspace;
    if (workspace != null) unawaited(workspace.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DemoWorkspace>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            body: Column(
              children: [
                _DemoToolbar(
                  onReset: _reset,
                  onExit: () => Navigator.of(this.context).pop(),
                ),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Column(
              children: [
                _DemoToolbar(
                  onReset: _reset,
                  onExit: () => Navigator.of(this.context).pop(),
                ),
                Expanded(
                  child: Center(child: Text(context.l10n.demoLoadFailed)),
                ),
              ],
            ),
          );
        }
        final workspace = snapshot.requireData;
        return UncontrolledProviderScope(
          key: ObjectKey(workspace),
          container: workspace.container,
          child: SerlinkApp(
            workspaceBuilder: (context, child) => Column(
              children: [
                Expanded(child: child),
                // Navigator's BlockSemantics hides earlier siblings. Paint
                // the persistent demo controls after the routed workspace.
                _DemoToolbar(
                  onReset: _reset,
                  onExit: () => Navigator.of(this.context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DemoToolbar extends StatelessWidget {
  const _DemoToolbar({required this.onReset, required this.onExit});
  final VoidCallback onReset;
  final VoidCallback onExit;
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final header = Row(
                children: [
                  const Icon(Icons.science_outlined, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.demoBanner,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              );
              final actions = [
                TextButton(
                  key: const ValueKey('offline-demo-guide'),
                  onPressed: () => showSerlinkDialog<void>(
                    context: context,
                    builder: (dialogContext) => SerlinkDialog(
                      title: Text(l10n.demoGuideTitle),
                      content: SerlinkScrollView(child: Text(l10n.demoGuide)),
                      actions: [
                        SerlinkTextButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          child: Text(l10n.closeAction),
                        ),
                      ],
                    ),
                  ),
                  child: Text(l10n.demoGuideTitle),
                ),
                TextButton(
                  key: const ValueKey('offline-demo-reset'),
                  onPressed: onReset,
                  child: Text(l10n.demoReset),
                ),
                TextButton(
                  key: const ValueKey('offline-demo-exit'),
                  onPressed: onExit,
                  child: Text(l10n.demoExit),
                ),
              ];
              if (constraints.maxWidth < 640) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    header,
                    Wrap(alignment: WrapAlignment.end, children: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: header),
                  ...actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
