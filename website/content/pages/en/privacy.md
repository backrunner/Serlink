---
title: "Privacy policy"
description: "How the app and this website handle information."
---

Effective date: 30 September 2026


Serlink is an SSH terminal and SFTP workspace. The app does not require a Serlink account. This policy describes the app's current data handling.




## Your local workspace


Host profiles, credential material, snippets and workspace records are stored in an encrypted local vault. Device-local secrets use the operating system's secure storage. Optional biometric unlock protects a random device key; the vault passphrase is not saved by that feature. Serlink does not receive biometric templates.


Terminal data is used to display your remote session. Downloaded files and exported plaintext metadata are stored where you select them; those files are not covered by vault encryption. Protect your exported files separately. Locking the vault prevents new credential access but does not disconnect already-established SSH/SFTP sessions or transfers.




## Servers and optional sync


When you connect, authentication data, commands and files are sent to your chosen SSH/SFTP server. The server operator can process that data under its own policies. The app does not relay those connections through a Serlink-operated service.


iCloud sync uses Apple's CloudKit private database. WebDAV sync uses an endpoint you configure. Sync uploads encrypted vault snapshots and operational object metadata; the app's vault keys are not uploaded by the sync service. Apple or your WebDAV operator may process service and connection metadata under their policies. Disabling sync stops future app sync; it does not erase existing remote copies.




## Diagnostics and external agents


Serlink has no advertising or analytics SDK and does not automatically upload diagnostic logs to its developer. Diagnostic exports are local, redact sensitive connection information and omit terminal output. If you send an export to support, review the files and remove anything private first.


The optional MCP endpoint permits an external agent to use explicitly authorized sessions. Model command protection is off by default. If you configure your own TypeSafe API key and enable it, Serlink sends the commands submitted by agents to TypeSafe for risk assessment; it does not include host records, SSH credentials, terminal screens or command output in these requests. The API key and protection settings stay in device-local secure storage and are not included in vault sync or backups. TypeSafe processes these requests under its own service and privacy policies. An agent you authorize may separately transmit data according to that agent's configuration and provider policies.




## Control, retention and deletion


You control host records, credentials, snippets, backups, exported files, sync destinations and agent authorizations. Local records remain until you delete or reset them. Remote data and backups have separate lifetimes: use the remote-data controls or your provider to delete them, and remove exports and backups separately. Keep recovery keys safe; the developer cannot recover an unknown vault passphrase without your recovery key.




## Contact and updates


For privacy questions, use the contact published on the [support page](/support). This policy will be updated if the app's data handling changes.



## This website and support

This website at **serlink.alkinum.com** serves static pages and product images. Documentation search runs in your browser. It contains no analytics, advertising pixels, account system or remote font requests. The host still receives requests for pages and assets and may process network metadata to deliver and secure the service. Your theme preference is saved in browser local storage; clearing site data removes it.

The support form sends your email address, selected topic, subject, message, language and any optional app/device information to our OnFire support system hosted on Cloudflare. Authorized staff use them to handle your request. The form has no file upload and does not access diagnostics, terminal output or vault data automatically. Cloudflare Turnstile processes browser, device and network signals to prevent abuse; we also use IP addresses to limit attempts. Keep credentials and recovery material out of messages. Use the support form to request access or deletion of support records; we may need to verify your request. Records are kept as needed to resolve requests and meet legal obligations.

GitHub links lead to an external service governed by its own policy. GitHub issues are public; use the support form for private security or privacy reports.
