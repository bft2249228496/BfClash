# Windows feature acceptance against Android

A shared implementation is not acceptance. Every row needs an accessible Windows entry, complete behavior, failure feedback, persistence, and evidence from a packaged Windows build. This list is an active audit, not a completion claim.

| Android capability | Windows implementation / entry | Current evidence and remaining work |
| --- | --- | --- |
| Start/stop and internet proxy | Desktop dashboard, core lifecycle, system proxy/TUN | Installed1321 manual start verified: BfCore49412 exclusively7890, Party absent, system proxy enabled, Google204/YouTube200/movies303 and independent Edge system-proxy Google passed. Long-duration browsing and repeated start/stop remain pending |
| Rules/global/direct, node selection and delay | ProxiesView and dashboard | Shared UI present; device mode/node/delay checks pending |
| Profile import/edit/refresh/switch and overrides/scripts | ProfilesView and config views | Source paths present; real import/edit/restart/failure checks pending |
| DNS, ports, rules, providers and resources | ConfigView, AdvancedConfigView, ResourcesView | Resources desktop entry restored in this change; operation/restart checks pending |
| Language/theme/application settings | LocaleSettingItem, ThemeView, ApplicationSettingView | Missing desktop language entry restored in this change; device persistence check pending |
| Requests, connections, traffic and logs | Desktop navigation and logs setting | Entries present; user-generated traffic and connection controls pending |
| Local backup and restore | BackupAndRestore / backup actions | Installed1321 UI export saved successfully; archive readable, JSON valid, SQLite integrity_check ok, all19 profile hashes match live files. Restore roundtrip pending |
| WebDAV backup and restore | BackupAndRestore | User account reachability observed, full Windows backup/restore roundtrip pending |
| Remote Sub-Store | SubStoreView | Source path present; actual remote transform/import pending |
| Local Sub-Store | SubStoreBackendService | Build now packages pinned Node22.23.3 plus official2.39.8 Node backend with SHA256 verification; packaged health CI added; correct Node health endpoint verified locally; Windows beta/stable use3002/3001 with data in channel-specific home; packaged Windows CI, device transform/import and shutdown regression pending |
| Check/download/install update | CommonAction / Windows update downloader | Request-failure reporting fixed; current change adds verified Windows asset/download/install flow; Windows execution/upgrade acceptance pending |
| Platform routing controls | Android per-app VPN vs Windows rules/TUN/process rules | Equivalent user outcomes must be audited; Android-only permission UI is not a Windows implementation |
| Startup/background/tray/shortcuts/window restore | ApplicationSettingView and desktop window/tray managers | Shortcuts restored; window geometry tests pass; packaged restart/tray/startup checks pending |
| Stable/beta coexistence and uninstall | ChannelConfig / Inno / core-helper IPC | Package identities and beta preferences migration proved; full two-install service/update/uninstall regression pending |
| Signed release distribution | Windows packaging/release workflow | BLOCKED: public38689950646 unsigned installer blocked by enabled Smart App Control, events3077/3033; need trusted signing setup |

Latest installed device version is0.2.27-beta.1321+1321 fromCI38695657109, manually installed by user. EarlierCI38689950646 installer was blocked by application control; this does not describe the current installed package. Do not equate CI/build success, source presence or a single network probe with full feature acceptance.

Windows CI packages now stamp the source base version with a distinct beta/build number from the workflow run and attempt. The source pubspec is restored after packaging, keeping the Android release version unchanged. CI verifies the EXE numeric build field and beta ProductVersion as well as update asset compatibility.

Desktop application exit now stops its owned local Sub-Store backend through the existing exit cleanup coordinator; idle local endpoint fallback also uses the correct channel port. Windows packaged lifecycle regression remains pending.

2026-10-15 device Sub-Store integration: installed1321 UI start launched app-owned Node30332/3002; health success, synthetic subscription create/list/ClashMeta conversion passed and test record deleted. UI stop removed Node/3002 while Bf proxy49412/7890 and external access stayed working. Official frontend and app import are not yet accepted. CI38704330230 explicitly passed stable/beta packaged health, conversion and restart persistence. Source4a2ae781 removes Android-only local backend wording; its CI remains pending.

2026-10-15 installer regression: source64ff2c5f defers Helper removal until usUninstall. CI38741441432 on a403ea00 compiled a minimal installer using production Code and a marker-only fake Helper. Actual Windows execution confirmed aborted initialization preserves Helper/appfiles, and confirmed uninstall invokes Helper exactly once before removing files. This proves installer event sequencing in an isolated CI fixture, not full packaged service cleanup, channel coexistence or uninstall on the user device. No user-device install/uninstall was performed. Current public beta1381 predates this installer change.
