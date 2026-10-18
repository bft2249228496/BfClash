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
