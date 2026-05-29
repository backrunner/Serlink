import 'dart:convert';

import '../../../core/ids/entity_id.dart';
import '../../../platform/secret_store.dart';
import '../../vault/application/vault_record_repository.dart';
import '../../vault/application/vault_service.dart';
import '../data/webdav_sync_provider.dart';
import '../domain/webdav_tls_certificate_details.dart';

class WebDavSyncSettings {
  const WebDavSyncSettings({
    required this.endpoint,
    required this.username,
    required this.basePath,
    required this.passwordRef,
    required this.allowInsecureHttp,
    required this.enabled,
    required this.updatedAt,
    this.pinnedCertificateFingerprint,
  });

  final Uri endpoint;
  final String username;
  final String basePath;
  final SecretRef passwordRef;
  final bool allowInsecureHttp;
  final bool enabled;
  final DateTime updatedAt;
  final String? pinnedCertificateFingerprint;

  Map<String, Object?> toJson() {
    return {
      'endpoint': endpoint.toString(),
      'username': username,
      'basePath': basePath,
      'passwordRef': passwordRef.value,
      'allowInsecureHttp': allowInsecureHttp,
      'enabled': enabled,
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'pinnedCertificateFingerprint': pinnedCertificateFingerprint,
    };
  }

  factory WebDavSyncSettings.fromJson(Map<String, Object?> json) {
    return WebDavSyncSettings(
      endpoint: Uri.parse(json['endpoint'] as String),
      username: json['username'] as String,
      basePath: json['basePath'] as String,
      passwordRef: SecretRef(json['passwordRef'] as String),
      allowInsecureHttp: json['allowInsecureHttp'] as bool,
      enabled: json['enabled'] as bool,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      pinnedCertificateFingerprint:
          json['pinnedCertificateFingerprint'] as String?,
    );
  }

  WebDavSyncSettings copyWith({
    String? pinnedCertificateFingerprint,
    bool clearPinnedCertificateFingerprint = false,
    DateTime? updatedAt,
  }) {
    return WebDavSyncSettings(
      endpoint: endpoint,
      username: username,
      basePath: basePath,
      passwordRef: passwordRef,
      allowInsecureHttp: allowInsecureHttp,
      enabled: enabled,
      updatedAt: updatedAt ?? this.updatedAt,
      pinnedCertificateFingerprint: clearPinnedCertificateFingerprint
          ? null
          : pinnedCertificateFingerprint ?? this.pinnedCertificateFingerprint,
    );
  }
}

class WebDavSyncSettingsDraft {
  const WebDavSyncSettingsDraft({
    required this.endpoint,
    required this.username,
    required this.password,
    this.basePath = '/serlink',
    this.allowInsecureHttp = false,
    this.enabled = true,
  });

  final String endpoint;
  final String username;
  final String password;
  final String basePath;
  final bool allowInsecureHttp;
  final bool enabled;
}

class SyncSettingsException implements Exception {
  const SyncSettingsException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'SyncSettingsException($code): $message';
}

abstract interface class SyncSettingsRepository {
  Future<WebDavSyncSettings?> readWebDav();
  Future<void> saveWebDav(WebDavSyncSettings settings);
  Future<void> deleteWebDav();
}

class EncryptedSyncSettingsRepository implements SyncSettingsRepository {
  EncryptedSyncSettingsRepository({
    required VaultService vault,
    required VaultRecordRepository records,
  }) : this._(vault, records);

  EncryptedSyncSettingsRepository._(this._vault, this._records);

  static const recordType = 'sync_settings';

  final VaultService _vault;
  final VaultRecordRepository _records;

  @override
  Future<WebDavSyncSettings?> readWebDav() async {
    final envelope = await _records.read(_webDavRecordId);
    if (envelope == null) {
      return null;
    }
    final plaintext = await _vault.decryptRecord(envelope);
    return WebDavSyncSettings.fromJson(
      jsonDecode(utf8.decode(plaintext)) as Map<String, Object?>,
    );
  }

  @override
  Future<void> saveWebDav(WebDavSyncSettings settings) async {
    final envelope = await _vault.encryptRecord(
      id: _webDavRecordId,
      type: recordType,
      plaintext: utf8.encode(jsonEncode(settings.toJson())),
    );
    await _records.upsert(envelope);
  }

  @override
  Future<void> deleteWebDav() async {
    await _records.delete(_webDavRecordId);
  }
}

class SyncSettingsService {
  const SyncSettingsService({
    required SyncSettingsRepository settings,
    required SecretStore secrets,
  }) : this._(settings, secrets);

  const SyncSettingsService._(this._settings, this._secrets);

  static const _webDavPasswordRef = SecretRef('sync:webdav:password');

  final SyncSettingsRepository _settings;
  final SecretStore _secrets;

  Future<WebDavSyncSettings?> readWebDav() {
    return _settings.readWebDav();
  }

  Future<WebDavSyncSettings> saveWebDav(WebDavSyncSettingsDraft draft) async {
    final endpoint = _parseEndpoint(draft.endpoint);
    if (endpoint.scheme == 'http' && !draft.allowInsecureHttp) {
      throw const SyncSettingsException(
        'sync.webdav.insecure_http',
        'HTTP WebDAV requires explicit confirmation.',
      );
    }
    final username = draft.username.trim();
    if (username.isEmpty) {
      throw const SyncSettingsException(
        'sync.webdav.username_required',
        'Username is required.',
      );
    }

    final existing = await _settings.readWebDav();
    final password = utf8.encode(draft.password);
    final hasNewPassword = draft.password.isNotEmpty;
    if (!hasNewPassword && existing == null) {
      throw const SyncSettingsException(
        'sync.webdav.password_required',
        'Password is required for a new WebDAV account.',
      );
    }
    if (hasNewPassword) {
      await _secrets.write(_webDavPasswordRef, password);
    }

    final settings = WebDavSyncSettings(
      endpoint: endpoint,
      username: username,
      basePath: _normalizeBasePath(draft.basePath),
      passwordRef: existing?.passwordRef ?? _webDavPasswordRef,
      allowInsecureHttp: draft.allowInsecureHttp,
      enabled: draft.enabled,
      updatedAt: DateTime.now().toUtc(),
      pinnedCertificateFingerprint: _preservedCertificatePin(
        existing: existing,
        endpoint: endpoint,
        allowInsecureHttp: draft.allowInsecureHttp,
      ),
    );
    await _settings.saveWebDav(settings);
    return settings;
  }

  Future<WebDavSyncSettings> trustWebDavCertificate(
    WebDavTlsCertificateDetails certificate,
  ) async {
    final settings = await _settings.readWebDav();
    if (settings == null) {
      throw const SyncSettingsException(
        'sync.webdav.not_configured',
        'WebDAV sync is not configured.',
      );
    }
    if (settings.endpoint.scheme != 'https') {
      throw const SyncSettingsException(
        'sync.webdav.certificate_not_applicable',
        'Certificate pinning only applies to HTTPS WebDAV endpoints.',
      );
    }
    if (!_sameEndpoint(settings.endpoint, certificate.endpoint)) {
      throw const SyncSettingsException(
        'sync.webdav.certificate_endpoint_mismatch',
        'Certificate does not match the configured WebDAV endpoint.',
      );
    }
    final updated = settings.copyWith(
      pinnedCertificateFingerprint: certificate.fingerprint,
      updatedAt: DateTime.now().toUtc(),
    );
    await _settings.saveWebDav(updated);
    return updated;
  }

  Future<void> deleteWebDav() async {
    final existing = await _settings.readWebDav();
    await _settings.deleteWebDav();
    if (existing != null) {
      await _secrets.delete(existing.passwordRef);
    }
  }

  Future<WebDavSyncProvider> buildWebDavProvider() async {
    final settings = await _settings.readWebDav();
    if (settings == null) {
      throw const SyncSettingsException(
        'sync.webdav.not_configured',
        'WebDAV sync is not configured.',
      );
    }
    final passwordBytes = await _secrets.read(settings.passwordRef);
    if (passwordBytes == null) {
      throw const SyncSettingsException(
        'sync.webdav.password_missing',
        'Stored WebDAV password is missing.',
      );
    }
    return WebDavSyncProvider(
      endpoint: settings.endpoint,
      username: settings.username,
      password: utf8.decode(passwordBytes),
      basePath: settings.basePath,
      allowInsecureHttp: settings.allowInsecureHttp,
      pinnedCertificateFingerprint: settings.pinnedCertificateFingerprint,
    );
  }
}

Uri _parseEndpoint(String value) {
  final endpoint = Uri.tryParse(value.trim());
  if (endpoint == null ||
      !endpoint.isAbsolute ||
      (endpoint.scheme != 'https' && endpoint.scheme != 'http')) {
    throw const SyncSettingsException(
      'sync.webdav.endpoint_invalid',
      'WebDAV endpoint must be an absolute HTTP or HTTPS URL.',
    );
  }
  return endpoint;
}

String _normalizeBasePath(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty || trimmed == '/') {
    return '/serlink';
  }
  final withLeadingSlash = trimmed.startsWith('/') ? trimmed : '/$trimmed';
  return withLeadingSlash.endsWith('/') && withLeadingSlash.length > 1
      ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
      : withLeadingSlash;
}

final _webDavRecordId = VaultRecordId('sync:webdav');

String? _preservedCertificatePin({
  required WebDavSyncSettings? existing,
  required Uri endpoint,
  required bool allowInsecureHttp,
}) {
  if (allowInsecureHttp || endpoint.scheme != 'https') {
    return null;
  }
  if (existing == null) {
    return null;
  }
  if (!_sameEndpoint(existing.endpoint, endpoint)) {
    return null;
  }
  return existing.pinnedCertificateFingerprint;
}

bool _sameEndpoint(Uri left, Uri right) {
  return left.scheme == right.scheme &&
      left.host.toLowerCase() == right.host.toLowerCase() &&
      _effectivePort(left) == _effectivePort(right);
}

int _effectivePort(Uri uri) {
  if (uri.hasPort) {
    return uri.port;
  }
  return switch (uri.scheme) {
    'http' => 80,
    'https' => 443,
    _ => uri.port,
  };
}
