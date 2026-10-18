# Desktop redesign and requested optimization acceptance

Visual reference: origin/design/desktop-redesign at657b3284, design/desktop-redesign.html. Port visual structure onto existing actions; do not merge unrelated Android base commits.

## Required outcomes

1. Windows and Android downloads: pause returns navigation; change node; continue verified partial without quitting; restart recovery; clear errors/retry; no corrupt/partial installation. Device evidence required beyond protocol tests.
2. Desktop: prototype dark surfaces, cyan/indigo/purple accent, compact horizontal navigation, power hero/chart and consistent pages. Preserve light/custom themes, keyboard navigation, narrow windows and all capabilities.
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
