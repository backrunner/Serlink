import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:serlink/features/sync/data/local_sync_provider.dart';
import 'package:serlink/features/sync/data/webdav_sync_provider.dart';
import 'package:serlink/features/sync/domain/sync_provider.dart';
import 'package:serlink/features/sync/domain/webdav_tls_certificate_details.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('serlink-sync-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'local sync provider round trips encrypted manifest and objects',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final manifest = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        encryptedPayload: [1, 2, 3],
      );

      expect(await provider.readManifest(), isNull);

      await provider.writeManifest(manifest);
      await provider.writeObject(const RemoteObjectRef('records/a.bin'), [
        4,
        5,
      ]);
      await provider.writeObject(const RemoteObjectRef('records/b.bin'), [
        6,
        7,
      ]);

      final restored = await provider.readManifest();
      expect(restored, isNotNull);
      expect(restored!.encryptedPayload, manifest.encryptedPayload);
      expect(restored.snapshotObjectPaths, isEmpty);
      expect(
        await provider.readObject(const RemoteObjectRef('records/a.bin')),
        [4, 5],
      );
      expect(
        [
          for (final ref in await provider.listRecordObjects(prefix: 'records'))
            ref.path,
        ],
        ['records/a.bin', 'records/b.bin'],
      );

      await provider.deleteObject(const RemoteObjectRef('records/a.bin'));

      expect(
        [
          for (final ref in await provider.listRecordObjects(prefix: 'records'))
            ref.path,
        ],
        ['records/b.bin'],
      );
    },
  );

  test('local sync provider rejects unsafe object paths', () async {
    final provider = LocalDirectorySyncProvider(tempDir);

    await expectLater(
      provider.writeObject(const RemoteObjectRef('../outside.bin'), [1]),
      throwsA(
        isA<SyncProviderException>().having(
          (error) => error.code,
          'code',
          'sync.provider.invalid_object_ref',
        ),
      ),
    );

    expect(
      await File(p.join(tempDir.parent.path, 'outside.bin')).exists(),
      isFalse,
    );
  });

  test('remote manifest round trips snapshot object paths', () async {
    final manifest = RemoteManifest(
      vaultId: 'vault-1',
      protocolVersion: 1,
      headerPath: 'vault/headers/vault-1.json',
      encryptedPayload: [1, 2, 3],
      snapshotObjectPaths: const [
        'records/host%3A1-rev.json',
        'vault/headers/vault-1.json',
      ],
    );

    final restored = RemoteManifest.fromBytes(manifest.toBytes());

    expect(restored.vaultId, manifest.vaultId);
    expect(restored.headerPath, manifest.headerPath);
    expect(restored.encryptedPayload, manifest.encryptedPayload);
    expect(restored.snapshotObjectPaths, manifest.snapshotObjectPaths);
  });

  test(
    'conditional manifest writes include snapshot object paths in conflict checks',
    () async {
      final provider = LocalDirectorySyncProvider(tempDir);
      final current = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [1, 2, 3],
        snapshotObjectPaths: const ['records/current.bin'],
      );
      final staleExpected = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [1, 2, 3],
        snapshotObjectPaths: const ['records/stale.bin'],
      );
      final next = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [4, 5, 6],
        snapshotObjectPaths: const ['records/next.bin'],
      );

      await provider.writeManifest(current);

      await expectLater(
        provider.writeManifestIfUnchanged(next, staleExpected),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.conflict',
          ),
        ),
      );
      expect(
        (await provider.readManifest())?.snapshotObjectPaths,
        current.snapshotObjectPaths,
      );
    },
  );

  test('webdav provider rejects insecure HTTP unless explicitly allowed', () {
    expect(
      () => WebDavSyncProvider(
        endpoint: Uri.parse('http://example.test/webdav'),
        username: 'u',
        password: 'p',
      ),
      throwsArgumentError,
    );

    final provider = WebDavSyncProvider(
      endpoint: Uri.parse('http://example.test/webdav'),
      username: 'u',
      password: 'p',
      allowInsecureHttp: true,
    );

    expect(provider.capabilities(), completion(isA<ProviderCapabilities>()));
  });

  test(
    'webdav provider creates parent folders before writing objects',
    () async {
      final client = _FakeWebDavClient();
      final provider = WebDavSyncProvider(
        endpoint: Uri.parse('https://example.test/webdav'),
        username: 'u',
        password: 'p',
        client: client,
      );

      await provider.writeObject(const RemoteObjectRef('records/a.bin'), [
        1,
        2,
      ]);

      expect(client.createdDirectories, contains('/serlink/records'));
      expect(client.writes, containsPair('/serlink/records/a.bin', [1, 2]));
    },
  );

  test('webdav provider rejects unsafe object paths', () async {
    final client = _FakeWebDavClient();
    final provider = WebDavSyncProvider(
      endpoint: Uri.parse('https://example.test/webdav'),
      username: 'u',
      password: 'p',
      client: client,
    );

    await expectLater(
      provider.writeObject(const RemoteObjectRef('/absolute.bin'), [1]),
      throwsA(
        isA<SyncProviderException>().having(
          (error) => error.code,
          'code',
          'sync.provider.invalid_object_ref',
        ),
      ),
    );

    expect(client.writes, isEmpty);
    expect(client.createdDirectories, isEmpty);
  });

  test(
    'webdav conditional manifest writes reject stale snapshot paths',
    () async {
      final client = _FakeWebDavClient();
      final provider = WebDavSyncProvider(
        endpoint: Uri.parse('https://example.test/webdav'),
        username: 'u',
        password: 'p',
        client: client,
      );
      final current = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [1, 2, 3],
        snapshotObjectPaths: const ['records/current.bin'],
      );
      final staleExpected = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [1, 2, 3],
        snapshotObjectPaths: const ['records/stale.bin'],
      );
      final next = RemoteManifest(
        vaultId: 'vault-1',
        protocolVersion: 1,
        headerPath: 'vault/headers/vault-1.json',
        encryptedPayload: [4, 5, 6],
        snapshotObjectPaths: const ['records/next.bin'],
      );

      await provider.writeManifest(current);

      await expectLater(
        provider.writeManifestIfUnchanged(next, staleExpected),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            'sync.provider.conflict',
          ),
        ),
      );
      expect(
        (await provider.readManifest())?.snapshotObjectPaths,
        current.snapshotObjectPaths,
      );
    },
  );

  test('webdav provider maps provider errors to stable sync errors', () async {
    final cases = <(DioException, String)>[
      (
        DioException(
          requestOptions: RequestOptions(path: '/serlink/manifest.json'),
          response: Response<void>(
            requestOptions: RequestOptions(path: '/serlink/manifest.json'),
            statusCode: 401,
          ),
          type: DioExceptionType.badResponse,
        ),
        'sync.provider.authentication_failed',
      ),
      (
        DioException(
          requestOptions: RequestOptions(path: '/serlink/manifest.json'),
          type: DioExceptionType.transformTimeout,
        ),
        'sync.provider.timeout',
      ),
    ];

    for (final (error, expectedCode) in cases) {
      final client = _FakeWebDavClient(readError: error);
      final provider = WebDavSyncProvider(
        endpoint: Uri.parse('https://example.test/webdav'),
        username: 'u',
        password: 'p',
        client: client,
      );

      await expectLater(
        provider.readManifest(),
        throwsA(
          isA<SyncProviderException>().having(
            (error) => error.code,
            'code',
            expectedCode,
          ),
        ),
      );
    }
  });

  test(
    'webdav provider includes certificate diagnostics on TLS failure',
    () async {
      final certificate = _FakeX509Certificate(
        subject: 'CN=dav.example.test',
        issuer: 'CN=Local CA',
        startValidity: DateTime.utc(2026, 1, 1),
        endValidity: DateTime.utc(2027, 1, 1),
        der: Uint8List.fromList([1, 2, 3, 4]),
      );
      final client = _FakeWebDavClient(
        readError: DioException.badCertificate(
          requestOptions: RequestOptions(path: '/serlink/manifest.json'),
          error: certificate,
        ),
      );
      final provider = WebDavSyncProvider(
        endpoint: Uri.parse('https://dav.example.test/webdav'),
        username: 'u',
        password: 'p',
        client: client,
      );

      try {
        await provider.readManifest();
        fail('did not throw');
      } on SyncProviderException catch (error) {
        expect(error.code, 'sync.provider.tls_certificate_failed');
        final details = WebDavTlsCertificateDetails.tryParse(error.diagnostic);
        expect(details, isNotNull);
        expect(details!.endpoint.host, 'dav.example.test');
        expect(details.fingerprint, startsWith('SHA256:'));
        expect(details.requiresClockReview, isFalse);
      }
    },
  );
}

class _FakeWebDavClient implements webdav.Client {
  _FakeWebDavClient({this.readError});

  final Object? readError;
  final createdDirectories = <String>[];
  final writes = <String, List<int>>{};

  @override
  Future<void> mkdirAll(String path, [CancelToken? cancelToken]) async {
    createdDirectories.add(path);
  }

  @override
  Future<void> write(
    String path,
    Uint8List data, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    writes[path] = data;
  }

  @override
  Future<List<int>> read(
    String path, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return writes[path] ??
        (throw const SyncProviderException(
          'sync.provider.not_found',
          'Sync object was not found.',
        ));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeX509Certificate implements X509Certificate {
  const _FakeX509Certificate({
    required this.subject,
    required this.issuer,
    required this.startValidity,
    required this.endValidity,
    required this.der,
  });

  @override
  final String subject;

  @override
  final String issuer;

  @override
  final DateTime startValidity;

  @override
  final DateTime endValidity;

  @override
  final Uint8List der;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
