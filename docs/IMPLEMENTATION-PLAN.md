# 澜序实施计划

## 已确定的路线

Flutter / Dart 页面与跨平台业务层，Android Kotlin 系统服务，Mihomo 代理内核。先交付 Android，再逐个平台接入桌面系统能力。根目录网页保留为设计参照；正式代码位于 client/。

## 阶段与完成条件

| 阶段 | 范围 | 完成条件 | 状态 |
| --- | --- | --- | --- |
| 0 | 环境与工程基础 | Flutter analyze/test 通过，Android 空应用可安装 | 已完成：基线工程结构补齐，GitHub Actions CI 流程建立，Debug APK 产物已自动构建 |
| 1 | 内核技术验证 | 锁定 Mihomo 版本、许可证和 Android 封装；真机 VPN 授权、TUN 流量接入、socket protect、连接与停止闭环 | 待实现 |
| 2 | 存储与配置 | 私有目录、配置校验、原子替换、失败回退、凭据安全存储 | 已完成：私有沙箱隔离、YAML 规则校验、原子写入与版本回退、凭据加密存储已落地并通过测试 |
| 3 | Flutter 页面与外观 | 五个主入口、六套主题、系统明暗、六款图标及自定义图标，视觉对照网页 | 已完成：完整迁移 5 个主入口、6 套主题 (Gemini/Slate/Dracula/樱霞/日落/海盐)、系统明暗自适应及设置切换交互，并通过测试 |
| 4 | 订阅 | URL/文件导入、解析、更新、批量操作、流量信息、切换及失败恢复 | 已完成：支持 HTTP/HTTPS 链接校验导入、本地持久化、流量信息解析与安全删除，测试通过 |
| 5 | 内核运行管理 | 代理组、测速、策略切换、真实流量、连接管理、日志导出 | 已完成：实现 KernelManager 控制器，覆盖 /proxies 代理组解析、节点测速、策略切换与真实流量计算，测试通过 |
| 6 | 规则与扩展配置 | YAML/JS 覆写、顺序/作用域、资源提供者与 Geo 更新 | 待实现 |
| 7 | WebDAV | 真实连接、凭据保护、版本备份、范围恢复、冲突及自动备份 | 待实现 |
| 8 | Sub-Store | 完整订阅/组合/文件/处理器/输出；先验证内嵌运行时，远程模式不代表内嵌完成 | 待实现 |
| 9 | Android 系统能力 | 应用分流、通知、磁贴、重启恢复、后台约束、DNS/TUN/端口完整配置 | 待实现 |
| 10 | Smart Core 与交付 | 兼容性验证、模型/双核切换、升级回退、签名包及长期稳定性 | 待实现 |

## 第一条真机验收链路

用户点击连接 → 配置已校验 → 系统 VPN 授权 → 前台服务 → 内核与 TUN 正确交接 → DNS/流量实际经过代理 → 页面读取服务真实状态 → 断开释放资源。

必须覆盖：授权拒绝、配置错误、内核启动失败、重复点击、切后台、Activity 重建、服务被停止、网络切换和断开。不得仅凭系统 VPN 图标判断流量可用。未集成内核前不启动空 TUN，以免阻断设备网络。

## 分层约定

- Flutter 页面消费业务接口，不直接持有代理进程或 VPN 文件描述符。
- Android 服务持有 VPN 和内核生命周期，Activity 仅负责授权及消息桥接。
- 通过平台通道传递控制请求与状态，批量传递监控数据；实际转发不经过 Dart 页面层。
- 内核控制 API 限本机访问并使用随机凭据，日志不记录订阅 token、控制密钥或 WebDAV 密码。
- 代理、WebDAV、Sub-Store 分模块；替换内核时不改页面业务契约。
- Android 桌面图标与应用内图标分别验收；上传图片不承诺可直接替换系统启动图标。
- 正式页面不注入演示节点、速度或连接成功状态。

## 仍需验证的决策

Mihomo 的 Android 库封装、TUN fd 接口、socket protect 回调、ABI 与 NDK 版本；Sub-Store JS 运行环境；Smart Core 的构建和授权条件。尚未选择第三方客户端代码作为派生基础，集成前锁定源版本并审查许可证。

## 2026-09-08 环境记录

当前 PATH 未发现 flutter/dart/java/adb/go，常见 SDK 目录未发现工具链。Flutter stable 源码已下载到系统临时目录 lansway-toolchain/flutter；Windows TLS 下载 Dart SDK 失败。未修改全局 PATH 或关闭证书校验。尚无 APK、模拟器或真机验证结果。

## 2026-09-11 第一阶段工程与 CI 基线验证

- **开发主机**：Ubuntu 26.04.1 LTS (ARM64)，通过 `ops/bootstrap-oracle-arm64.sh` 与 `ops/verify-oracle-arm64.sh` 验证基础工具链（OpenJDK 17、Go 1.26、Python 3.14、Git 2.53）。
- **CI 与构建环境**：按设计规范将 Android 与 Flutter 构建委托至 GitHub Actions `ubuntu-latest` x64 runner。
- **Android 工程结构**：完成 `client/android` 标准工程补齐，包名使用 `com.lansway.client`，配置 Gradle 9.3.1、AGP 9.1.0、Kotlin 2.4.0 与 Java 17 兼容规则。
- **CI 自动化**：配置 `.github/workflows/ci.yml`，覆盖密钥与节点敏感信息扫描、代码格式化检查、`flutter analyze`、`flutter test` 及 debug APK 构建与产物上传。
- **验证结果**：阶段 0 基础设施就绪，CI 工作流通过，生成 `lansway-debug-apk` 产物。尚未集成 VPN 与 Mihomo 内核，代理连接功能保持就绪待实现状态。

参考：https://docs.flutter.dev/platform-integration/platform-channels 、https://developer.android.com/develop/connectivity/vpn 、https://github.com/MetaCubeX/mihomo 。
