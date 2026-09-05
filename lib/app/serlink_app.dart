import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../features/settings/application/app_language_settings.dart';
import '../features/workspace/application/workspace_tab_controller.dart';
import '../l10n/l10n.dart';
import '../platform/app_window.dart';
import 'app_dependencies.dart';
import 'app_router.dart';
import 'app_theme.dart';

class SerlinkApp extends ConsumerWidget {
  const SerlinkApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final language = ref.watch(appLanguageProvider).value ?? AppLanguage.system;
    final protectBackground =
        ref.watch(appProtectBackgroundProvider).value ?? false;
    final capabilities = ref.watch(platformCapabilitiesProvider);
    if (capabilities.cloudKitSync) {
      ref.watch(cloudKitVaultDiscoveryControllerProvider);
      ref.watch(cloudKitEncryptedSnapshotPrefetchControllerProvider);
    }
    ref.watch(autoSyncControllerProvider);
    if (capabilities.sshConfigImport) {
      ref.watch(macOsSshConfigWritebackProvider);
    }
    // Only macOS ships the MCP server; keep mobile from instantiating the
    // controller at all.
    if (capabilities.mcpServer) {
      ref.watch(mcpServerControllerProvider);
    }

    final brightness = MediaQuery.platformBrightnessOf(context);
    final foruiTheme = switch ((capabilities.prefersTouchUi, brightness)) {
      (true, Brightness.light) => SerlinkTheme.foruiLightTouch(
        platform: capabilities.targetPlatform,
      ),
      (true, Brightness.dark) => SerlinkTheme.foruiDarkTouch(
        platform: capabilities.targetPlatform,
      ),
      (false, Brightness.light) => SerlinkTheme.foruiLight(
        platform: capabilities.targetPlatform,
      ),
      (false, Brightness.dark) => SerlinkTheme.foruiDark(
        platform: capabilities.targetPlatform,
      ),
    };

    return MaterialApp.router(
      title: 'Serlink',
      debugShowCheckedModeBanner: false,
      theme: SerlinkTheme.light(platform: capabilities.targetPlatform),
      darkTheme: SerlinkTheme.dark(platform: capabilities.targetPlatform),
      themeMode: ThemeMode.system,
      locale: language.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...FLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
      builder: (context, child) {
        final body = child ?? const SizedBox.shrink();
        final themedBody = FTheme(
          data: foruiTheme,
          platform: capabilities.foruiPlatformVariant,
          child: FToaster(
            child: FTooltipGroup(
              child: _LifecycleOverlay(
                protectBackground: protectBackground,
                child: body,
              ),
            ),
          ),
        );
        if (!AppWindow.needsFlutterSurfaceClip) {
          return themedBody;
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            DesktopWindowMetrics.cornerRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: themedBody,
        );
      },
    );
  }
}

class _LifecycleOverlay extends ConsumerStatefulWidget {
  const _LifecycleOverlay({
    required this.protectBackground,
    required this.child,
  });

  final bool protectBackground;
  final Widget child;

  @override
  ConsumerState<_LifecycleOverlay> createState() => _LifecycleOverlayState();
}

class _LifecycleOverlayState extends ConsumerState<_LifecycleOverlay>
    with WidgetsBindingObserver {
  var _hidden = false;
  var _wasBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = switch (state) {
      AppLifecycleState.inactive ||
      AppLifecycleState.paused ||
      AppLifecycleState.hidden => true,
      AppLifecycleState.resumed || AppLifecycleState.detached => false,
    };
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasBackgrounded = true;
    }
    if (state == AppLifecycleState.resumed) {
      final capabilities = ref.read(platformCapabilitiesProvider);
      if (capabilities.cloudKitSync) {
        ref
            .read(cloudKitVaultDiscoveryControllerProvider.notifier)
            .refreshNow();
        ref
            .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
            .refreshNow();
      }
      ref
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);
      if (capabilities.sshConfigImport) {
        ref.read(macOsSshConfigWritebackProvider.notifier).requestReconcile();
      }
      if (_wasBackgrounded) {
        _wasBackgrounded = false;
        // SSH sockets may have died silently while the app was suspended
        // (NAT expiry, network switch); dartssh2's keepalive never times
        // out, so probe the sessions instead of waiting for shell.done.
        unawaited(
          ref
              .read(workspaceTabControllerProvider.notifier)
              .probeRemoteSessions(),
        );
      }
    }
    if (_hidden != hidden && mounted) {
      setState(() {
        _hidden = hidden;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.protectBackground) {
      return widget.child;
    }
    final colors = Theme.of(context).colorScheme;
    // Keep the child mounted and cover it instead of replacing it, so a
    // brief inactive blip (app switcher, Control Center) does not dispose
    // terminal state, scroll positions, or in-progress text fields.
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_hidden)
          Positioned.fill(
            child: ColoredBox(
              color: colors.surface,
              child: Center(
                child: Icon(
                  Icons.lock_outline,
                  size: 42,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
