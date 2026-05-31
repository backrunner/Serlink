import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../features/settings/application/app_language_settings.dart';
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
    ref.watch(autoSyncControllerProvider);

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
          data: SerlinkTheme.foruiDark(),
          platform: FPlatformVariant.macOS,
          child: FToaster(child: FTooltipGroup(child: body)),
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
