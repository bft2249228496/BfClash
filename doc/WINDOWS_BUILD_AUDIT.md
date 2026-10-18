# BfClash Windows 构建依赖与能力缺口审计报告 (Phase 0 & 1)

**基线版本**: `v0.2.27`  
**审计目标**: Windows x86_64 / arm64 架构下构建链可行性、模块完备度与依赖缺口  

---

## 1. 构建依赖全景审计

### 1.1 Flutter 与 Dart 运行时
- **Flutter SDK 版本**: Pinned `3.47.1` (CI master/pinned)，Dart `>=3.10.0 <4.0.0`
- **Native Assets / Build Hooks**:
  - `plugins/setup/hook/build.dart` 通过 `setup_hooks` 协调底层构建。
  - `plugins/rust_api/hook/build.dart` 通过 `flutter_rust_bridge` 构建跨语言 API 桥接层。
- **Windows 桌面插件兼容性**:
  - `window_manager`: in-house fork `v0.5.1-flclash.3`，带 Windows 原生全屏/任务栏修复 (`GetMonitorInfo().rcWork`)。
  - `launch_at_startup`: in-house fork，已适配 `win32_registry: ^3.0.3`。
  - `tray`: 自研平台插件 `plugins/tray/windows`，提供 Windows 托盘图标及原生右键菜单。
  - `proxy`: 自研 Windows 系统代理插件 `plugins/proxy/windows`，负责设置与清除 IE/WinINet 代理。
  - `wifi_ssid`: `plugins/wifi_ssid/windows`，基于 Windows WLAN API。

### 1.2 Go Core 核心编译链
- **模块路径**: `core/` (Clash.Meta 子模块 `core/Clash.Meta`，已固定 commit `70f0570405c3c2c47bb113b88db95006d239b346`)
- **构建目标**: `GOOS=windows GOARCH=amd64` / `arm64`
- **编译参数**: `CGO_ENABLED=0`, Tags: `with_gvisor`, ldflags: `-w -s`
- **产物形态**: `BfClashCore.exe` (约 58MB)
- **实测结果**: 已在宿主机完成交叉编译实测，成功生成 `BfClashCore.exe`，无需 CGO 依赖，纯静态链接。

### 1.3 Rust Helper 服务与跨平台桥
- **模块路径**: `services/helper/`
- **功能**: Windows 后台系统服务 (`BfClashHelperService.exe`)，负责安装与管理 TUN 虚拟网卡 (`wintun.dll`)、提权路由转发及防火墙放行规则。
- **依赖工具链**: `cargo`, `rustc` (Target: `x86_64-pc-windows-msvc`)
- **编译参数**: `--features windows-service --release`
- **安全约束**: 编译时通过环境变量注入 `CORE_SHA256` 与 `CORE_NAME`，校验 Core 二进制防篡改。

### 1.4 Windows 打包与分发组件
- **打包配置**: `windows/packaging/exe/make_config.yaml`
- **安装包生成器**: Inno Setup (`inno_setup.iss`)
- **辅助工具**: `windows/EnableLoopback.exe` 用于 UWP 应用回环代理豁免。

---

## 2. 现有能力与缺口分析 (Gap Analysis)

| 组件 / 能力 | 现状评估 | 存在问题 / 缺口 | 处置方案与优化建议 |
| :--- | :--- | :--- | :--- |
| **Go Core 静态构建** | ✅ 完备 | 无，可直接以 `CGO_ENABLED=0` 交叉编译生成 | 在 CI 中配置 Go 1.26.4 统一构建并校验 hash |
| **Rust Helper 编译** | ⚠️ 依赖宿主工具链 | Linux 交叉编译 MSVC target 需复杂 clang/llvm-rc 工具链；本地主机未装 Rust | 交付由 GitHub Actions `windows-2022` 原生环境编译 |
| **Flutter Windows Runner** | ✅ 完备 | `windows/CMakeLists.txt` 已对齐 `BfClash` 二进制及 `BfClashHelperService` 协同打包 | CI Windows Runner 可一键生成 |
| **Sub-Store 本地引擎** | ⚠️ Android 独占 | 目前内嵌后端是基于 Android WebView / Ktor 实现；Windows 缺乏 Node/Deno 或内嵌 Web 运行时 | 阶段 1 先保障远程 Sub-Store 链接配置与管理；下一阶段可引入轻量本地后端进程或内嵌轻量 JS 引擎 |
| **正式与测试双包共存** | ⚠️ 基础单配置 | `inno_setup.iss` 与 `make_config.yaml` 目前仅写死 AppId 与 `BfClash.exe`，未支持动态切换测试版名称与 AppId | 下一阶段重构 `setup.dart` windows 目标支持 `--env beta` 自动替换 AppId 与输出路径 |
