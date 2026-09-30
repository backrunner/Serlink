# Encryption implementation inventory

Verified against the source on 2026-09-30. This is technical input for the
App Store Connect questionnaire, not a completed export declaration.

| Use | Implementation |
| --- | --- |
| Vault records and key protectors | XChaCha20-Poly1305 AEAD from Dart `cryptography`; Argon2id for passphrase derivation and HKDF/HMAC-SHA256 for derived keys. See `lib/features/vault/application/in_memory_vault_service.dart`. |
| SSH and SFTP | Dart `dartssh2`, with negotiated standard SSH encryption and authentication. Actual interoperability checks cover AES-GCM, ChaCha20-Poly1305, CTR and CBC plus password, private-key and keyboard-interactive authentication. SFTP uses the SSH transport. |
| SSH key generation | Ed25519 and RSA through `cryptography` and `pointycastle`; see `ssh_key_pair_generator.dart`. |
| WebDAV | TLS transport plus encrypted vault snapshots; certificate validation and optional pinning are implemented by the sync provider. |
| iCloud | CloudKit private database stores encrypted snapshot objects. Keys are not uploaded by the sync service. |
| Local biometric protector | Apple Keychain/LocalAuthentication gates a device-local random key; vault passphrases are not stored. |

Serlink contains app/library cryptography in addition to Apple OS facilities.
It is therefore inaccurate to answer that all encryption is provided solely
by the operating system. No new proprietary encryption algorithm is introduced
by the app. Record the actual features and standard algorithms in the current
questionnaire, then follow the documents it requests for the chosen territories.
Do not assume SSH/TLS automatically makes the separate vault encryption exempt.

The repository does not provide a confirmed CCATS number, French declaration,
or approved encryption code. Leave these values unset until established by the
account holder's applicable declaration. Do not insert
`ITSAppUsesNonExemptEncryption=false` simply to suppress the questions.

Current references:

- [Apple export compliance overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance)
- [Apple encryption documentation requirements](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption/)
- [Apple encryption export guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
