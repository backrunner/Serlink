part of 'workspace_smoke_test.dart';

void _credentialPaginationTests() {
  testWidgets('host credentials stay pinned across pages, deletion and save', (
    tester,
  ) async {
    final identities = _credentialPaginationIdentities();
    final hosts = _MemoryHostRepository();
    await hosts.save(
      HostConfig.fromJson({
        ..._hostConfig(
          id: 'credential-host',
          displayName: 'Credential Host',
          hostname: 'credentials.internal',
          createdAt: DateTime.utc(2026),
        ).toJson(),
        'identityIds': ['credential-09', 'credential-07'],
      }),
    );
    await _pumpLockedVaultApp(
      tester,
      hostRepository: hosts,
      identityRepository: identities,
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    await tester.pumpAndSettle();
    await _openHostContextMenu(tester, 'Credential Host');
    await tester.tap(find.text('Edit host'));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Credential 09')).dy,
      lessThan(tester.getTopLeft(find.text('Credential 07')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Credential 07')).dy,
      lessThan(tester.getTopLeft(find.text('Credential 00')).dy),
    );
    expect(find.text('Credential 03'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);
    expect(
      tester
          .widget<SerlinkIconButton>(
            find.byKey(const ValueKey('credential-previous-page')),
          )
          .onPressed,
      isNull,
    );

    await _changeCredentialPage(tester, next: true);
    expect(find.text('Credential 00'), findsNothing);
    expect(find.text('Credential 09'), findsOneWidget);
    expect(find.text('Credential 07'), findsOneWidget);
    expect(find.text('Credential 04'), findsOneWidget);
    await tester.ensureVisible(find.text('Credential 04'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Credential 04'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Credential 04')).dy,
      lessThan(tester.getTopLeft(find.text('Credential 03')).dy),
    );

    await _changeCredentialPage(tester, next: false);
    expect(find.text('Credential 04'), findsOneWidget);
    expect(find.text('Credential 00'), findsOneWidget);
    await _changeCredentialPage(tester, next: true);
    await _changeCredentialPage(tester, next: true);
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.ensureVisible(find.text('Credential 08'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Credential 08'),
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete credential'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SerlinkFilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await identities.read(IdentityId('credential-08')), isNull);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(
      tester
          .widget<SerlinkIconButton>(
            find.byKey(const ValueKey('credential-next-page')),
          )
          .onPressed,
      isNull,
    );
    expect(find.text('Credential 09'), findsOneWidget);
    expect(find.text('Credential 07'), findsOneWidget);
    expect(find.text('Credential 04'), findsOneWidget);

    // Multiple pointer taps can arrive before the next frame rebuilds the
    // disabled state. Keep the page within bounds during that interval.
    final previousPage = find.byKey(const ValueKey('credential-previous-page'));
    await tester.ensureVisible(previousPage);
    await tester.pumpAndSettle();
    await tester.tap(previousPage);
    await tester.tap(previousPage);
    await tester.tap(previousPage);
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('host-save-button')));
    await tester.pumpAndSettle();
    expect(hosts.hosts.single.identityIds.map((id) => id.value), [
      'credential-09',
      'credential-07',
      'credential-04',
    ]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile credential pages fit enlarged text and retain selections',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpLockedVaultApp(
        tester,
        identityRepository: _credentialPaginationIdentities(),
        capabilities: const PlatformCapabilities(
          operatingSystem: 'ios',
          targetPlatform: TargetPlatform.iOS,
        ),
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      tester.platformDispatcher.textScaleFactorTestValue = 1.4;
      await _tapAddHost(tester);
      await tester.ensureVisible(find.text('Saved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Saved'));
      await tester.pumpAndSettle();
      await _changeCredentialPage(tester, next: true);
      await tester.ensureVisible(find.text('Credential 03'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Credential 03'));
      await tester.pumpAndSettle();
      await _changeCredentialPage(tester, next: false);
      expect(find.text('Credential 03'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Credential 03')).dy,
        lessThan(tester.getTopLeft(find.text('Credential 00')).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

_MemoryIdentityRepository _credentialPaginationIdentities() =>
    _MemoryIdentityRepository([
      for (var index = 0; index < 10; index += 1)
        IdentityConfig(
          id: IdentityId('credential-${index.toString().padLeft(2, '0')}'),
          displayName: 'Credential ${index.toString().padLeft(2, '0')}',
          kind: IdentityKind.password,
          usernameHint: 'deploy',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        ),
    ]);

Future<void> _changeCredentialPage(
  WidgetTester tester, {
  required bool next,
}) async {
  final button = find.byKey(
    ValueKey(next ? 'credential-next-page' : 'credential-previous-page'),
  );
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}
