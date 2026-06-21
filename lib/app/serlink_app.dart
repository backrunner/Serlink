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
    final capabilities = ref.watch(platformCapabilitiesProvider);
    ref.watch(cloudKitVaultDiscoveryControllerProvider);
    ref.watch(cloudKitEncryptedSnapshotPrefetchControllerProvider);
    ref.watch(autoSyncControllerProvider);

    final foruiTheme = capabilities.prefersTouchUi
        ? SerlinkTheme.foruiDarkTouch()
        : SerlinkTheme.foruiDark();

    return MaterialApp.router(
      title: 'Serlink',
      debugShowCheckedModeBanner: false,
      theme: SerlinkTheme.light(),
      darkTheme: SerlinkTheme.dark(),
      themeMode: ThemeMode.dark,
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
            child: FTooltipGroup(child: _LifecycleOverlay(child: body)),
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
  const _LifecycleOverlay({required this.child});

  final Widget child;

  @override
  ConsumerState<_LifecycleOverlay> createState() => _LifecycleOverlayState();
}

class _LifecycleOverlayState extends ConsumerState<_LifecycleOverlay>
    with WidgetsBindingObserver {
  var _hidden = false;
  var _suspendedForBackground = false;

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
    if (hidden && !_suspendedForBackground) {
      final capabilities = ref.read(platformCapabilitiesProvider);
      if (capabilities.suspendSessionsOnBackground) {
        _suspendedForBackground = true;
        ref
            .read(workspaceTabControllerProvider.notifier)
            .suspendForBackground();
      }
    } else if (!hidden) {
      _suspendedForBackground = false;
      ref.read(cloudKitVaultDiscoveryControllerProvider.notifier).refreshNow();
      ref
          .read(cloudKitEncryptedSnapshotPrefetchControllerProvider.notifier)
          .refreshNow();
      ref
          .read(autoSyncControllerProvider.notifier)
          .requestSync(delay: Duration.zero);
    }
    if (_hidden != hidden && mounted) {
      setState(() {
        _hidden = hidden;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hidden) {
      return widget.child;
    }
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surface,
      child: Center(
        child: Icon(
          Icons.lock_outline,
          size: 42,
          color: colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
