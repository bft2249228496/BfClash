# BfClash Windows 版阶段 2：桌面 UI 框架、Sub-Store 本地后端与双渠道隔离方案

**基线版本**: `v0.2.27`  
**分支**: `feat/windows-desktop-v0227`  
**PR**: [#2](https://github.com/bft2249228496/BfClash/pull/2)  
**更新日期**: 2026-09-28  

---

## 1. Windows 真实 CI 构建结果与 Artifact 证据 (Run #36341781191)

在阶段 1 提交了 `.github/workflows/windows-probe.yml` 探针后，GitHub Actions 原生 `windows-2022` Runner 执行完成，编译结果完全成功（真实非交叉编译）：
- **Run ID**: `36341781191` ([查看链接](https://github.com/bft2249228496/BfClash/actions/runs/36341781191))
- **执行时长**: 12m 41s
- **产物文件 (Artifacts)**:
  1. `BfClash-0.2.27-windows-amd64-setup.exe` (39,230,560 字节，约 37.4 MB) —— Inno Setup 安装包
  2. `BfClash-0.2.27-windows-amd64.zip` (62,189,878 字节，约 59.3 MB) —— 便携版压缩包
- **构建链路实际验证内容**:
  - `actions/setup-go@v5` (Go 1.26.4): 成功编译 Windows Go 核心 `BfClashCore.exe`。
  - `dtolnay/rust-toolchain@stable` (`x86_64-pc-windows-msvc`): 成功在 Windows 原生编译 Rust 提权后台服务 `BfClashHelperService.exe`。
  - `flutter build windows`: 成功由 MSVC `cmake` 链接 Flutter Runner，生成 `BfClash.exe`，捆绑了 MSVC C++ 运行时与 `EnableLoopback.exe`。
  - Inno Setup 自动打包封装。

---

## 2. Windows 桌面 UI 框架与首批页面设计

针对桌面宽屏展示与用户喜好的深色精致布局，重构桌面端布局规范：
1. **左侧窄导航 (NavigationRail)**:
   - 保持 Material You / Fluent 现代桌面质感，紧凑图标 + 可折叠标签设计（总览、配置、代理节点、Sub-Store、请求记录、活动连接、配置中心、工具、设置）。
2. **顶部状态与控制区 (Header Toolbar)**:
   - 状态常驻：TUN 虚拟网卡状态、系统代理开关、总流量即时速率（上传/下载）、核心版本与运行时间。
   - 快捷动作：一键测速、模式切换 (Rule / Global / Direct)、快速清空连接。
3. **中央主体视口与双列自适应**:
   - 当视口宽度 $\ge 1200\text{px}$ 时，自动切为 Master-Detail 双列布局（左侧列表/卡片矩阵，右侧上下文详情抽屉）。
   - 仪表盘卡片、代理组与节点卡片按网格平铺自适应。
4. **功能完整度与明确占位标注**:
   - 严禁假装可用：对于 Windows 桌面环境正在开发或未落地的功能（如移动端扫码导入、磁贴快捷方式等），明确标注 `[桌面待完善]` 状态提示，保障用户知情。
5. **备份与恢复严格保留**:
   - 无论是 WebDAV 远程备份恢复，还是基于 Windows COM 对话框的本地 `.bfclash` 导出/导入，均置于显著入口并进行回归验收。

---

## 3. Sub-Store Windows 本地后端架构与实施计划

### 3.1 核心问题定位
Android 端现有 Sub-Store 本地引擎依赖 Kotlin 平台代码，通过内嵌 Android WebView 注入 `loon-bridge.js` 并用 Ktor 提供本地 HTTP Server (`http://127.0.0.1:3001`)。Windows 桌面端无法运行该套 Android 平台通道代码。

### 3.2 Windows 本地后端技术方案
- **技术选型**:
  - 方案 A（当前集成）：内置独立打包的轻量 Node.js / QuickJS 绿色独立运行时进程（或内嵌轻量二进制），由桌面应用启动时作为子进程托管运行官方 `sub-store.min.js`。
  - 方案 B（过渡与双模支持）：在 Windows 端提供“内置本地进程”与“外部远程 API”两种模式切换开关。
- **阶段 2 落地任务**:
  1. 界面上完善 Sub-Store 桌面自适应控制台，支持直接输入或自动探测本地 `http://127.0.0.1:3001` 与外部远程 URL。
  2. 明确标注 Windows 本地后台进程的生命周期托管与启停接口契约。
  3. 后续阶段通过 setup.dart 将 Sub-Store 桌面服务可执行体打包入 Windows Bundle。

---

## 4. 正式版与测试版 Windows 双渠道完全隔离规范

为了保证正式版（Stable）与测试版（Beta）可在同一台 Windows 机器上无冲突并存安装与运行，制定以下严格隔离矩阵：

| 隔离项 | 正式渠道 (Stable) | 测试渠道 (Beta) | 隔离实现机制 |
| :--- | :--- | :--- | :--- |
| **可执行文件名称** | `BfClash.exe` | `BfClash-Beta.exe` | `CMakeLists.txt` / `setup.dart` 输出变量 |
| **Inno Setup AppId** | `728B3532-C74B-4870-9068-BE70FE12A3E6` | `A19F870C-739B-4FA0-A39B-67E082DEBF01` | Inno Setup 注册表唯一键，防止覆盖卸载 |
| **默认安装目录** | `{autopf}\BfClash` | `{autopf}\BfClash Beta` | Inno Setup `DefaultDirName` 区分 |
| **本地数据目录** | `%APPDATA%\com.bfclash.client` | `%APPDATA%\com.bfclash.client.beta` | `path_provider` / Flutter 数据目录分立 |
| **Windows 系统服务名** | `BfClashHelperService` | `BfClashHelperServiceBeta` | `services/helper` 服务注册参数隔离 |
| **进程单实例互斥锁** | `Global\BfClash_SingleInstance` | `Global\BfClashBeta_SingleInstance` | `windows/runner/main.cpp` 互斥量隔离 |
| **IPC 命名管道** | `\\.\pipe\bfclash_ipc` | `\\.\pipe\bfclash_ipc_beta` | 核心与 Helper 间 Named Pipe 隔离 |
| **应用更新检查通道** | 仅检查最新正式 Tag (`v*` 无 `-beta`) | 检查包含 `-beta` 的预发布版本 | `lib/common/update.dart` 过滤通道 |
