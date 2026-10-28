# macOS privacy declaration

The next macOS submission must disclose optional TypeSafe command protection.
The local proposal in `metadata.json` and `macos/Runner/PrivacyInfo.xcprivacy`
uses **Data Linked to You**. It has not been applied to App Store Connect.

## Data flow and proposed answers

Protection is off by default. The user supplies a TypeSafe API key, explicitly
agrees to complete-command sharing and enables the feature. Only then does
Serlink send agent commands to `https://api.typesafe.ai/v1/systemone`, with the
key in the authorization header. Commands may contain arbitrary personal or
secret text. The app does not attach a vault record, screen buffer or command
output object. The developer receives none of those requests.

| App privacy category | Linked to user | Purpose | Basis |
| --- | --- | --- | --- |
| User Content / Other User Content | Yes | App Functionality | Complete agent-command text; conservatively allow for provider retention |
| Identifiers / User ID | Yes | App Functionality | Requests authenticate to the user's TypeSafe account; no de-identification guarantee |
| Usage Data / Product Interaction | Yes | App Functionality, Analytics | API request usage/billing and provider service telemetry |

Tracking is false. There is no advertising SDK, developer telemetry upload or
cross-company advertising identifier in this integration. This proposal does
not declare the entire encrypted vault as uploaded to TypeSafe. Provider
account registration/payment happens outside Serlink; Serlink does not collect
that registration or payment form.

These are conservative declarations for the integration's normal account terms,
not evidence that every request is retained or that every provider account has
identical terms. Do not change to **Data Not Collected** based solely on BYOK,
opt-in, no-training language or one user's enterprise ZDR arrangement. Apple's
definition concerns retention beyond servicing a request in real time. TypeSafe
does not establish universal zero retention for arbitrary user-supplied keys.
An account-specific agreement can support a different assessment only for the
data flows and accounts it actually covers.

## Consent and local storage

- Consent is device-local and versioned alongside the model configuration.
  Previously enabled configurations without current consent block requests
  until the user renews it. No vault or remote-sync schema is changed.
- Turning protection off stops model calls. Users can withdraw consent in the
  same dialog; removing the key also clears consent. Local hard-block rules
  remain available when cloud protection is off.
- The API key is stored locally and transmitted to TypeSafe for authentication.
  It is excluded from vault sync, backups and diagnostic logs. Local storage
  does not mean the key is never transmitted.
- MCP discovery requires separate revocable consent. Existing connections need
  their own grant, including existing history. External agents may send shared
  content onward under their configuration and provider policies. Those agents
  are configured by the user and are separate from Serlink's TypeSafe request.

## Before submission

Apply these categories/purposes/linkage answers to App Store Connect and publish
the corresponding English, Chinese and Japanese privacy policies. Validate the
exported app's bundled manifest. Keep a limited TypeSafe review key in the
private reviewer supplement so optional protection is reviewable without a
purchase. The source change does not provision that key, publish the website,
change Apple's saved privacy answers or establish Apple approval.

Reassess if provider terms or the payload change. Secret text embedded in a
command is not automatically redacted; keep that fact visible in consent.

## Primary sources

- [Apple app privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)
- [Apple privacy-manifest data categories](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
- [TypeSafe retention guidance](https://help.typesafe.ai/articles/5974925716-how-is-submitted-data-used-or-retained)
- [TypeSafe legal and ZDR documentation](https://docs.typesafe.ai/legal)
- [TypeSafe privacy policy](https://typesafe.ai/legal/privacy-policy)

Checked 2026-10-29. This is an engineering declaration proposal for the current
integration; App Store Connect remains the authoritative saved submission.
