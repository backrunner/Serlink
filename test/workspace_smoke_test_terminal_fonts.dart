part of 'workspace_smoke_test.dart';

void _terminalFontTests() {
  for (final mobile in [false, true]) {
    for (final language in [
      AppLanguage.english,
      AppLanguage.simplifiedChinese,
      AppLanguage.japanese,
    ]) {
      testWidgets(
        'terminal fonts ${mobile ? 'mobile' : 'desktop'} ${language.name}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = mobile
              ? const Size(375, 812)
              : const Size(1280, 800);
          tester.platformDispatcher.textScaleFactorTestValue = 1.3;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final host = _hostConfig(
            id: 'font-review',
            displayName: 'Font review',
            hostname: 'font.example.test',
            createdAt: DateTime.utc(2026),
          );
          final hosts = _MemoryHostRepository()..hosts.add(host);
          await _pumpLockedVaultApp(
            tester,
            capabilities: PlatformCapabilities(
              operatingSystem: mobile ? 'ios' : 'macos',
              targetPlatform: mobile
                  ? TargetPlatform.iOS
                  : TargetPlatform.macOS,
            ),
            hostRepository: hosts,
            connectionProfileResolver: StaticConnectionProfileResolver({
              host.id: StaticConnectionProfile(
                hostId: host.id,
                hostname: host.hostname,
                port: 22,
                username: host.username,
                authMethods: [staticPasswordAuth('fixture-only')],
              ),
            }),
            languageRepository: _FontReviewLanguageRepository(language),
            fontDiscovery: const TerminalFontDiscovery(fontDirectories: []),
          );
          await _submitVaultPassphrase(tester, 'correct horse battery staple');
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SerlinkApp)),
          );
          final controller = container.read(
            workspaceTabControllerProvider.notifier,
          );
          unawaited(controller.openTerminal(host.toSummary()));
          await _pumpUntil(
            tester,
            () =>
                controller.state.activeTab?.lifecycle ==
                SessionLifecycleState.connected,
          );
          await tester.pumpAndSettle();
          final l10n = lookupSerlinkLocalizations(language);

          Future<void> openSettings() async {
            final overflow = find.byKey(
              const ValueKey('terminal-toolbar-overflow-button'),
            );
            if (overflow.evaluate().isNotEmpty) {
              await tester.tap(overflow);
              await tester.pumpAndSettle();
            }
            await tester.tap(
              find.byKey(const ValueKey('terminal-settings-button')),
            );
            await tester.pumpAndSettle();
          }

          Finder pickerFor(String family, {bool hostProfile = false}) =>
              find.byKey(ValueKey('terminal-font-family-$family-$hostProfile'));
          await openSettings();
          final picker = pickerFor(bundledTerminalFontFamily);
          await tester.ensureVisible(picker);
          await tester.pumpAndSettle();
          expect(
            tester.widget<SerlinkSelect<String>>(picker).items.first.label,
            contains(l10n.terminalBundledFont),
          );
          expect(find.text(l10n.terminalNerdFontReady), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Search the full family name and select the bundled font from the menu.
          await tester.tap(picker);
          await tester.pumpAndSettle();
          final search = find.descendant(
            of: picker,
            matching: find.byType(EditableText),
          );
          await tester.enterText(search.last, 'JetBrainsMono Nerd Font Mono');
          await tester.pumpAndSettle();
          final bundledLabel = tester
              .widget<SerlinkSelect<String>>(picker)
              .items
              .first
              .label;
          await tester.tap(find.text(bundledLabel).last);
          await tester.pumpAndSettle();

          final custom = find.byWidgetPredicate(
            (widget) =>
                widget is SerlinkTextFormField &&
                widget.decoration?.hintText == l10n.terminalCustomFamilyHint,
          );
          await tester.ensureVisible(custom);
          final customFamily = mobile ? 'Menlo' : 'Hack Nerd Font Mono';
          await tester.enterText(custom, '  $customFamily  ');
          if (mobile) {
            tester.view.viewInsets = const FakeViewPadding(bottom: 300);
            await tester.pumpAndSettle();
            await tester.ensureVisible(custom);
            await tester.pumpAndSettle();
            expect(tester.getRect(custom).bottom, lessThanOrEqualTo(512));
          }
          await tester.testTextInput.receiveAction(TextInputAction.done);
          tester.view.resetViewInsets();
          await tester.pumpAndSettle();
          expect(
            container.read(terminalDisplaySettingsProvider).value!.fontFamily,
            customFamily,
          );
          final preview = tester.widget<Text>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.textSpan?.toPlainText().startsWith('serlink') ??
                      false),
            ),
          );
          final spans = (preview.textSpan! as TextSpan).children!
              .cast<TextSpan>();
          for (final icon in spans.where((span) => span.text == '\u{e0b0}')) {
            expect(
              icon.style!.fontFamily,
              mobile ? bundledTerminalFontFamily : customFamily,
            );
          }
          expect(spans.first.style!.fontFamily, customFamily);
          await tester.tap(find.text(l10n.doneAction));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<TerminalView>(find.byType(TerminalView).first)
                .textStyle
                .fontFamily,
            customFamily,
          );

          // Reopen, create a host override, then change it without changing global settings.
          await openSettings();
          expect(pickerFor(customFamily), findsOneWidget);
          await tester.tap(find.text(l10n.terminalSaveForHostAction));
          await tester.pumpAndSettle();
          final hostPicker = pickerFor(customFamily, hostProfile: true);
          await tester.ensureVisible(hostPicker);
          await tester.pumpAndSettle();
          await tester.tap(hostPicker);
          await tester.pumpAndSettle();
          await tester.enterText(
            find
                .descendant(of: hostPicker, matching: find.byType(EditableText))
                .last,
            'JetBrainsMono Nerd Font Mono',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(bundledLabel).last);
          await tester.pumpAndSettle();
          final content =
              controller.state.activeTab!.content as TerminalTabContent;
          expect(
            content.primaryPane.displaySettings!.fontFamily,
            bundledTerminalFontFamily,
          );
          expect(
            container.read(terminalDisplaySettingsProvider).value!.fontFamily,
            customFamily,
          );
          await tester.tap(find.text(l10n.terminalUseGlobalAction));
          await tester.pumpAndSettle();
          expect(pickerFor(customFamily), findsOneWidget);
          await tester.tap(find.text(l10n.doneAction));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

class _FontReviewLanguageRepository implements AppLanguageSettingsRepository {
  _FontReviewLanguageRepository(this.language);
  AppLanguage language;
  @override
  Future<AppLanguage> read() async => language;
  @override
  Future<void> save(AppLanguage value) async {
    language = value;
  }
}
