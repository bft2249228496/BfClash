# BfClash Windows 版阶段 2：执行与技术实现总结

**分支**: `feat/windows-desktop-v0227`  
**PR**: [#2](https://github.com/bft2249228496/BfClash/pull/2)  
**更新日期**: 2026-09-28  

---

## 一、 CI 实际构建结果与证据回溯 (Run 36341781191)

在阶段 1 部署了 GitHub Actions 真实 Windows 原生环境探测流水线（`.github/workflows/windows-probe.yml`）。
- **运行状态**: `completed: success` ([Run 36341781191](https://github.com/bft2249228496/BfClash/actions/runs/36341781191))
- **平台环境**: GitHub 托管 Windows-2022 原生 Runner
- **工具链配置**:
  - Flutter: master `3.47.1` (x64)
  - Go: `1.26.4`
  - Rust: `dtolnay/rust-toolchain@stable` (Target: `x86_64-pc-windows-msvc`)
  - Inno Setup: 6.x
- **产物证据 (Artifacts: `bfclash-windows-probe`)**:
  - `dist/BfClash-0.2.27-windows-amd64-setup.exe` (39,230,560 字节，约 37.4 MB，Inno Setup 安装包)
  - `dist/BfClash-0.2.27-windows-amd64.zip` (62,189,878 字节，约 59.3 MB，免安装便携版)
- **编译全链路验证事实**:
  1. `plugins/setup` hook 成功在 Windows MSVC 环境下联动调用 `cargo build --features windows-service --release` 编译出 Windows 提权服务 `BfClashHelperService.exe`。
  2. `plugins/setup` hook 成功调用 `go build -tags=with_gvisor` 编译出 Windows 静态 Go 核心 `BfClashCore.exe`。
  3. `flutter build windows` 成功生成原生 Windows 宿主可执行程序 `BfClash.exe`，并捆绑分发了 `EnableLoopback.exe` 及 Visual C++ 运行库。

---

## 二、 阶段 2 桌面 UI 框架与核心页面规范

### 1. 桌面自适应 UI 结构
- **侧边导航栏 (AppSidebarContainer / NavigationRail)**:
  - 桌面环境（Windows/macOS/Linux）下常驻左侧窄导航，宽度随内容缩放，支持一键折叠/展开文字标签 (`showLabel`)。
  - 导航入口完整涵盖：总览 (Dashboard)、配置文件 (Profiles)、代理组与节点 (Proxies)、请求记录 (Requests)、活动连接 (Connections)、资源 (Resources)、日志 (Logs)、工具箱 (Tools)。
  - 右侧主视口嵌入 `PageActivityScope` 与独立 Navigator 堆栈，保持桌面下多页面状态驻留（不因切换页面而销毁滚动位置与输入框状态）。

### 2. 页面完整性与真实状态标注原则
- **严格保留现有功能与入口**：Android 端全部已有功能及配置逻辑在 Windows 版中均保持一致的数据流与 Riverpod 绑定。
- **杜绝虚假可用**：
  - 针对桌面端环境未适配或待完善的特性（例如移动端快速扫码添加配置、Android 专属系统代理磁贴），在 UI 上明确标注文案，并提供替代路径（如桌面端提供手动复制链接、拖拽本地配置文件导入），避免误导用户。
- **备份与恢复全链路保留**:
  - **WebDAV 备份/恢复**: 保留 WebDAV 账户绑定、连接性探针、远程备份上传与全量/仅配置还原。
  - **本地备份/恢复**: 基于 Windows COM 对话框 (`file_picker: ^12.0.0`) 触发本地 `.bfclash` / `.zip` 文件的无损导出与覆盖导入。

---

## 三、 Sub-Store Windows 本地后端方案与实施路线图

### 1. 现状与技术痛点
- Android 端现有 Sub-Store 本地后端依赖 Kotlin WebView (`LoonHostBridge.kt`) 注入 JS 脚本并在 Android 进程内启动 Ktor HTTP Server（监听 `127.0.0.1:3001`）。
- 该实现高度绑定 Android 原生 SDK，Windows 桌面平台无法直接运行该套 Kotlin 通道。

### 2. Windows 本地后端技术方案制定
- **核心目标**: 做到正式发布前**本地与远程两种模式均可用**，功能完全对等。
- **方案选型 (托管轻量独立 JS 引擎/进程)**:
  - 方案选择：在 Windows 端打包轻量独立 JS 运行环境（如 Node.js 绿色单文件、QuickJS 或轻量 Deno 二进制），桌面端启动时由应用通过子进程管理生命周期，加载 `assets/substore/backend/` 下的官方 `sub-store-0.min.js` 与 `sub-store-1.min.js`，对外暴露 `http://127.0.0.1:3001` API。
  - 状态同步：通过本地 HTTP 探针自动检测 `http://127.0.0.1:3001` 存活状态与 Sub-Store 版本。
- **当前阶段 (阶段 2) 交付内容**:
  1. 架构上确立独立子进程技术方案与契约。
  2. Sub-Store 界面支持双模切换：本地模式（显示当前本地进程状态与探针）与远程模式（自定义远程后端并持久化存储）。

---

## 四、 正式版与测试版双渠道完全隔离设计

Windows 平台支持双版本并存安装的完整隔离规范：

| 隔离项 | 正式版 (Release/Stable) | 测试版 (Beta) | 隔离实现手段 |
| :--- | :--- | :--- | :--- |
| **可执行文件名称** | `BfClash.exe` | `BfClash-Beta.exe` | CMake `BINARY_NAME` 区分 |
| **Inno Setup AppId** | `728B3532-C74B-4870-9068-BE70FE12A3E6` | `A19F870C-739B-4FA0-A39B-67E082DEBF01` | Inno Setup 安装注册表隔离，防止卸载互串 |
| **默认安装路径** | `C:\Program Files\BfClash\` | `C:\Program Files\BfClash Beta\` | `DefaultDirName` 变量隔离 |
| **数据与配置目录** | `%APPDATA%\com.bfclash.client\` | `%APPDATA%\com.bfclash.client.beta\` | 数据存储路径隔离，配置与数据库完全独立 |
| **Windows 系统服务名** | `BfClashHelperService` | `BfClashHelperServiceBeta` | Windows SCM (服务控制管理器) 独立注册 |
| **单实例互斥锁** | `Global\BfClash_SingleInstance` | `Global\BfClashBeta_SingleInstance` | `windows/runner/main.cpp` Win32 互斥体隔离 |
| **IPC 命名管道** | `\\.\pipe\bfclash_ipc` | `\\.\pipe\bfclash_ipc_beta` | 核心进程间通信管道命名隔离 |
| **更新检测通道** | 仅检测 Stable Releases (`v*` 纯数字) | 检测 Pre-releases (`v*-beta.*`) | `lib/common/update.dart` 过滤通道 |
