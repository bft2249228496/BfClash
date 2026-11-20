<div>

[**简体中文**](README_zh_CN.md) | [**English**](README.md)

</div>

<p align="center">
  <img src="assets/images/icon.png" width="128" height="128" alt="BfClash Icon" style="border-radius: 28px;">
</p>

<h1 align="center">BfClash</h1>

<p align="center">
  <strong>A modern, elegant cross-platform Clash proxy client with Party neon aesthetics.</strong><br>
  一款基于 Flutter 与 ClashMeta 内核构建的现代化跨平台代理客户端，专为纯粹、高颜值与极致体验打造。
</p>

<p align="center">
  <a href="https://github.com/bft2249228496/BfClash/releases"><img src="https://img.shields.io/github/v/release/bft2249228496/BfClash?style=flat-square&color=818CF8" alt="Latest Release"></a>
  <a href="https://github.com/bft2249228496/BfClash/releases"><img src="https://img.shields.io/github/downloads/bft2249228496/BfClash/total?style=flat-square&logo=github&color=38BDF8" alt="Downloads"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/bft2249228496/BfClash?style=flat-square&color=C084FC" alt="License"></a>
  <a href="https://t.me/bf2249"><img src="https://img.shields.io/badge/Telegram-@bf2249-blue?style=flat-square&logo=telegram" alt="Telegram"></a>
</p>

---

> ### 📌 项目定位与免责声明
> 1. **个人定制项目。** 本项目基于 FlClash，按作者的个人偏好和审美定制，主要用于日常学习和使用。
> 2. **维护与支持。** 作者会视个人时间处理功能建议、问题修复和技术支持，相关事项不作承诺或保证。
> 3. **更新安排。** 版本发布和代码更新视作者的空闲时间和实际需要而定，暂无服务级别承诺、固定更新计划或长期路线图。
> 4. **欢迎 Fork。** 如果你有具体想法、需求或改进建议，欢迎 Fork 本仓库，并依据 GPL-3.0 许可证构建自己的版本。
> 5. **免责声明。** 本软件按现状提供，不附带任何形式的保证。作者不对因使用本软件而产生的损失或问题承担责任。

---

## 🌟 核心亮点 (Highlights)

- 🎨 **黑曜派对流光美学 (Party Neon Aesthetics)**：深度定制的暗黑派对视觉系统，核心指标与动态折线图融入极光霓虹流光渐变（`#38BDF8` ➔ `#818CF8` ➔ `#C084FC`），全界面告别生硬死白，采用舒适护眼的柔和冰月白与雾感紫蓝灰。
- 📱 **多平台无缝体验 (Multi-Platform Support)**：基于 Flutter 3.x 驱动，完美适配 Android 各大主流手机架构（ARM64 / ARMv7 / x86_64）及桌面系统。
- ⚡ **高性能 ClashMeta 内核**：集成强大稳定的 Clash.Meta / Mihomo 核心，全面支持主流协议与分流规则，低内存占用与智能 GC。
- 🛡️ **纯粹安全、开箱即用**：支持订阅自动拉取与定时同步、WebDAV 云端数据同步、分应用代理与精准访问控制。

---

## 📥 快速下载 (Download & Install)

你可以前往 [GitHub Releases](https://github.com/bft2249228496/BfClash/releases) 获取各平台的最新预编译安装包：

| 平台 / 架构 | 安装包类型 | 适用设备说明 |
| :--- | :--- | :--- |
| **Android (ARM64)** | `.apk` | 推荐主流绝大多数现代 64 位安卓机型 |
| **Android (ARMv7)** | `.apk` | 适用于老旧 32 位安卓机型或特定嵌入式设备 |
| **Android (x86_64)** | `.apk` | 适用于 PC 安卓模拟器、虚拟机或 x86 平板 |

---

## 🛠️ 项目架构与技术栈 (Tech Stack)

- **UI 框架**：[Flutter](https://flutter.dev/) (Material 3 + BfClash 自研 Party 霓虹视觉系统)
- **状态管理**：[Riverpod](https://riverpod.dev/) (高效响应式单向数据流)
- **底层内核**：[Clash.Meta (Mihomo)](https://github.com/MetaCubeX/mihomo) (Go / Rust 桥接动态库)
- **自动化构建**：GitHub Actions 6 阶段矩阵交叉编译与自动 Release 部署

---

## 👨💻 作者与维护者 (Author)

- **开发者**：不负 ([@bft2249228496](https://github.com/bft2249228496))
- **Telegram**：[@bf2249](https://t.me/bf2249)

---

## 🙏 鸣谢与上游 (Credits & Upstream)

- **[FlClash](https://github.com/chen08209/FlClash)**：本项目 UI 架构与客户端底座基于 FlClash 深度定制与流光重构，感谢原作者 @chen08209 及所有贡献者的卓越工作。
- **[Mihomo (Clash.Meta)](https://github.com/MetaCubeX/mihomo)**：高性能代理与路由内核。

---

## 📄 开源许可证 (License)

本项目基于 [GPL-3.0 License](LICENSE) 开源。
