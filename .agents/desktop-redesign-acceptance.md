# Desktop redesign and requested optimization acceptance

Visual reference: origin/design/desktop-redesign at657b3284, design/desktop-redesign.html. Port visual structure onto existing actions; do not merge unrelated Android base commits.

## Required outcomes

1. Windows and Android downloads: pause returns navigation; change node; continue verified partial without quitting; restart recovery; clear errors/retry; no corrupt/partial installation. Device evidence required beyond protocol tests.
2. Desktop: prototype dark surfaces, cyan/indigo/purple accent, responsive desktop sidebar, power hero/chart and consistent pages. Preserve light/custom themes, keyboard navigation, narrow windows and all capabilities.
3. Xiaomi15 Android: reduce screen-off/background work while VPN/recovery stay reliable. Candidate package/signature continuity; real phone locked/foreground battery and network-recovery comparison before claiming savings.

## Feature retention map

| Area | Production capabilities that must remain |
| --- | --- |
| Dashboard | Actual core vs proxy-running state; start/stop, mode, system proxy, TUN, exitIP/refresh, speed/traffic, update and quick links |
| Proxies | Groups, node selection, delay, search, tab/list styles, providers/settings |
| Profiles | Local/URL import, edit/preview, refresh, switch, sorting, overrides/scripts |
| Connections | Real list, filters, close controls |
| Logs | Real logs, levels/search, pause/clear, visibility preference |
| Requests (missing from prototype) | Independent request page and navigation |
| Settings/Tools | Locale/theme, application/startup/tray, hotkeys, resources, basic/advanced config, DNS/ports/rules/providers, loopback, About/developer |
| Backup (missing) | Local and WebDAV export/import, errors/progress; never overwrite shared backup for tests |
| SubStore (missing) | Local/remote endpoint, owned backend lifecycle/status, frontend launch, conversion/import, exit cleanup |
| Window | Drag/maximize/minimize/close, tray/hotkeys, geometry, exit cleanup |
| Distribution | Windows channels/manual installer/signing; Android signed manual candidate, no formal autopromotion |

## Evidence boundaries

Published Windows1451 and AndroidRC1 protocol/CI evidence is baseline; redesigned package device acceptance pending. First adaptation touches desktop theme/sidebar/dashboard only, retaining page builders and actions. Mobile layout/theme unchanged; optional NetworkSpeed height defaults to original mobile size.

Never convert prototype examples (node/speed/count/memory/today totals/toasts) into fabricated state. Add only with a real source/action. All pages, failure feedback, persistence and device paths remain completion requirements.

2026-10-18 adaptation checks: desktop-only grouped settings cards reuse every passed row/action; existing mobile builders stay unchanged. Tools retain locale/resources/backup/SubStore/basic+advanced config/application/theme/hotkeys/About/developer. Quick links now open backup and SubStore directly with normal back navigation. Initial25 shell/theme/navigation checks, expanded8 light/dark900/1400 dashboard+tools renders and21 UI/shared-core/status checks passed locally; these counts overlap and must not be added as unique coverage. Windows packaging/device and remaining reference pages still pending.

2026-10-18 connection/log adaptation: wide desktop connection rows reuse existing detail sheet, chain keyword callbacks and close controls; below880px/mobile keep original rows. Desktop log rows align time/level/payload with wrapping on narrow windows, selectable payload and level callbacks retained. Shared-core4 checks plus connection narrow/wide and log6 checks passed (different suites); actual device remains pending. Xiaomi15 user now confirms RC1 installed, drain scenario unknown; battery screenshot/foreground-vs-lock comparison still pending, no savings claimed.

2026-10-18 profiles/proxies: desktop profile grid becomes a bounded vertical list, same ProfileItem and all existing menus/callbacks; current selection/file/cloud icons use real profile state. Selected desktop cards use subtle primary tint; mobile selection untouched. Wide tab-style proxies gain240px strategy-group panel driving the same TabController/ProxyGroupView; narrow keeps tabs; user list mode stays available. Wide selection->resize->empty->return test and shared core/offset suite11 passed. Profile focus/edit/import/preview10 passed. Expanded dashboard/tools/profiles/proxies16 dark/light900/1400 renders passed, fixture values only, not device verification. No candidate published for these changes yet.

2026-10-18 cross-proxy regression: real loopback HTTP proxyA cancels at32768/65536 bytes; same downloader switches to proxyB and sends bytes=32768-, full digest matches. All9 downloader tests passed in both Windows/Android source trees (not live app/device proxy selection evidence). Windows test4dd0f841 and Android461a04b4 add tests only; Android RC runtime unchanged, do not republish just for tests. Final desktop six-page24 renders plus narrow/wide connection2 passed; fixed missing upload/download glyphs found by image review by using bundled Material icons with localized tooltips. No device claims.

2026-10-18 connection close behavioral regression: existing close-all dispatched without await before refreshing. Now await completion, disable pending close controls, route thrown errors through existing visible status manager, restore controls after failure, and prevent a second click on disabled row close from opening details. Four delayed success/failure (single/all) UI checks plus existing lazy list/page and app lifecycle/core interaction11 passed, targeted analyze clean. This requires a newer package than95596552; no user-device claim.

2026-10-18 WebDAV application regression added after1551 delivery (test-only): actual BackupAndRestore taps -> DAVClient/Dio real loopback origin -> real archive writer/reader -> applyRestore in isolated file SQLite tree. Replaced only background isolate dispatch to pass explicit fixture paths; not installed-app/device proof. Roundtrip restores profile/script/rule/link/group rows, selected profile and file contents after deliberately changing/deleting them. Denied PUT leaves stored archive hash unchanged, cleans produced temporary file and shows401; corrupt GET shows invalid-backup error, does not apply DB restore and cleans staging. Existing DAV/forms/provider suite39 passed locally; isolated test and analyze passed. CI adds standard suite and APP_BETA=true UI regression; all test paths must stay within generated sandbox even for Windows beta data-directory remapping. Do not republish1551 or a new test-only package for this. Actual device WebDAV roundtrip still pending.

2026-10-18 Chinese/scaled short-window regression: expanded six-page rendering to36 cases, adding zh_CN at840x592 with130% text and long Chinese profile labels. Scrolling to the actual IP card exposed a4px overflow in TrafficUsage legend. Desktop card height now follows the bodySmall text scale (never shrinks below base); mobile height unchanged. All36 render/scroll cases pass with a local WenQuanYi CJK font and targeted analyze clean. CJK Linux font is not Windows typography/device proof. Original failure log /tmp/bf-cjk-overflow-details.log, final /tmp/bf-desktop-cjk-final-20261018.log and12 short-window crops copied to Mac BfClash-desktop-cjk-20261018. Screenshot values remain fixtures. Runtime changes need a later combined package; do not claim1551 includes this fix.

2026-10-18 Requests retention check: added the real RequestsView and seeded requestsProvider to the desktop visual matrix, now7pages/42cases including Chinese840x592/130% text. Existing42 visual cases pass; a separate6-case request suite now opens actual search, filters alpha/beta, taps the destination text to open TrackerInfoDetailView, checks full rule+endpoint, closes detail, clears query and verifies both original store IDs. Initial test tapped the row center on its keyword chip; changing the test tap to the destination fixed the test, no product defect inferred. Analyze on both tests clean. Cropped fixture render copied to Mac BfClash-desktop-cjk-20261018/requests-840-dark-zh_CN-1.3.png. Real device/page/network evidence still pending; no new runtime or release for these tests.
