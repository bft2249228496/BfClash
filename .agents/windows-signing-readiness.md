# Windows trusted signing readiness

## Current status

No trusted signing identity/backend is configured. This integration cannot create a trusted certificate, recover the user's blocked1711, or prove Smart App Control compatibility without an authorized service and real Windows verification. Do not release another unsigned repair claiming this blocker is fixed.

## Implemented Core/Helper stage

Opt-in with BFCLASH_WINDOWS_SIGNING_REQUIRED=true on a Windows build host. Missing/invalid signing configuration fails closed. Required inputs: BFCLASH_SIGNTOOL (SDKSignTool path), BFCLASH_SIGNING_DLIB (official ArtifactSigning client DLL path), BFCLASH_SIGNING_METADATA (official metadata JSON path), BFCLASH_SIGNER_SUBJECT (authorized exact public certificate subject). Authentication stays in the authorized managed environment; no PFX/password/private-key export or self-signed root installation is used.

GoBuilder signs the staged Core before replacing its previous output and before cache metadata is recorded. buildPlatform verifies that signed Core, then computes the final SHA256. RustBuilder compiles Helper against that SHA, signs a staged helper preserving the .exe extension, then replaces its output atomically. Signed Helper is verified before the manifest is written. Signing configuration and signing input hashes participate in both fingerprints; cache hits are signature-verified again. Signing failure cannot silently create an unsigned successful build.

The PowerShell backend uses Microsoft's SignTool/dlib metadata flow, SHA256 and RFC3161 timestamping, then verifies Authenticode trust, timestamp presence, exact authorized publisher and RSA identity. The endpoint is restricted to HTTPS ArtifactSigning Azure endpoints. This script has not been executed with a real signing account and must not be represented as a completed trusted release.

## Remaining required stages

- Obtain an authorized identity/account/profile and configure it without sharing private keys or passwords in chat. No account creation, purchase or external application submission is authorized by this file.
- Verify the backend on real Windows with that identity; reject wrong publisher/untrusted/missing timestamp/failing service responses.
- Validate the new staged whole-payload signing path against the real backend. It scans PE content (including app.so), preserves signed Core/Helper bytes and signs unsigned payloads. Existing trusted timestamped third-party signatures are retained. No real backend run has occurred.
- Validate new Inno automatic uninstaller/installer signing and callback receipts on the authorized Windows build host. Final hashes are written only after both callbacks and final installer verification; actual installed uninstaller verification remains required.
- Replace unsigned-only updater/installer refusal with actual verified trusted-signature handling for the signed distribution. Do not remove protection merely to permit another unsigned package.
- Run packaged Helper/Core hash validation and actual startup/TUN/exit on the user's enforced-policy device, followed by remaining complete UI/update/feature acceptance.

## Tests and limits

The portable order fixture uses real tiny Go and Rust builds with an explicitly fake marker signer. It verifies that the compiled helper prints the final Core hash, signed output cache reuse, profile-change invalidation and preservation of prior artifacts when Core signing fails. It cannot prove Authenticode or real signing authorization. Existing cache tests remain independent.

Official integration references: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations and https://github.com/Azure/artifact-signing-action .

## Hook cache and entrypoint

Use `dart setup.dart windows` for this signing path. It stamps only public signing configuration and content digests into the setup hook user defines, then restores pubspec in finally. Native hooks strip arbitrary environment variables and do not invalidate their outer cache on environment changes; reading BFCLASH variables only inside the hook would therefore be unsafe. The hook receives this explicit input and forwards the required public variables to the signing subprocess. Changes to signing mode, publisher, tools, metadata or script alter hook inputs. Direct Flutter builds do not configure this signing entrypoint and are not trusted release commands. Authentication must be available via the authorized managed host identity/credential store; no secrets are written into user defines.

## Signed packaging entrypoint implementation

`setup.dart windows` now branches to an explicit signed packager when trusted signing is required. It builds Flutter, renders the existing stable/beta installer template using the same Liquid renderer, stages files into a unique dist directory, checks channel/required runner/Flutter/AOT/Node files and the signed Core manifest, and signs/verifies PE payloads without changing Core/Helper. The compiler is invoked with an explicit named signer and SignedUninstaller=yes. Signature receipts from Inno callbacks and final installer verification are required before EXE/ZIP/signature proof move into dist. Staging is deleted on failure. No installation or release upload is performed by this command.

Unsigned default builds retain the policy refusal. The trusted compile define is used only after staged payload verification and requires the compiler signing command; without that command compilation must fail. Whole-build test coverage includes rendering both identities, original lifecycle/entry sections and rejection of an unknown architecture; actual Artifact Signing and enforced-device startup are not established by those tests. The current in-app unsigned-update preflight still conservatively blocks under enforcement; signature-aware updates are a remaining stage and must not be bypassed based solely on a new filename or compile flag.
