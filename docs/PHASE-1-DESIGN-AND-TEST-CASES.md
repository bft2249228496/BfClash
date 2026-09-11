# 第二阶段：Android VPN + Mihomo 最小闭环设计与验收用例

## 1. 风险攻关与技术选型决议

### 1.1 Mihomo 选型、许可证与 ABI 策略
- **内核版本**：锁定 Mihomo v1.19.30 (MetaCubeX)。
- **开源许可证**：GPL-3.0。客户端业务层与系统通道代码需与内核保持清晰的进程/接口隔离，避免传染破坏跨平台抽象。
- **ABI 支持**：
  - 首选 ABI：`arm64-v8a`（主流真机）、`armeabi-v7a`（旧设备）、`x86_64`（主流桌面模拟器）。
- **运行模式决议**：
  - 采用 Android 独立前台服务进程管理模式：由 `LanswayVpnService` (Kotlin) 负责持有 Android `VpnService.Builder` 建立的 TUN 文件描述符 (`ParcelFileDescriptor`)，并通过本地 Socket / 命令行参数交接。
  - 内核出站 Socket 绑定：通过 Native Unix Domain Socket / 平台接口调用 `VpnService.protect(socketFd)`，确保所有流向远端代理节点的底层 TCP/UDP 连接不回环进入 TUN。

### 1.2 Android 14+ 前台服务与权限规范
- Android 14 (API 34) 及 Android 15 (API 35) 对后台启动前台服务有严格限制，要求必须在 `AndroidManifest.xml` 中明确声明 `foregroundServiceType`。
- 采用规范：
  - 声明 `android.permission.FOREGROUND_SERVICE` 与 `android.permission.POST_NOTIFICATIONS`。
  - 针对 VPN 核心服务声明 `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` 或系统标准 VPN 豁免，启动时挂载包含当前连接状态、断开快捷操作的前台通知。

### 1.3 状态管理与“杜绝假连接”红线
- 界面严禁使用模拟延时或虚构的 IP、速度、已连接状态。
- 状态流严格由 `LanswayVpnService` -> `MethodChannel / EventChannel` -> `VpnServiceController` (Flutter) 单向流动。
- 真实状态集合：
  - `disconnected`（已断开）
  - `connecting`（正在启动内核/建立 TUN）
  - `connected`（TUN 建立且内核健康巡检通过）
  - `disconnecting`（正在优雅停止内核、关闭 fd、注销通知）
  - `error`（启动失败、配置校验失败或异常退出，附带脱敏原因）

---

## 2. 验收用例规范 (Test Matrix)

| 编号 | 用例名称 | 前置条件 | 触发操作 | 预期行为与验收标准 |
|---|---|---|---|---|
| TC-101 | 首次连接触发系统 VPN 授权 | 未授权 VPN 权限 | 点击概览页“启动连接” | 正确拉起 Android 系统 VPN 授权弹窗（`VpnService.prepare`）；若用户拒绝，状态保持 `disconnected`，提示用户权限未授予，不启动服务。 |
| TC-102 | 无有效配置时拒绝启动空 TUN | 无有效 Mihomo 配置文件 | 尝试调用 `startVpn` | 触发严格前置配置校验；校验失败立即报错返回，**绝对不建立 TUN fd**，避免系统流量黑洞导致网络断网。 |
| TC-103 | 重复点击连接防御 (Idempotency) | 处于 `connecting` 或 `connected` 状态 | 快速连续点击启动连接 | 前台及 Service 侧执行原子防重，忽略冗余启动请求，不产生多重 TUN 或崩溃。 |
| TC-104 | 主动正常断开与资源释放 | 处于 `connected` 状态 | 点击“断开连接” | 状态变为 `disconnecting` -> `disconnected`；优雅终止内核，显式 `close()` TUN 文件描述符，注销前台通知，设备直连网络恢复。 |
| TC-105 | Activity 重建与切后台状态保持 | 服务正在运行 | 旋转屏幕、切后台或杀死主界面重开 | 新 Activity 启动后通过通道主动查询 Service 当前真实运行状态，无缝恢复界面连接状态，不中断 VPN 转发。 |
| TC-106 | 异常退出与自愈反馈 | 内核异常崩溃或被杀 | 模拟内核异常退出 | `LanswayVpnService` 捕获子进程退出信号，自动关闭 TUN fd 并向 Flutter 推送 `disconnected` 附带错误状态，避免假死。 |
