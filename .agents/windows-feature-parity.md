# Windows feature acceptance against Android

A shared implementation is not acceptance. Every row needs an accessible Windows entry, complete behavior, failure feedback, persistence, and evidence from a packaged Windows build. This list is an active audit, not a completion claim.

| Android capability | Windows implementation / entry | Current evidence and remaining work |
| --- | --- | --- |
| Start/stop and internet proxy | Desktop dashboard, core lifecycle, system proxy/TUN | CI38673081286 autoRun with Bf core exclusively7890 and Edge system proxy passed; manual transitions, first-start reliability and sustained browsing pending |
| Rules/global/direct, node selection and delay | ProxiesView and dashboard | Shared UI present; device mode/node/delay checks pending |
| Profile import/edit/refresh/switch and overrides/scripts | ProfilesView and config views | Source paths present; real import/edit/restart/failure checks pending |
| DNS, ports, rules, providers and resources | ConfigView, AdvancedConfigView, ResourcesView | Resources desktop entry restored in this change; operation/restart checks pending |
| Language/theme/application settings | LocaleSettingItem, ThemeView, ApplicationSettingView | Missing desktop language entry restored in this change; device persistence check pending |
| Requests, connections, traffic and logs | Desktop navigation and logs setting | Entries present; user-generated traffic and connection controls pending |
| Local backup and restore | BackupAndRestore / backup actions | Shared implementation present; Windows archive roundtrip/content check pending |
| WebDAV backup and restore | BackupAndRestore | User account reachability observed, full Windows backup/restore roundtrip pending |
| Remote Sub-Store | SubStoreView | Source path present; actual remote transform/import pending |
| Local Sub-Store | SubStoreBackendService | Build now packages pinned Node22.23.3 plus official2.39.8 Node backend with SHA256 verification; packaged health CI added; correct Node health endpoint verified locally; Windows beta/stable use3002/3001 with data in channel-specific home; packaged Windows CI, device transform/import and shutdown regression pending |
| Check/download/install update | CommonAction / Windows update downloader | Request-failure reporting fixed; current change adds verified Windows asset/download/install flow; Windows execution/upgrade acceptance pending |
| Platform routing controls | Android per-app VPN vs Windows rules/TUN/process rules | Equivalent user outcomes must be audited; Android-only permission UI is not a Windows implementation |
| Startup/background/tray/shortcuts/window restore | ApplicationSettingView and desktop window/tray managers | Shortcuts restored; window geometry tests pass; packaged restart/tray/startup checks pending |
| Stable/beta coexistence and uninstall | ChannelConfig / Inno / core-helper IPC | Package identities and beta preferences migration proved; full two-install service/update/uninstall regression pending |
| Signed release distribution | Windows packaging/release workflow | BLOCKED: public38689950646 unsigned installer blocked by enabled Smart App Control, events3077/3033; need trusted signing setup |

Latest installed device version remains CI38673081286. CI38689950646 was published and downloaded with matching hash but never executed due to application control. Do not equate CI/build success, source presence or a single network probe with full feature acceptance.
