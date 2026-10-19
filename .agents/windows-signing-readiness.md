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
- Sign/verify the Flutter runner and every executable/DLL payload after build and before packaging. Do not alter Core after Helper compilation.
- Sign the uninstaller through Inno and verify it, then sign/verify the final installer; calculate ZIP/installer release hashes only after all signing steps.
- Replace unsigned-only updater/installer refusal with actual verified trusted-signature handling for the signed distribution. Do not remove protection merely to permit another unsigned package.
- Run packaged Helper/Core hash validation and actual startup/TUN/exit on the user's enforced-policy device, followed by remaining complete UI/update/feature acceptance.

## Tests and limits

The portable order fixture uses real tiny Go and Rust builds with an explicitly fake marker signer. It verifies that the compiled helper prints the final Core hash, signed output cache reuse, profile-change invalidation and preservation of prior artifacts when Core signing fails. It cannot prove Authenticode or real signing authorization. Existing cache tests remain independent.

Official integration references: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations and https://github.com/Azure/artifact-signing-action .

## Hook cache and entrypoint

Use `dart setup.dart windows` for this signing path. It stamps only public signing configuration and content digests into the setup hook user defines, then restores pubspec in finally. Native hooks strip arbitrary environment variables and do not invalidate their outer cache on environment changes; reading BFCLASH variables only inside the hook would therefore be unsafe. The hook receives this explicit input and forwards the required public variables to the signing subprocess. Changes to signing mode, publisher, tools, metadata or script alter hook inputs. Direct Flutter builds do not configure this signing entrypoint and are not trusted release commands. Authentication must be available via the authorized managed host identity/credential store; no secrets are written into user defines.
