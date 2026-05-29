import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/dart.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:webdav_client/webdav_client.dart' as webdav;

import '../domain/sync_provider.dart';
import '../domain/webdav_tls_certificate_details.dart';

class WebDavSyncProvider implements SyncProvider {
  WebDavSyncProvider({
    required Uri endpoint,
    required String username,
    required String password,
    String basePath = '/serlink',
    bool allowInsecureHttp = false,
    String? pinnedCertificateFingerprint,
    webdav.Client? client,
  }) : _basePath = _normalizeBasePath(basePath),
       _client = _mappedClient(
         client ??
             _newClient(
               endpoint: endpoint,
               username: username,
               password: password,
               allowInsecureHttp: allowInsecureHttp,
               pinnedCertificateFingerprint: pinnedCertificateFingerprint,
             ),
         endpoint: endpoint,
         pinnedCertificateFingerprint: pinnedCertificateFingerprint,
       );

  static const _manifestFileName = 'manifest.json';

  final String _basePath;
  final webdav.Client _client;

  @override
  Future<ProviderCapabilities> capabilities() async {
    return const ProviderCapabilities(
      kind: SyncProviderKind.webDav,
      supportsConditionalWrites: false,
      requiresTls: true,
    );
  }

  @override
  Future<RemoteManifest?> readManifest() async {
    try {
      return RemoteManifest.fromBytes(
        await _client.read(_join(_basePath, _manifestFileName)),
      );
    } on SyncProviderException catch (error) {
      if (error.code == 'sync.provider.not_found') {
        return null;
      }
      rethrow;
    } on FormatException {
      throw const SyncProviderException(
        'sync.provider.manifest_invalid',
        'WebDAV sync manifest is invalid.',
      );
    }
  }

  @override
  Future<void> writeManifest(RemoteManifest manifest) async {
    await _client.mkdirAll(_basePath);
    await _client.write(
      _join(_basePath, _manifestFileName),
      Uint8List.fromList(manifest.toBytes()),
    );
  }

  @override
  Future<List<RemoteObjectRef>> listRecordObjects({String? prefix}) async {
    final directory = _join(_basePath, prefix ?? '');
    final files = await _client.readDir(directory);
    return [
      for (final file in files)
        if (file.isDir != true && file.path != null)
          RemoteObjectRef(_stripBasePath(file.path!)),
    ]..sort((a, b) => a.path.compareTo(b.path));
  }

  @override
  Future<List<int>> readObject(RemoteObjectRef ref) async {
    return _client.read(_join(_basePath, ref.path));
  }

  @override
  Future<void> writeObject(RemoteObjectRef ref, List<int> bytes) async {
    await _client.mkdirAll(_parentPath(_join(_basePath, ref.path)));
    await _client.write(_join(_basePath, ref.path), Uint8List.fromList(bytes));
  }

  @override
  Future<void> deleteObject(RemoteObjectRef ref) async {
    await _client.remove(_join(_basePath, ref.path));
  }

  String _stripBasePath(String remotePath) {
    final normalized = remotePath.startsWith('/') ? remotePath : '/$remotePath';
    if (normalized.startsWith(_basePath)) {
      return normalized.substring(_basePath.length).replaceFirst('/', '');
    }
    return normalized.replaceFirst('/', '');
  }
}

SyncProviderException _mapWebDavException(
  DioException error, {
  Uri? endpoint,
  String? pinnedCertificateFingerprint,
}) {
  final statusCode = error.response?.statusCode;
  if (statusCode != null) {
    return switch (statusCode) {
      401 => SyncProviderException(
        'sync.provider.authentication_failed',
        'WebDAV authentication failed.',
        statusCode: statusCode,
      ),
      403 => SyncProviderException(
        'sync.provider.forbidden',
        'WebDAV account does not have permission for this sync path.',
        statusCode: statusCode,
      ),
      404 => SyncProviderException(
        'sync.provider.not_found',
        'WebDAV sync path was not found.',
        statusCode: statusCode,
      ),
      409 => SyncProviderException(
        'sync.provider.partial_upload',
        'WebDAV sync path is incomplete. Serlink can rebuild the encrypted remote set from local records.',
        statusCode: statusCode,
      ),
      423 => SyncProviderException(
        'sync.provider.locked',
        'WebDAV sync path is locked by the provider.',
        statusCode: statusCode,
      ),
      507 => SyncProviderException(
        'sync.provider.quota_exceeded',
        'WebDAV storage quota is full.',
        statusCode: statusCode,
      ),
      >= 500 && < 600 => SyncProviderException(
        'sync.provider.server_error',
        'WebDAV server is temporarily unavailable.',
        statusCode: statusCode,
      ),
      _ => SyncProviderException(
        'sync.provider.http_error',
        'WebDAV sync failed with HTTP $statusCode.',
        statusCode: statusCode,
      ),
    };
  }

  return switch (error.type) {
    DioExceptionType.badCertificate => _tlsCertificateFailure(
      error,
      endpoint: endpoint,
      pinnedCertificateFingerprint: pinnedCertificateFingerprint,
    ),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const SyncProviderException(
      'sync.provider.timeout',
      'WebDAV sync timed out.',
    ),
    DioExceptionType.connectionError => const SyncProviderException(
      'sync.provider.network_unavailable',
      'WebDAV network connection failed.',
    ),
    DioExceptionType.cancel => const SyncProviderException(
      'sync.provider.cancelled',
      'WebDAV sync was cancelled.',
    ),
    DioExceptionType.badResponse => const SyncProviderException(
      'sync.provider.http_error',
      'WebDAV sync failed.',
    ),
    DioExceptionType.unknown => const SyncProviderException(
      'sync.provider.unavailable',
      'WebDAV sync is unavailable.',
    ),
  };
}

SyncProviderException _tlsCertificateFailure(
  DioException error, {
  Uri? endpoint,
  String? pinnedCertificateFingerprint,
}) {
  final certificate = error.error;
  final details = certificate is X509Certificate && endpoint != null
      ? webDavTlsCertificateDetails(
          endpoint: endpoint,
          certificate: certificate,
          reason: _certificateFailureReason(certificate, DateTime.now()),
          expectedFingerprint: pinnedCertificateFingerprint,
        )
      : null;
  return SyncProviderException(
    'sync.provider.tls_certificate_failed',
    _tlsCertificateFailureMessage(details),
    diagnostic: details?.toDiagnosticJson(),
  );
}

String _tlsCertificateFailureMessage(WebDavTlsCertificateDetails? details) {
  if (details == null) {
    return 'WebDAV TLS certificate validation failed.';
  }
  if (details.requiresClockReview) {
    return 'WebDAV TLS certificate is not valid yet. Check this device clock and time zone.';
  }
  if (details.expectedFingerprint != null &&
      _normalizeFingerprint(details.expectedFingerprint) !=
          _normalizeFingerprint(details.fingerprint)) {
    return 'WebDAV TLS certificate changed. Review the new fingerprint before syncing.';
  }
  return 'WebDAV TLS certificate is untrusted. Review the fingerprint before syncing.';
}

String _certificateFailureReason(X509Certificate certificate, DateTime now) {
  final utcNow = now.toUtc();
  if (utcNow.isBefore(certificate.startValidity.toUtc())) {
    return 'not_yet_valid';
  }
  if (utcNow.isAfter(certificate.endValidity.toUtc())) {
    return 'expired';
  }
  return 'untrusted';
}

webdav.Client _newClient({
  required Uri endpoint,
  required String username,
  required String password,
  required bool allowInsecureHttp,
  required String? pinnedCertificateFingerprint,
}) {
  if (endpoint.scheme != 'https' && !allowInsecureHttp) {
    throw ArgumentError.value(
      endpoint.toString(),
      'endpoint',
      'WebDAV sync requires HTTPS unless insecure HTTP was explicitly allowed.',
    );
  }
  final dio = _newDio(endpoint, pinnedCertificateFingerprint);
  return webdav.Client(
    uri: _withTrailingSlash(endpoint.toString()),
    c: dio,
    auth: webdav.Auth(user: username, pwd: password),
  );
}

webdav.Client _mappedClient(
  webdav.Client client, {
  required Uri endpoint,
  required String? pinnedCertificateFingerprint,
}) {
  return _MappedWebDavClient(
    inner: client,
    endpoint: endpoint,
    pinnedCertificateFingerprint: pinnedCertificateFingerprint,
  );
}

webdav.WdDio _newDio(Uri endpoint, String? pinnedCertificateFingerprint) {
  final dio = webdav.WdDio(debug: false);
  if (endpoint.scheme != 'https') {
    return dio;
  }
  final normalizedPinnedFingerprint = _normalizeFingerprint(
    pinnedCertificateFingerprint,
  );
  final badCertificateCounts = <String, int>{};
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () {
      final client = HttpClient()..idleTimeout = const Duration(seconds: 3);
      client.badCertificateCallback = (certificate, host, port) {
        if (!_isEndpointHost(endpoint, host, port)) {
          return false;
        }
        final key = _certificateApprovalKey(certificate, host, port);
        badCertificateCounts[key] = (badCertificateCounts[key] ?? 0) + 1;
        return true;
      };
      return client;
    },
    validateCertificate: (certificate, host, port) {
      if (certificate == null || !_isEndpointHost(endpoint, host, port)) {
        return false;
      }
      final key = _certificateApprovalKey(certificate, host, port);
      final badCertificateCount = badCertificateCounts[key] ?? 0;
      if (badCertificateCount > 1) {
        badCertificateCounts[key] = badCertificateCount - 1;
      } else {
        badCertificateCounts.remove(key);
      }
      if (normalizedPinnedFingerprint != null) {
        return normalizedPinnedFingerprint ==
            _normalizeFingerprint(webDavTlsCertificateFingerprint(certificate));
      }
      return badCertificateCount == 0;
    },
  );
  return dio;
}

class _MappedWebDavClient implements webdav.Client {
  _MappedWebDavClient({
    required this.inner,
    required this.endpoint,
    required this.pinnedCertificateFingerprint,
  });

  final webdav.Client inner;
  final Uri endpoint;
  final String? pinnedCertificateFingerprint;

  @override
  Future<void> mkdirAll(String path, [CancelToken? cancelToken]) async {
    try {
      await inner.mkdirAll(path, cancelToken);
    } on SyncProviderException {
      rethrow;
    } on DioException catch (error) {
      throw _mapWebDavException(
        error,
        endpoint: endpoint,
        pinnedCertificateFingerprint: pinnedCertificateFingerprint,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'WebDAV sync is unavailable.',
      );
    }
  }

  @override
  Future<List<webdav.File>> readDir(
    String path, [
    CancelToken? cancelToken,
  ]) async {
    try {
      return await inner.readDir(path, cancelToken);
    } on SyncProviderException {
      rethrow;
    } on DioException catch (error) {
      throw _mapWebDavException(
        error,
        endpoint: endpoint,
        pinnedCertificateFingerprint: pinnedCertificateFingerprint,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'WebDAV sync is unavailable.',
      );
    }
  }

  @override
  Future<List<int>> read(
    String path, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      return await inner.read(
        path,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on SyncProviderException {
      rethrow;
    } on DioException catch (error) {
      throw _mapWebDavException(
        error,
        endpoint: endpoint,
        pinnedCertificateFingerprint: pinnedCertificateFingerprint,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'WebDAV sync is unavailable.',
      );
    }
  }

  @override
  Future<void> write(
    String path,
    Uint8List data, {
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      await inner.write(
        path,
        data,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    } on SyncProviderException {
      rethrow;
    } on DioException catch (error) {
      throw _mapWebDavException(
        error,
        endpoint: endpoint,
        pinnedCertificateFingerprint: pinnedCertificateFingerprint,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'WebDAV sync is unavailable.',
      );
    }
  }

  @override
  Future<void> remove(String path, [CancelToken? cancelToken]) async {
    try {
      await inner.remove(path, cancelToken);
    } on SyncProviderException {
      rethrow;
    } on DioException catch (error) {
      throw _mapWebDavException(
        error,
        endpoint: endpoint,
        pinnedCertificateFingerprint: pinnedCertificateFingerprint,
      );
    } on Object {
      throw const SyncProviderException(
        'sync.provider.unavailable',
        'WebDAV sync is unavailable.',
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

String _certificateApprovalKey(
  X509Certificate certificate,
  String host,
  int port,
) {
  return '${host.toLowerCase()}:$port:${webDavTlsCertificateFingerprint(certificate)}';
}

bool _isEndpointHost(Uri endpoint, String host, int port) {
  final expectedPort = endpoint.hasPort ? endpoint.port : 443;
  return endpoint.host.toLowerCase() == host.toLowerCase() &&
      expectedPort == port;
}

String webDavTlsCertificateFingerprint(X509Certificate certificate) {
  final digest = const DartSha256().hashSync(certificate.der);
  return _formatSha256Fingerprint(digest.bytes);
}

WebDavTlsCertificateDetails webDavTlsCertificateDetails({
  required Uri endpoint,
  required X509Certificate certificate,
  required String reason,
  String? expectedFingerprint,
}) {
  return WebDavTlsCertificateDetails(
    endpoint: endpoint,
    fingerprint: webDavTlsCertificateFingerprint(certificate),
    algorithm: 'SHA256',
    subject: certificate.subject,
    issuer: certificate.issuer,
    validFrom: certificate.startValidity.toUtc(),
    validUntil: certificate.endValidity.toUtc(),
    reason: reason,
    expectedFingerprint: expectedFingerprint,
  );
}

String _formatSha256Fingerprint(List<int> bytes) {
  return 'SHA256:${base64Encode(bytes).replaceAll('=', '')}';
}

String? _normalizeFingerprint(String? fingerprint) {
  if (fingerprint == null) {
    return null;
  }
  return fingerprint.trim().toLowerCase();
}

String _withTrailingSlash(String value) {
  return value.endsWith('/') ? value : '$value/';
}

String _normalizeBasePath(String path) {
  final cleaned = path.trim();
  if (cleaned.isEmpty || cleaned == '/') {
    return '';
  }
  final withLeadingSlash = cleaned.startsWith('/') ? cleaned : '/$cleaned';
  return withLeadingSlash.endsWith('/')
      ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
      : withLeadingSlash;
}

String _join(String basePath, String childPath) {
  final cleanedChild = childPath.replaceFirst(RegExp('^/+'), '');
  if (basePath.isEmpty) {
    return '/$cleanedChild';
  }
  if (cleanedChild.isEmpty) {
    return basePath;
  }
  return '$basePath/$cleanedChild';
}

String _parentPath(String path) {
  final normalized = path.startsWith('/') ? path : '/$path';
  final index = normalized.lastIndexOf('/');
  if (index <= 0) {
    return '/';
  }
  return normalized.substring(0, index);
}
