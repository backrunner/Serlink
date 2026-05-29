import 'package:flutter_test/flutter_test.dart';
import 'package:serlink/core/ids/entity_id.dart';
import 'package:serlink/features/identities/application/identity_repository.dart';
import 'package:serlink/features/identities/domain/identity.dart';
import 'package:serlink/features/import_export/application/identity_metadata_export_service.dart';

void main() {
  test('exports public identity metadata without secret references', () async {
    final identities = [
      _identity(
        id: 'cert',
        displayName: 'Deploy Certificate',
        kind: IdentityKind.openSshCertificate,
        usernameHint: 'deploy',
        publicKeyFingerprint: 'SHA256:abc',
        certificatePrincipal: 'deploy@example',
      ),
      _identity(
        id: 'key',
        displayName: 'Ops Key',
        kind: IdentityKind.privateKey,
        usernameHint: 'ops',
      ),
    ];
    final service = IdentityMetadataExportService(
      identities: _FakeIdentityRepository(identities),
      now: () => DateTime.utc(2026, 5, 29, 12, 0),
    );

    final bundle = await service.export();
    final restored = IdentityMetadataExportBundle.fromBytes(bundle.toBytes());

    expect(restored.formatVersion, 1);
    expect(restored.identities, hasLength(2));
    expect(restored.identities.map((identity) => identity.displayName), [
      'Deploy Certificate',
      'Ops Key',
    ]);
    expect(restored.identities.first.publicKeyFingerprint, 'SHA256:abc');
    expect(restored.identities.first.certificatePrincipal, 'deploy@example');
    expect(restored.toJson().toString(), isNot(contains('secretRecordId')));
  });
}

IdentityConfig _identity({
  required String id,
  required String displayName,
  required IdentityKind kind,
  String? usernameHint,
  String? publicKeyFingerprint,
  String? certificatePrincipal,
}) {
  return IdentityConfig(
    id: IdentityId(id),
    displayName: displayName,
    kind: kind,
    usernameHint: usernameHint,
    publicKeyFingerprint: publicKeyFingerprint,
    certificatePrincipal: certificatePrincipal,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
}

class _FakeIdentityRepository implements IdentityRepository {
  _FakeIdentityRepository(List<IdentityConfig> identities)
    : _identities = {for (final identity in identities) identity.id: identity};

  final Map<IdentityId, IdentityConfig> _identities;

  @override
  Future<void> delete(IdentityId id) async {
    _identities.remove(id);
  }

  @override
  Future<List<IdentityConfig>> list() async {
    return _identities.values.toList();
  }

  @override
  Future<IdentityConfig?> read(IdentityId id) async {
    return _identities[id];
  }

  @override
  Future<void> save(IdentityConfig identity) async {
    _identities[identity.id] = identity;
  }
}
