import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/app/app_dependencies.dart';
import 'package:serlink/features/demo/demo_entry.dart';
import 'package:serlink/features/settings/application/app_language_settings.dart';
import 'package:serlink/l10n/l10n.dart';
import 'package:serlink/platform/platform_capabilities.dart';

void main() {
  for (final mobile in [false, true]) {
    testWidgets(
      '${mobile ? 'mobile' : 'desktop'} demo opens populated pages, resets and exits without parent data',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = mobile
            ? const Size(375, 812)
            : const Size(1000, 760);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              platformCapabilitiesProvider.overrideWithValue(
                PlatformCapabilities(
                  operatingSystem: mobile ? 'ios' : 'windows',
                  targetPlatform: mobile
                      ? TargetPlatform.iOS
                      : TargetPlatform.windows,
                ),
              ),
              appLanguageSettingsRepositoryProvider.overrideWithValue(
                _Language(),
              ),
              serlinkDatabaseProvider.overrideWith(
                (_) => throw StateError('Parent database must stay untouched'),
              ),
              secretStoreProvider.overrideWith(
                (_) => throw StateError('Parent secrets must stay untouched'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                ...GlobalMaterialLocalizations.delegates,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: Center(child: DemoEntry(child: Text('Preview entry'))),
              ),
            ),
          ),
        );
        await tester.longPress(
          find.byKey(const ValueKey('offline-demo-entry')),
        );
        await _waitForDemo(tester);
        expect(find.text('Review Sandbox'), findsWidgets);
        expect(
          find.text('Demo mode: simulated terminal and remote files'),
          findsOneWidget,
        );
        await tester.tap(find.text('Snippets'));
        await tester.pumpAndSettle();
        expect(find.text('Explore the demo'), findsOneWidget);
        await tester.tap(find.text('Transfers'));
        await tester.pumpAndSettle();
        expect(find.textContaining('README.txt'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('offline-demo-reset')));
        await _waitForDemo(tester);
        expect(find.text('Review Sandbox'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('offline-demo-exit')));
        await tester.pumpAndSettle();
        expect(find.text('Preview entry'), findsOneWidget);
        expect(find.text('Review Sandbox'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _waitForDemo(WidgetTester tester) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    if (find.text('Review Sandbox').evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
  }
  fail('The offline demo did not load');
}

class _Language implements AppLanguageSettingsRepository {
  @override
  Future<AppLanguage> read() async => AppLanguage.english;
  @override
  Future<void> save(AppLanguage language) async {}
}
