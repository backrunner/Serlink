# SSH agent authentication

Serlink connects to any local agent implementing the SSH agent protocol. There
are no provider-specific API calls or private-key exports. This covers password
manager agents, OpenSSH agents, and agents backed by hardware or smart cards.

## Configuration

Select **Agent** when adding a host, or create an **SSH Agent** credential in the
credential manager. Open **SSH agent provider** to list all discovered reachable
agents, including the system agent. Every result shows an application name
when available (otherwise a location-derived identifier), endpoint and public-key
count. Users always confirm the
provider, even when only one is found; **Search again** refreshes the inventory
without changing the current selection. Custom endpoints remain available in a
secondary field inside the provider options menu. Choosing a different provider
resets the old key selection in
the unsaved form; cancelling preserves the original provider and key.

**Choose key** first asks for a provider when none is selected, then lists only
that provider's keys. The selected endpoint is saved with the credential.

Discovery starts with `SSH_AUTH_SOCK` (and `launchctl getenv SSH_AUTH_SOCK` for
macOS GUI launches), or the local OpenSSH named pipe on Windows. On Unix it
also checks socket metadata in bounded user home/config/cache/runtime and
generic macOS app-container locations. macOS additionally supplies the real
user home and application-group paths from public installed/running application
metadata, including code-signing entitlements. Direct checks of common IPC
filenames work even when enumerating a container parent is unavailable; no
vendor identifier or provider API is hardcoded. Display names come from bundle
metadata when available. Up to 512 native roots supplement directory discovery.
It follows no directory symlinks, reads
no private files, executes no SSH config commands, and uses no vendor IDs.
Candidates must answer a bounded SSH agent public-identity request; stale,
invalid, or unresponsive sockets are ignored. Safe discovery diagnostics record
counts and error types/codes, without paths, identity names or key material.
Scanning is limited to 160
directories, 2,400 entries, and 32 candidates, with four concurrent probes.
Arbitrary custom locations may still require a manual endpoint.

Legacy credentials without a saved endpoint can resolve a sole discovered
provider or a provider uniquely identified by their selected public key.
Multiple providers require an explicit choice; the system agent has no
selection priority, including when it has no keys. Explicit endpoints never
fall back to another agent on failure. Enumeration results are reused and the
signing endpoint stays pinned for that connection.

Enter a Unix socket path or a local Windows named pipe to use another
compatible agent. A leading `~/` is expanded
using the current device's home directory. Endpoints are interpreted locally;
an endpoint synced from another device may need to be changed on that device.

The optional public-key file selects the matching key instead of offering all
agent identities. This helps avoid servers' authentication-attempt limits.
**Choose key** lists the agent's public identity names and SHA-256
fingerprints inside Serlink, so users can select a specific key without an
export or clipboard operation. The same picker works with any compatible agent.
Only public material is imported. Private keys and approval UI stay with the
agent. Serlink probes the public key before requesting a signature, and performs
local IPC signing outside the Flutter event loop so approval does not freeze UI.

Authentication diagnostics record candidate/probe counts and signing request/
success counts in `ssh.auth.summary`. They do not log key blobs, key comments,
signing payloads, signatures, passwords, or private keys. A failed connection
with no signing requests means the probe stage did not reach an external signer.

The SSH config importer currently warns about `IdentityAgent` rather than
importing its endpoint. Configure Agent authentication after importing such a
host. Serlink does not execute `ProxyCommand` or shell expressions from config.

## Hardware keys

Create a **Hardware Key** credential after loading the key into an appropriate
SSH agent. OpenSSH FIDO2 `sk-ssh-ed25519@openssh.com` and
`sk-ecdsa-sha2-nistp256@openssh.com` public keys and signatures are passed through
without removing their application, user-presence flags, or signature counters.
Smart-card/PIV/PKCS#11 keys work through agents which expose them as ordinary
RSA/ECDSA identities. Serlink does not infer hardware provenance from a public
key, enroll devices, or load PKCS#11 providers itself. PIN entry, touch, biometric
approval, and provider selection belong to the agent.

## User certificates

A **Certificate** credential can use either an imported private key or an SSH
agent. For the agent option, import the OpenSSH user certificate and load its
matching private key into the chosen agent. The certificate's underlying public
key is matched against agent identities before signing; an unrelated key is
rejected. The certificate is presented to the SSH server while the agent signs
the authentication challenge. The agent need not store the certificate itself.
RSA certificates use SHA-256 authentication/signatures rather than SHA-1.
The SSH server validates the CA signature, certificate validity, principals,
and certificate options.

Agent configuration is optional identity metadata. Existing identities retain
their behavior when the field is absent. Agent-backed certificates store the
certificate in the encrypted credential record, with no private key/passphrase.
No remote or local schema version change is needed for these optional fields.

## Availability and evidence

Local agents are enabled for direct desktop distributions on macOS, Linux, and
Windows. iOS and macOS App Store builds keep this feature unavailable because
the existing sandbox does not grant access to arbitrary local agent endpoints.

Unit tests cover agent filtering, endpoint selection, hardware wire formats,
certificate matching, and vault persistence. The opt-in native test creates a
disposable OpenSSH agent and CA-signed Ed25519/RSA keys, deletes the source
private files, then cryptographically verifies agent signatures:

```sh
SERLINK_TEST_LOCAL_AGENT=1 flutter test \
  test/features/ssh/data/ssh_agent_integration_test.dart --concurrency=1
```

This verifies OpenSSH agent interoperability on the machine running the test.
It does not certify a particular password manager's authorization UI, a physical
security key, a Windows named-pipe runtime on macOS, or a full SSH server login.

Protocol references:

- [SSH Agent Protocol (RFC 9987)](https://www.rfc-editor.org/rfc/rfc9987.html)
- [OpenSSH FIDO/U2F formats](https://github.com/openssh/openssh-portable/blob/master/PROTOCOL.u2f)
