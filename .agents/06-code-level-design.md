# Code-Level Design

## Engineering Baseline

- Flutter stable.
- Dart null safety.
- Riverpod for state management.
- go_router for routing unless a simpler custom router is chosen.
- Drift + SQLite for persistence.
- `xterm` for terminal emulation UI/model.
- `dartssh2` for SSH/SFTP.
- `file_selector` for cross-platform file picking.
- Platform channels for native secure storage/iCloud/agent gaps.

## Core Domain Models

### IDs

Use typed ID value objects to avoid mixing record types:

```dart
extension type HostId(String value) {}
extension type IdentityId(String value) {}
extension type GroupId(String value) {}
extension type VaultRecordId(String value) {}
extension type SessionId(String value) {}
extension type TransferTaskId(String value) {}
```

Generate UUID v7 or ULID-like sortable IDs if a reliable package is selected; otherwise UUID v4 is acceptable.

### Host

```dart
class Host {
  final HostId id;
  final String displayName;
  final String hostname;
  final int port;
  final String? username;
  final GroupId? groupId;
  final Set<String> tags;
  final List<IdentityId> identityIds;
  final HostSshOptions sshOptions;
  final HostSftpOptions sftpOptions;
  final TerminalProfileRef terminalProfile;
  final List<PortForwardConfig> portForwards;
  final JumpHostConfig? jumpHost;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastConnectedAt;
  final bool archived;
}
```

Validation:

- `displayName` required.
- `hostname` required and trimmed.
- `port` 1-65535.
- `username` may inherit from identity or SSH config.
- Tags normalized case-insensitively for search but displayed as entered.

### Identity

```dart
sealed class IdentityAuthMaterialRef {
  const IdentityAuthMaterialRef();
}

class PortableVaultSecretRef extends IdentityAuthMaterialRef {
  final VaultRecordId recordId;
}

class DeviceSecretRef extends IdentityAuthMaterialRef {
  final String secretStoreKey;
}

class ExternalFileRef extends IdentityAuthMaterialRef {
  final String path;
}

class Identity {
  final IdentityId id;
  final String name;
  final String? username;
  final AuthMethod method;
  final IdentityAuthMaterialRef materialRef;
  final String? publicKeyFingerprint;
  final bool portable;
  final DateTime createdAt;
  final DateTime updatedAt;
}

enum AuthMethod {
  password,
  privateKey,
  sshAgent,
  keyboardInteractive,
}
```

### Connection Profile Snapshot

```dart
class ConnectionProfileSnapshot {
  final HostId hostId;
  final String hostname;
  final int port;
  final String username;
  final List<ResolvedAuthMethod> authMethods;
  final KnownHostPolicy knownHostPolicy;
  final PseudoTerminalConfig pty;
  final List<PortForwardConfig> forwards;
  final JumpHostChain? jumpHostChain;
}
```

This object is short-lived and should not be persisted.

### Workspace Tab

```dart
sealed class WorkspaceTabContent {
  const WorkspaceTabContent();
}

class TerminalTabContent extends WorkspaceTabContent {
  final SessionId sessionId;
}

class SftpTabContent extends WorkspaceTabContent {
  final SessionId sessionId;
  final String currentPath;
}

class WorkspaceTabState {
  final String tabId;
  final HostId hostId;
  final String title;
  final WorkspaceTabContent content;
  final SessionLifecycleState lifecycle;
  final WorkspaceTabFailure? failure;
  final bool hasActiveTransfer;
  final DateTime createdAt;
  final DateTime lastActivityAt;
}
```

Workspace tab requirements:

- Terminal and SFTP tabs share one tab container.
- Multiple hosts can have active tabs at the same time.
- Opening a host lets the user choose terminal, SFTP, or both.
- Unexpected disconnect never closes the tab automatically.
- Reconnect creates a new connection for the current tab.
- Full app exit does not persist or restore workspace tabs.
- Vault lock does not alter already-established SSH/SFTP sessions.
- Tab UI should expose reconnect and close actions for failed/disconnected tabs.
- Tab badges must stay sparse: connecting, disconnected, failed, or active transfer only.

### Terminal Session

```dart
class TerminalSessionState {
  final SessionId id;
  final HostId hostId;
  final SessionLifecycleState lifecycle;
  final String title;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final TerminalProfile profile;
  final SessionFailure? failure;
  final ReconnectPolicy reconnectPolicy;
}
```

### SFTP Session

```dart
class SftpSessionState {
  final SessionId id;
  final HostId hostId;
  final SessionLifecycleState lifecycle;
  final String currentPath;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final SftpFailure? failure;
  final ReconnectPolicy reconnectPolicy;
}
```

### SFTP Entry

```dart
class SftpEntry {
  final String name;
  final String path;
  final SftpEntryType type;
  final int? size;
  final DateTime? modifiedAt;
  final SftpPermissions? permissions;
  final String? owner;
  final String? group;
  final bool isHidden;
}

enum SftpEntryType { file, directory, symlink, unknown }
```

### Transfer Task

```dart
class TransferTask {
  final TransferTaskId id;
  final HostId hostId;
  final TransferDirection direction;
  final String sourceUri;
  final String targetUri;
  final int? totalBytes;
  final int transferredBytes;
  final TransferState state;
  final TransferConflictPolicy conflictPolicy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TransferFailure? failure;
}
```

Paths in durable tasks should be encrypted or stored in a sensitive local table.

## Repository Interfaces

```dart
abstract interface class HostRepository {
  Stream<List<HostSummary>> watchHosts(HostQuery query);
  Future<Host?> getHost(HostId id);
  Future<void> saveHost(Host host);
  Future<void> archiveHost(HostId id);
  Future<void> deleteHostPermanently(HostId id);
}

abstract interface class IdentityRepository {
  Stream<List<IdentitySummary>> watchIdentities();
  Future<Identity?> getIdentity(IdentityId id);
  Future<void> saveIdentity(Identity identity);
  Future<void> deleteIdentity(IdentityId id);
}

abstract interface class VaultRecordRepository {
  Future<VaultRecordEnvelope?> get(VaultRecordId id);
  Future<void> put(VaultRecordEnvelope record);
  Stream<List<VaultRecordEnvelope>> watchDirtyRecords();
}
```

## Vault Interfaces

```dart
abstract interface class VaultService {
  Stream<VaultState> watchState();
  Future<void> initialize(CreateVaultRequest request);
  Future<void> unlock(UnlockRequest request);
  Future<void> lock();
  Future<VaultRecordEnvelope> encryptRecord(VaultPlainRecord record);
  Future<VaultPlainRecord> decryptRecord(VaultRecordEnvelope envelope);
  Future<ConnectionProfileSnapshot> resolveConnectionProfile(HostId hostId);
}
```

Plain secret bytes:

- Represent with a dedicated type such as `SecretBytes`.
- Provide explicit `dispose()` or zeroing where feasible.
- Avoid converting secrets to `String` unless required by library API.

## SSH Interfaces

```dart
abstract interface class SshSessionService {
  Future<SshShellSession> openShell(ConnectionProfileSnapshot profile);
  Future<SftpConnection> openSftp(ConnectionProfileSnapshot profile);
  Future<HostKeyCheckResult> checkHostKey(ConnectionProfileSnapshot profile);
  Future<void> testConnection(ConnectionProfileSnapshot profile);
}

abstract interface class SshShellSession {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  Stream<SshSessionEvent> get events;
  Future<void> write(List<int> bytes);
  Future<void> resize({required int columns, required int rows, int? pixelWidth, int? pixelHeight});
  Future<void> close();
}
```

Implementation requirements:

- Channel reads must be streamed and batched before terminal writes.
- PTY resize must be debounced but not delayed enough to feel broken.
- SSH disconnect must complete all state transitions.
- Authentication failure must not reveal secret details.
- Unexpected disconnect must emit a typed event and leave the owning workspace tab recoverable.
- Reconnect must re-resolve host profile and credentials from the vault, then open a new SSH/SFTP connection in the current tab.
- If the vault is locked during reconnect, prompt unlock before resolving credentials.

## Terminal Adapter

```dart
abstract interface class TerminalAdapter {
  TerminalControllerHandle create(TerminalProfile profile);
  void attach(SessionId sessionId, SshShellSession shell);
  void detach(SessionId sessionId);
  void writeInput(SessionId sessionId, List<int> bytes);
  Stream<TerminalEvent> events(SessionId sessionId);
}
```

Responsibilities:

- Bridge `xterm` terminal model to SSH channel streams.
- Apply theme/profile.
- Handle resize callbacks.
- Detect zmodem sequences and route to zmodem service.
- Keep UI widgets independent from SSH library details.

## Zmodem Design

```dart
abstract interface class ZmodemService {
  Stream<ZmodemEvent> detect(SessionId sessionId, Stream<List<int>> terminalBytes);
  Future<TransferTaskId> acceptDownload(ZmodemOffer offer, LocalPath target);
  Future<TransferTaskId> startUpload(SessionId sessionId, List<LocalPath> files);
  Future<void> cancel(ZmodemTransferId id);
}
```

Implementation phases:

1. Add stream detector around terminal bytes.
2. Show UI prompt when rz/sz sequence appears.
3. Transfer through same `TransferQueueController`.
4. Add integration tests with `lrzsz`.

Rules:

- If detection is uncertain, pass bytes through unchanged.
- Zmodem UI must not block terminal indefinitely.
- Cancellation must restore terminal stream cleanly where possible.

## SFTP Interfaces

```dart
abstract interface class SftpConnection {
  Future<List<SftpEntry>> list(String path);
  Future<void> mkdir(String path);
  Future<void> rename(String oldPath, String newPath);
  Future<void> deleteFile(String path);
  Future<void> deleteDirectory(String path, {required bool recursive});
  Future<void> chmod(String path, SftpPermissions permissions);
  Stream<TransferProgress> upload(LocalPath source, String remotePath, TransferOptions options);
  Stream<TransferProgress> download(String remotePath, LocalPath target, TransferOptions options);
  Future<void> close();
}
```

Requirements:

- All file operations return typed failures.
- Transfers stream data in chunks.
- Directory listings sort directories first by default.
- Hidden files are toggleable.
- Symlink behavior is explicit.

## Sync Interfaces

```dart
abstract interface class SyncOrchestrator {
  Stream<SyncState> watchState();
  Future<SyncRunSummary> syncNow(SyncAccountId accountId);
  Future<void> pause(SyncAccountId accountId);
  Future<void> resume(SyncAccountId accountId);
}

abstract interface class SyncMergeEngine {
  Future<SyncMergePlan> plan(SyncSnapshot local, SyncSnapshot remote);
  Future<void> apply(SyncMergePlan plan);
}
```

Sync run stages:

- Load provider.
- Read remote manifest.
- Load local encrypted records.
- Plan merge.
- Download remote changes.
- Store local changes.
- Upload local changes.
- Write manifest.
- Mark checkpoint.

## Data Exchange

### OpenSSH Config Importer

```dart
abstract interface class SshConfigImporter {
  Future<SshConfigImportPreview> preview(String rawConfig, ImportOptions options);
  Future<SshConfigImportResult> import(SshConfigImportPreview preview);
}
```

Support:

- `Host`
- `HostName`
- `User`
- `Port`
- `IdentityFile`
- `Include` with preview warnings when expansion is not supported
- `Host *` inheritance
- wildcard hosts where safe
- `ProxyJump`
- `ProxyCommand` as deferred/manual review
- `ForwardAgent`
- `LocalForward`
- `RemoteForward`
- `CertificateFile` as unsupported/deferred warning unless OpenSSH certificate auth is implemented
- `IdentityAgent` as unsupported/deferred warning unless SSH agent support is implemented

Unsupported directives should be preserved as warnings, not silently ignored.

Known hosts import must preserve or warn on security-relevant entries:

- hashed hostnames
- `@cert-authority`
- `@revoked`
- multiple hostnames per entry
- custom known-host files

### Private Key Importer

```dart
abstract interface class PrivateKeyImporter {
  Future<KeyImportPreview> preview(KeySource source);
  Future<Identity> import(KeyImportPreview preview, KeyImportStorageChoice choice);
}
```

### Exporters

```dart
abstract interface class VaultBackupExporter {
  Future<ExportPreview> preview(ExportVaultBackupRequest request);
  Future<ExportResult> export(ExportVaultBackupRequest request, ExportConfirmation confirmation);
}

abstract interface class HostMetadataExporter {
  Future<ExportPreview> preview(ExportHostMetadataRequest request);
  Future<ExportResult> export(ExportHostMetadataRequest request, ExportConfirmation confirmation);
}
```

Export requirements:

- All export flows produce a preview before writing files.
- Sensitive exports require a modal confirmation token.
- Encrypted vault backup export must clearly report encryption status and recovery requirements.
- Diagnostic bundle export must redact hostnames, usernames, paths, commands, and secrets by default.

## Modal Confirmation Interfaces

```dart
abstract interface class SecurityModalService {
  Future<HostKeyTrustDecision> confirmHostKey(HostKeyPrompt prompt);
  Future<ExportConfirmation?> confirmExport(ExportPreview preview);
  Future<bool> confirmDestructiveAction(DestructiveActionPrompt prompt);
  Future<bool> confirmMultilinePaste(MultilinePastePrompt prompt);
}
```

Rules:

- SSH host key verification must call `confirmHostKey` before trusting unknown or changed fingerprints.
- Exporters must require `ExportConfirmation` before writing sensitive output.
- Modal prompts should receive redacted/safe display data only.
- Services should not directly render dialogs; controllers request confirmation through the modal service.

## State Management Requirements

Use Riverpod providers by feature:

- Repositories as app-scoped providers.
- Services as app-scoped providers.
- Controllers as route/session scoped providers.
- Terminal session controllers must be disposable.
- Transfer queue is app-scoped and survives view navigation.
- Workspace tab controller is app-scoped and owns terminal/SFTP tab ordering, active tab, close prompts, and reconnect actions.

Example:

```dart
final hostRepositoryProvider = Provider<HostRepository>((ref) {
  return DriftHostRepository(ref.watch(databaseProvider), ref.watch(vaultServiceProvider));
});

final terminalSessionControllerProvider =
    AutoDisposeAsyncNotifierProviderFamily<TerminalSessionController, TerminalSessionState, HostId>(
  TerminalSessionController.new,
);
```

## Database Requirements

Migration rules:

- Every schema change has an explicit migration.
- Encrypted record schema version is separate from SQLite schema version.
- Migrations must not require decrypting all records unless unavoidable.
- Backup before destructive migration.

Tables:

```text
vault_records(
  id text primary key,
  type text not null,
  schema_version integer not null,
  revision text not null,
  updated_at integer not null,
  tombstone integer not null,
  nonce blob not null,
  aad blob not null,
  ciphertext blob not null,
  dirty integer not null
)

host_index(
  host_id text primary key,
  display_name_enc blob not null,
  searchable_hash blob,
  group_id text,
  last_connected_at integer,
  archived integer not null
)

sync_accounts(...)
sync_checkpoints(...)
transfer_tasks(...)
settings(...)
```

## Error Codes

Examples:

- `vault.locked`
- `vault.passphrase_invalid`
- `vault.record_tampered`
- `secret_store.unavailable`
- `ssh.connection_timeout`
- `ssh.auth_failed`
- `ssh.host_key_unknown`
- `ssh.host_key_changed`
- `sftp.permission_denied`
- `transfer.conflict`
- `sync.provider_unreachable`
- `sync.conflict`
- `sync.vault_mismatch`
- `import.unsupported_key_format`
- `export.confirmation_required`
- `export.redaction_failed`
- `runtime.unhandled_async_error`

Error messages must be localized-ready: stable code + parameterized display string.

## Runtime Modes And Crash Resilience

```dart
enum SerlinkRuntimeMode {
  debug,
  profile,
  release,
}

class RuntimeCapabilities {
  final SerlinkRuntimeMode mode;
  final bool verboseRedactedLogging;
  final bool crashReporting;
  final bool unsafeDiagnosticsAllowed;
}
```

Implementation requirements:

- Wrap app bootstrap with guarded async error handling.
- Route Flutter framework errors, platform dispatcher errors, zone errors, and stream errors into a redacted `CrashBoundaryService`.
- Release builds must contain session/task failures and show typed recovery UI instead of terminating the app.
- Debug builds should provide verbose redacted logs and clear developer-facing error messages through normal logs, not an in-app debug panel.
- Release builds must disable unsafe diagnostics and avoid logging terminal output, commands, hostnames, usernames, file paths, private keys, passwords, and passphrases.
- Profile builds may enable performance counters but must keep privacy redaction equivalent to release.
- Every long-running SSH, SFTP, sync, transfer, and terminal stream must report failures through typed state rather than uncaught exceptions.

## Feature Flags

Initial flags:

- `enableICloudSync`
- `enableSshAgent`
- `enableZmodem`
- `enablePortForwarding`
- `enableJumpHosts`
- `enableTerminalSplits`
- `enableCrashDiagnostics`

Use flags to ship unstable platform-specific capabilities safely.

## Code Quality Rules

- No UI widget should directly call `dartssh2`.
- No UI widget should directly decrypt records.
- No plaintext secret should be stored in app state longer than needed.
- No provider implementation should know host model internals.
- No sync provider should receive plaintext.
- No terminal emulator detail should leak into host repository.
- All async controllers must handle cancellation/dispose.
- All long-running streams must be closed on session end.

## Minimum Test Doubles

Create fakes early:

- `FakeSecretStore`
- `FakeVaultService`
- `FakeSshSessionService`
- `FakeSftpConnection`
- `FakeSyncProvider`
- `MemoryVaultRecordRepository`
- `FakeTerminalAdapter`

These fakes allow UI and merge tests without real servers.
