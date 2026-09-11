# OpenClaw 开发任务书

## 工作环境

- 仓库：`git@github.com:bft2249228496/clash-self.git`
- 服务器目录：`/root/projects/clash-self`
- 服务器：Ubuntu ARM64；负责代码开发、Go/Java 工具、静态检查与任务编排。
- Android/Flutter 构建：GitHub Actions `ubuntu-latest` x64 runner。不要在 ARM64 服务器强装官方 x64 Flutter SDK 或 Android build-tools。
- 正式客户端：`client/`；根目录网页只作为已经确认的视觉原型。

## 总目标

交付可长期维护的 Android 代理客户端：Flutter 负责页面与跨平台业务层，Kotlin 负责 Android VPN/前台服务/系统集成，Mihomo 负责代理内核。后续再扩展桌面平台。

## 执行规则

1. 每次开始前执行 `git status --short --branch` 和 `git pull --ff-only`，不得覆盖未提交修改。
2. 一次只实现一个可验收的纵向切片；提交信息写明范围和验证结果。
3. 不提交订阅链接、访问令牌、WebDAV 密码、签名文件、SSH 密钥或真实节点配置。
4. 页面不得使用演示数据冒充真实连接状态；未接好 Mihomo 前不得启动空 TUN。
5. 每个 PR 必须通过 analyze、test、Android debug build 和密钥扫描。
6. 遇到架构、许可证、Android VPN 或 Mihomo 接口不确定项，先记录证据和最小实验，不凭猜测扩展实现。

## 第一阶段：工程与 CI 基线

目标：把当前 Flutter 骨架变成可持续构建的 Android 工程。

- 补齐 Flutter Android 工程结构，包名暂用 `com.lansway.client`。
- 固定 Flutter stable 与 Java 17 版本，提交 lockfile。
- 新增 GitHub Actions：格式检查、`flutter analyze`、`flutter test`、debug APK 构建、产物上传。
- 添加最小应用启动测试，并确保仓库不包含生成目录和本地机密。
- 更新 `docs/IMPLEMENTATION-PLAN.md` 的阶段 0 状态和真实验证结果。

完成条件：干净检出后 CI 全绿，可下载并安装 debug APK；不得宣称代理功能已经可用。

## 第二阶段：Android VPN + Mihomo 最小闭环

目标：真机上完成连接、真实转发、状态读取和断开。

- 调研并锁定 Mihomo 版本、许可证、Android ABI、构建方式、TUN fd 和 socket protect 接口。
- Kotlin 实现 `VpnService`、前台通知、生命周期和 Flutter 平台通道。
- 实现配置校验、内核启动、TUN 交接、DNS/流量验证、停止与资源释放。
- 覆盖授权拒绝、配置错误、启动失败、重复点击、Activity 重建、网络切换和服务被杀。

完成条件：实体 Android 设备访问可验证站点，连接前后出口 IP 或路由证据发生预期变化；断开后网络恢复。

## 后续阶段

按 `docs/IMPLEMENTATION-PLAN.md` 顺序推进：安全存储与配置 → 正式 Flutter 页面和图标配置 → 订阅 → 内核运行管理 → 规则与覆写 → WebDAV → Sub-Store → Android 系统能力 → Smart Core 和发布。

每个阶段先提交设计说明和验收用例，再写实现。WebDAV、Sub-Store、订阅凭据必须进入安全存储；日志必须脱敏。

## OpenClaw 首个任务

只执行“第一阶段：工程与 CI 基线”。先检查服务器工具版本和仓库现状，再创建实现分支。完成后输出：

1. 分支名与提交 SHA；
2. 修改文件清单；
3. CI 链接及各检查结果；
4. debug APK artifact 名称；
5. 未解决风险和下一阶段建议。

第一阶段未通过前，不开始 VPN 或 Mihomo 集成。
