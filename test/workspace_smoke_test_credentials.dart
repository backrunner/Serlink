part of 'workspace_smoke_test.dart';

void _credentialPaginationTests() {
  for (final count in [0, 1, 2]) {
    testWidgets(
      'agent endpoint discovery handles $count results without typing paths',
      (tester) async {
        final identities = _MemoryIdentityRepository(const []);
        final hosts = _MemoryHostRepository();
        var requests = 0;
        await _pumpLockedVaultApp(
          tester,
          hostRepository: hosts,
          identityRepository: identities,
          agentEndpointLoader: () async {
            requests++;
            return [
              for (var index = 0; index < count; index++)
                DiscoveredSshAgent(
                  socketPath: '/found/agent-$index.sock',
                  identities: [
                    for (var key = 0; key < index; key++)
                      SshAgentIdentity(
                        publicKeyBlob: Uint8List(0),
                        comment: 'Fixture key $key',
                      ),
                  ],
                  isSystem: index == 0,
                ),
            ];
          },
        );
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        await _tapAddHost(tester);
        await tester.enterText(
          find.byKey(const ValueKey('host-hostname-field')),
          'discovery.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('host-username-field')),
          'root',
        );
        await tester.ensureVisible(find.text('Agent'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agent'));
        await tester.pumpAndSettle();
        await _showAgentCustomEndpoint(tester);
        final field = find.byKey(const ValueKey('agent-socket-field'));
        await tester.enterText(field, '/original.sock');
        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Enter public key manually'));
        await tester.pumpAndSettle();
        final originalKey = tester
            .widget<SerlinkTextField>(
              find.byKey(const ValueKey('agent-public-key-field')),
            )
            .controller!;
        await tester.enterText(
          find.byKey(const ValueKey('agent-public-key-field')),
          'ssh-ed25519 AAAA original',
        );
        Future<void> discover() async {
          final button = find.byKey(
            const ValueKey('agent-discover-endpoint-button'),
          );
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
        }

        await discover();
        expect(requests, 1);
        expect(find.text('Choose SSH agent'), findsOneWidget);
        if (count == 2) {
          expect(
            tester.getTopLeft(find.text('/found/agent-1.sock')).dy,
            lessThan(tester.getTopLeft(find.text('/found/agent-0.sock')).dy),
          );
        }
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('agent-selected-provider-path')),
              )
              .data,
          '/original.sock',
        );
        if (count == 0) {
          expect(
            find.textContaining('No SSH agent was found.'),
            findsOneWidget,
          );
          await tester.tap(
            find.widgetWithText(SerlinkTextButton, 'Cancel').last,
          );
          await tester.pumpAndSettle();
        } else {
          // Even a single result needs an explicit user selection.
          await tester.tap(
            find.widgetWithText(SerlinkTextButton, 'Cancel').last,
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('agent-selected-provider-path')),
                )
                .data,
            '/original.sock',
          );
          await discover();
          if (count == 1) {
            await tester.tap(
              find.byKey(const ValueKey('agent-refresh-providers-button')),
            );
            await tester.pumpAndSettle();
            expect(requests, 3);
          }
          expect(originalKey.text, 'ssh-ed25519 AAAA original');
          final selected = '/found/agent-${count == 1 ? 0 : 1}.sock';
          await tester.tap(find.text(selected));
          await tester.pumpAndSettle();
          expect(originalKey.text, isEmpty);
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('agent-selected-provider-path')),
                )
                .data,
            selected,
          );
          expect(
            find.byKey(const ValueKey('agent-socket-field')),
            findsNothing,
          );
          await tester.tap(find.byKey(const ValueKey('host-save-button')));
          await tester.pumpAndSettle();
          expect((await identities.list()).single.agent?.socketPath, selected);
          expect((await identities.list()).single.secretRecordId, isNull);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final width in [800.0, 1200.0]) {
    testWidgets(
      'saved agent key dropdown aligns fields and retains secondary actions at width $width',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1200, 900);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        const label =
            'Production signing key with a very long descriptive name';
        const publicKey = 'ssh-ed25519 YWJj $label';
        const fingerprint =
            'SHA256:ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0';
        final identity = IdentityConfig(
          id: IdentityId('agent-key'),
          displayName: 'Agent credential',
          kind: IdentityKind.sshAgent,
          agent: const IdentityAgentConfig(
            socketPath: '/agents/provider.sock',
            publicKey: publicKey,
          ),
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.utc(2026),
        );
        final identities = _MemoryIdentityRepository([identity]);
        final hosts = _MemoryHostRepository();
        await hosts.save(
          HostConfig.fromJson({
            ..._hostConfig(
              id: 'agent-host',
              displayName: 'Agent Host',
              hostname: 'agent.test',
              createdAt: DateTime.utc(2026),
            ).toJson(),
            'identityIds': [identity.id.value],
          }),
        );
        final documents = _PrivateKeyDocuments();
        await _pumpLockedVaultApp(
          tester,
          hostRepository: hosts,
          identityRepository: identities,
          documentGateway: documents,
        );
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        await tester.pumpAndSettle();
        await _openHostContextMenu(tester, 'Agent Host');
        await tester.tap(find.text('Edit host'));
        await tester.pumpAndSettle();
        final edit = find.byKey(
          ValueKey('credential-edit-${identity.id.value}'),
        );
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        await tester.pumpAndSettle();
        tester.view.physicalSize = Size(width, 900);
        if (width < 900) {
          tester.platformDispatcher.textScaleFactorTestValue = 1.4;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        }
        await tester.pumpAndSettle();
        final card = find.byKey(const ValueKey('agent-selected-key-summary'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        expect(find.text(fingerprint), findsOneWidget);
        expect(find.text(publicKey), findsNothing);
        expect(find.text('Select public key file'), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-public-key-field')),
          findsNothing,
        );
        expect(find.text(label), findsOneWidget);
        final providerField = find.byKey(
          const ValueKey('agent-discover-endpoint-button'),
        );
        final keyField = find.byKey(const ValueKey('agent-select-key-button'));
        expect(
          tester.getSize(providerField).height,
          tester.getSize(keyField).height,
        );
        expect(
          tester.getRect(providerField).left,
          tester.getRect(keyField).left,
        );
        expect(
          tester.getRect(providerField).right,
          tester.getRect(keyField).right,
        );
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('agent-provider-icon')))
              .dx,
          tester.getCenter(find.byKey(const ValueKey('agent-key-icon'))).dx,
        );
        final rect = tester.getRect(card);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(width));
        expect(tester.takeException(), isNull);

        // Cancelling or failing an import preserves the existing selection.
        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Select public key file'));
        await tester.pumpAndSettle();
        expect(find.text(fingerprint), findsOneWidget);
        documents.fail = true;
        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Select public key file'));
        await tester.pumpAndSettle();
        expect(find.text(fingerprint), findsOneWidget);
        expect(
          find.text('Could not read a public key from this file.'),
          findsOneWidget,
        );

        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Enter public key manually'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-public-key-field')),
          findsOneWidget,
        );
        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Hide public key input'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent-public-key-field')),
          findsNothing,
        );
        await _openAgentKeyOptions(tester);
        await tester.tap(find.text('Use all agent keys'));
        await tester.pumpAndSettle();
        expect(find.text('All available keys'), findsOneWidget);
        expect(find.text(fingerprint), findsNothing);
        expect(
          find.byKey(const ValueKey('agent-selected-key-fingerprint')),
          findsNothing,
        );
        expect(
          tester.getSize(providerField).height,
          tester.getSize(keyField).height,
        );
        expect(
          tester
              .getCenter(find.byKey(const ValueKey('agent-provider-icon')))
              .dx,
          tester.getCenter(find.byKey(const ValueKey('agent-key-icon'))).dx,
        );
        await tester.tap(find.byKey(const ValueKey('credential-save-button')));
        await tester.pumpAndSettle();
        expect((await identities.read(identity.id))!.agent?.publicKey, isNull);
        expect(
          (await identities.read(identity.id))!.agent?.socketPath,
          '/agents/provider.sock',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final duplicate in [false, true]) {
    for (final (label, kind) in [
      ('Password', IdentityKind.password),
      ('Key', IdentityKind.privateKey),
      ('Agent', IdentityKind.sshAgent),
    ]) {
      testWidgets(
        '${duplicate ? 'duplicate' : 'edit'} host can switch to $label without changing shared credentials',
        (tester) async {
          final original = IdentityConfig(
            id: IdentityId('shared-agent'),
            displayName: 'Shared Agent',
            kind: IdentityKind.sshAgent,
            agent: const IdentityAgentConfig(socketPath: '/original.sock'),
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          );
          final identities = _MemoryIdentityRepository([original]);
          final hosts = _MemoryHostRepository();
          for (final id in ['source', 'other']) {
            await hosts.save(
              HostConfig.fromJson({
                ..._hostConfig(
                  id: id,
                  displayName: '$id host',
                  hostname: '$id.internal',
                  createdAt: DateTime.utc(2026),
                ).toJson(),
                'authKinds': ['sshAgent'],
                'identityIds': [original.id.value],
              }),
            );
          }
          const key =
              '-----BEGIN OPENSSH PRIVATE KEY-----\nfixture\n-----END OPENSSH PRIVATE KEY-----';
          final documents = _PrivateKeyDocuments()
            ..document = const PickedTextDocument(
              name: 'id_test',
              contents: key,
            );
          await _pumpLockedVaultApp(
            tester,
            hostRepository: hosts,
            identityRepository: identities,
            documentGateway: documents,
          );
          await _submitVaultPassphrase(tester, 'correct horse battery staple');
          await tester.pumpAndSettle();
          await _openHostContextMenu(tester, 'source host');
          await tester.tap(
            find.text(duplicate ? 'Duplicate session' : 'Edit host'),
          );
          await tester.pumpAndSettle();
          expect(find.text('Shared Agent'), findsOneWidget);
          for (final segment in ['Password', 'Key', 'Agent', 'Saved']) {
            expect(find.text(segment), findsOneWidget);
          }
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          switch (kind) {
            case IdentityKind.password:
              await tester.enterText(
                find.byKey(const ValueKey('host-password-field')),
                'replacement-password',
              );
            case IdentityKind.privateKey:
              final import = find.byKey(
                const ValueKey('host-import-private-key-button'),
              );
              await tester.ensureVisible(import);
              await tester.pumpAndSettle();
              await tester.tap(import);
              await tester.pumpAndSettle();
            case IdentityKind.sshAgent:
              await _showAgentCustomEndpoint(tester);
              await tester.enterText(
                find.byKey(const ValueKey('agent-socket-field')),
                '/replacement.sock',
              );
            default:
              throw StateError('Unexpected test kind');
          }
          // Switching back keeps the original binding and the unsaved input.
          await tester.ensureVisible(find.text('Saved'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Saved'));
          await tester.pumpAndSettle();
          expect(find.text('Shared Agent'), findsOneWidget);
          expect(await identities.list(), hasLength(1));
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('host-save-button')));
          await tester.pumpAndSettle();

          final all = await identities.list();
          expect(all, hasLength(2));
          final created = all.singleWhere((item) => item.id != original.id);
          expect(created.kind, kind);
          final target = duplicate
              ? hosts.hosts.singleWhere(
                  (host) =>
                      host.id.value != 'source' && host.id.value != 'other',
                )
              : (await hosts.read(HostId('source')))!;
          expect(target.identityIds, [created.id]);
          expect(target.authKinds, {
            switch (kind) {
              IdentityKind.password => HostAuthKind.password,
              IdentityKind.privateKey => HostAuthKind.privateKey,
              _ => HostAuthKind.sshAgent,
            },
          });
          expect((await hosts.read(HostId('other')))!.identityIds, [
            original.id,
          ]);
          if (duplicate) {
            expect((await hosts.read(HostId('source')))!.identityIds, [
              original.id,
            ]);
          }
          expect(
            (await identities.read(original.id))!.toJson(),
            original.toJson(),
          );
          final container = ProviderScope.containerOf(
            tester.element(find.byType(SerlinkApp)),
          );
          final secret = await container
              .read(identityWriteServiceProvider)
              .readSecretMaterial(created);
          if (kind == IdentityKind.password) {
            expect(secret?.password, 'replacement-password');
          }
          if (kind == IdentityKind.privateKey) {
            expect(secret?.privateKeyPem, key);
          }
          if (kind == IdentityKind.sshAgent) {
            expect(created.agent?.socketPath, '/replacement.sock');
            expect(secret, isNull);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'cancelling a host authentication switch preserves its saved credentials',
    (tester) async {
      final identities = _credentialPaginationIdentities();
      final hosts = _MemoryHostRepository();
      final original = HostConfig.fromJson({
        ..._hostConfig(
          id: 'source',
          displayName: 'source host',
          hostname: 'source.internal',
          createdAt: DateTime.utc(2026),
        ).toJson(),
        'identityIds': ['credential-09'],
      });
      await hosts.save(original);
      await _pumpLockedVaultApp(
        tester,
        hostRepository: hosts,
        identityRepository: identities,
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await tester.pumpAndSettle();
      await _openHostContextMenu(tester, 'source host');
      await tester.tap(find.text('Edit host'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Password'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Password'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('host-password-field')),
        'unsaved-password',
      );
      await tester.tap(find.widgetWithText(SerlinkTextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect((await hosts.read(original.id))!.toJson(), original.toJson());
      expect(await identities.list(), hasLength(10));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'agent picker selects a named public identity without displaying its key material',
    (tester) async {
      final hosts = _MemoryHostRepository();
      final identities = _MemoryIdentityRepository(const []);
      String? requestedEndpoint;
      var keyRequests = 0;
      const publicKey = 'ssh-ed25519 AAAA chosen-key';
      await _pumpLockedVaultApp(
        tester,
        hostRepository: hosts,
        identityRepository: identities,
        agentEndpointLoader: () async => const [
          DiscoveredSshAgent(
            socketPath: '/system.sock',
            identities: [],
            isSystem: true,
          ),
          DiscoveredSshAgent(
            socketPath: '/found/provider.sock',
            identities: [],
          ),
        ],
        agentIdentityLoader: (endpoint) async {
          requestedEndpoint = endpoint;
          keyRequests++;
          return const [
            SshAgentIdentityChoice(
              label: 'Other key',
              fingerprint: 'SHA256:other',
              publicKey: 'ssh-ed25519 AAAA other-key',
            ),
            SshAgentIdentityChoice(
              label: 'Chosen key',
              fingerprint: 'SHA256:chosen',
              publicKey: publicKey,
              socketPath: '/found/provider.sock',
            ),
          ];
        },
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await _tapAddHost(tester);
      await tester.enterText(
        find.byKey(const ValueKey('host-hostname-field')),
        'agent.example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('host-username-field')),
        'deploy',
      );
      await tester.ensureVisible(find.text('Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-discover-endpoint-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('agent-discover-endpoint-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('/found/provider.sock'));
      await tester.pumpAndSettle();
      final dialogs = find.byType(SerlinkDialog).evaluate().length;
      final picker = find.byKey(const ValueKey('agent-select-key-button'));
      await tester.ensureVisible(picker);
      await tester.pumpAndSettle();
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(find.byType(SerlinkDialog), findsNWidgets(dialogs));
      expect(requestedEndpoint, '/found/provider.sock');
      expect(find.text('Other key'), findsOneWidget);
      expect(find.text('SHA256:chosen'), findsOneWidget);
      expect(find.text(publicKey), findsNothing);
      final search = find
          .byWidgetPredicate(
            (widget) => widget is EditableText && !widget.readOnly,
          )
          .last;
      await tester.enterText(search, '  CHOSEN  ');
      await tester.pumpAndSettle();
      expect(find.text('Other key'), findsNothing);
      expect(find.text('Chosen key'), findsOneWidget);
      await tester.enterText(search, 'no-matching-key');
      await tester.pumpAndSettle();
      expect(find.text('No matching keys.'), findsOneWidget);
      await tester.enterText(search, 'SHA256:chosen');
      await tester.pumpAndSettle();
      expect(find.text('Chosen key'), findsOneWidget);
      expect(keyRequests, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Search name or fingerprint'), findsNothing);
      // Reopening refreshes the agent; choosing all keys clears the old key.
      await tester.tap(picker);
      await tester.pumpAndSettle();
      expect(keyRequests, 2);
      await tester.tap(find.text('All available keys'));
      await tester.pumpAndSettle();
      expect(find.text('All available keys'), findsOneWidget);
      expect(find.text('SHA256:chosen'), findsNothing);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chosen key'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Chosen key'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('agent-public-key-field')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('host-save-button')));
      await tester.pumpAndSettle();
      expect((await identities.list()).single.agent?.publicKey, publicKey);
      expect(
        (await identities.list()).single.agent?.socketPath,
        '/found/provider.sock',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('agent key dropdown recovers from unavailable and empty agents', (
    tester,
  ) async {
    final pending = Completer<List<SshAgentIdentityChoice>>();
    var requests = 0;
    await _pumpLockedVaultApp(
      tester,
      agentIdentityLoader: (_) {
        requests++;
        return requests == 1 ? pending.future : Future.value(const []);
      },
    );
    await _submitVaultPassphrase(tester, 'correct horse battery staple');
    await _tapAddHost(tester);
    await tester.ensureVisible(find.text('Agent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agent'));
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('agent-select-key-button'));
    await tester.ensureVisible(picker);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pump();
    expect(requests, 1);
    pending.completeError(StateError('Agent unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('SSH agent is not available.'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.tap(picker);
    await tester.pumpAndSettle();
    expect(requests, 2);
    expect(
      find.textContaining('SSH agent has no loaded identities.'),
      findsOneWidget,
    );
    await tester.tap(find.text('All available keys').last);
    await tester.pumpAndSettle();
    expect(find.text('All available keys'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (label, kind) in [
    ('SSH Agent', IdentityKind.sshAgent),
    ('Hardware Key', IdentityKind.hardwareKey),
  ]) {
    testWidgets(
      '$label credentials persist a generic agent without secret material',
      (tester) async {
        final identities = _MemoryIdentityRepository(const []);
        await _pumpLockedVaultApp(tester, identityRepository: identities);
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        await _openCredentialManager(tester);
        await tester.tap(find.byKey(const ValueKey('credentials-add-button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('credential-display-name-field')),
          label,
        );
        await _showAgentCustomEndpoint(tester);
        await tester.ensureVisible(
          find.byKey(const ValueKey('agent-socket-field')),
        );
        await tester.pumpAndSettle();
        await _showAgentCustomEndpoint(tester);
        await tester.enterText(
          find.byKey(const ValueKey('agent-socket-field')),
          '~/agents/provider.sock',
        );
        await tester.tap(find.byKey(const ValueKey('credential-save-button')));
        await tester.pumpAndSettle();
        final identity = (await identities.list()).single;
        expect(identity.kind, kind);
        expect(identity.agent?.socketPath, '~/agents/provider.sock');
        expect(identity.secretRecordId, isNull);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'host Agent input persists a generic endpoint and selected public key',
    (tester) async {
      final hosts = _MemoryHostRepository();
      final identities = _MemoryIdentityRepository(const []);
      await _pumpLockedVaultApp(
        tester,
        hostRepository: hosts,
        identityRepository: identities,
      );
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await _tapAddHost(tester);
      await tester.enterText(
        find.byKey(const ValueKey('host-hostname-field')),
        'agent.example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('host-username-field')),
        'deploy',
      );
      await tester.ensureVisible(find.text('Agent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agent'));
      await tester.pumpAndSettle();
      await _showAgentCustomEndpoint(tester);
      await tester.enterText(
        find.byKey(const ValueKey('agent-socket-field')),
        '~/agents/custom.sock',
      );
      await _openAgentKeyOptions(tester);
      await tester.tap(find.text('Enter public key manually'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('agent-public-key-field')),
        'ssh-ed25519 AAAA public',
      );
      await tester.tap(find.byKey(const ValueKey('host-save-button')));
      await tester.pumpAndSettle();
      final identity = (await identities.list()).single;
      expect(identity.kind, IdentityKind.sshAgent);
      expect(identity.agent?.socketPath, '~/agents/custom.sock');
      expect(identity.agent?.publicKey, 'ssh-ed25519 AAAA public');
      expect(identity.secretRecordId, isNull);
      expect(hosts.hosts.single.identityIds, [identity.id]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'certificate credentials can use an external agent and keep private keys outside the vault',
    (tester) async {
      final identities = _MemoryIdentityRepository(const []);
      await _pumpLockedVaultApp(tester, identityRepository: identities);
      await _submitVaultPassphrase(tester, 'correct horse battery staple');
      await _openCredentialManager(tester);
      await tester.tap(find.byKey(const ValueKey('credentials-add-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Certificate'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('host-import-private-key-button')),
        findsNothing,
      );
      await tester.enterText(
        find.byKey(const ValueKey('credential-display-name-field')),
        'Agent certificate',
      );
      await _showAgentCustomEndpoint(tester);
      await tester.ensureVisible(
        find.byKey(const ValueKey('agent-socket-field')),
      );
      await tester.pumpAndSettle();
      await _showAgentCustomEndpoint(tester);
      await tester.enterText(
        find.byKey(const ValueKey('agent-socket-field')),
        '~/agents/custom.sock',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('credential-certificate-field')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('credential-certificate-field')),
        'ssh-ed25519-cert-v01@openssh.com AAAAB3NzaC1yc2EAAAADAQABAAABAQ== test',
      );
      await tester.tap(find.byKey(const ValueKey('credential-save-button')));
      await tester.pumpAndSettle();
      final identity = (await identities.list()).single;
      expect(identity.kind, IdentityKind.openSshCertificate);
      expect(identity.agent?.socketPath, '~/agents/custom.sock');
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SerlinkApp)),
      );
      final secret = await container
          .read(identityWriteServiceProvider)
          .readSecretMaterial(identity);
      expect(secret?.privateKeyPem, isNull);
      expect(secret?.openSshCertificate, contains('-cert-v01@openssh.com'));
      expect(tester.takeException(), isNull);
    },
  );

  for (final mobile in [false, true]) {
    testWidgets(
      'private key file import preserves secrets on cancel and error (mobile: $mobile)',
      (tester) async {
        if (mobile) {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(390, 844);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
        }
        final hosts = _MemoryHostRepository();
        final identities = _MemoryIdentityRepository(const []);
        final gateway = _PrivateKeyDocuments();
        await _pumpLockedVaultApp(
          tester,
          hostRepository: hosts,
          identityRepository: identities,
          documentGateway: gateway,
          capabilities: mobile
              ? const PlatformCapabilities(
                  operatingSystem: 'ios',
                  targetPlatform: TargetPlatform.iOS,
                )
              : null,
        );
        await _submitVaultPassphrase(tester, 'correct horse battery staple');
        await _tapAddHost(tester);
        await tester.enterText(
          find.byKey(const ValueKey('host-hostname-field')),
          'key.example.test',
        );
        await tester.enterText(
          find.byKey(const ValueKey('host-username-field')),
          'deploy',
        );
        await tester.ensureVisible(find.text('Key'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Key'));
        await tester.pumpAndSettle();
        final importButton = find.byKey(
          const ValueKey('host-import-private-key-button'),
        );
        final manualToggle = find.byKey(
          const ValueKey('private-key-manual-entry-toggle'),
        );
        final keyField = find.byKey(const ValueKey('host-private-key-field'));
        expect(keyField, findsNothing);
        Future<void> import() async {
          await tester.ensureVisible(importButton);
          await tester.pumpAndSettle();
          await tester.tap(importButton);
          await tester.pumpAndSettle();
        }

        const contents =
            '-----BEGIN OPENSSH PRIVATE KEY-----\ntest-key\n-----END OPENSSH PRIVATE KEY-----';
        gateway.document = const PickedTextDocument(
          name: 'id_ed25519',
          contents: contents,
        );
        await import();
        expect(find.text('id_ed25519'), findsOneWidget);
        expect(keyField, findsNothing);
        gateway.document = null;
        await import();
        expect(find.text('id_ed25519'), findsOneWidget);
        gateway.fail = true;
        await import();
        expect(
          find.textContaining('Could not read the private key file'),
          findsOneWidget,
        );
        expect(find.text('id_ed25519'), findsOneWidget);
        gateway.fail = false;
        gateway.document = const PickedTextDocument(
          name: 'empty',
          contents: ' ',
        );
        await import();
        expect(
          find.textContaining('Could not read the private key file'),
          findsOneWidget,
        );
        expect(find.text('id_ed25519'), findsOneWidget);
        await tester.ensureVisible(manualToggle);
        await tester.pumpAndSettle();
        await tester.tap(manualToggle);
        await tester.pumpAndSettle();
        expect(
          tester.widget<SerlinkTextField>(keyField).controller!.text,
          contents,
        );
        await tester.tap(manualToggle);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('host-save-button')));
        await tester.pumpAndSettle();
        final created = (await identities.list()).single;
        expect(created.kind, IdentityKind.privateKey);
        expect(hosts.hosts.single.identityIds, [created.id]);
        final container = ProviderScope.containerOf(
          tester.element(find.byType(SerlinkApp)),
        );
        final secret = await container
            .read(identityWriteServiceProvider)
            .readSecretMaterial(created);
        expect(secret?.privateKeyPem, contents);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

class _PrivateKeyDocuments extends DocumentGateway {
  _PrivateKeyDocuments()
    : super(
        capabilities: const PlatformCapabilities(
          operatingSystem: 'windows',
          targetPlatform: TargetPlatform.windows,
        ),
      );

  PickedTextDocument? document;
  bool fail = false;

  @override
  Future<PickedTextDocument?> pickTextFile({
    List<XTypeGroup> acceptedTypeGroups = const [],
  }) async {
    if (fail) throw const FileSystemException('unreadable');
    return document;
  }
}

Future<void> _openCredentialManager(WidgetTester tester) async {
  await tester.tap(find.text('Settings'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Credentials'));
  await tester.pumpAndSettle();
  final dy = tester.getCenter(find.text('Credentials')).dy;
  final buttons = find.text('Manage');
  var closest = buttons.first;
  var distance = double.infinity;
  for (var i = 0; i < buttons.evaluate().length; i++) {
    final button = buttons.at(i);
    final nextDistance = (tester.getCenter(button).dy - dy).abs();
    if (nextDistance < distance) {
      closest = button;
      distance = nextDistance;
    }
  }
  await tester.tap(closest);
  await tester.pumpAndSettle();
}

Future<void> _openAgentKeyOptions(WidgetTester tester) async {
  final options = find.byKey(const ValueKey('agent-key-options-button'));
  await tester.ensureVisible(options);
  await tester.pumpAndSettle();
  await tester.tap(options);
  await tester.pumpAndSettle();
}

Future<void> _showAgentCustomEndpoint(WidgetTester tester) async {
  final field = find.byKey(const ValueKey('agent-socket-field'));
  if (field.evaluate().isEmpty) {
    final options = find.byKey(const ValueKey('agent-provider-options-button'));
    await tester.ensureVisible(options);
    await tester.pumpAndSettle();
    await tester.tap(options);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use a custom endpoint'));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
}
