# BfClash Windows 版功能逐项台账 (Phase 0 & 1)

**基线版本**: `v0.2.27` (Commit: `93e601853f71a22bd93b14b0e2569fe65e141ac0`)  
**分支**: `feat/windows-desktop-v0227`  
**审计日期**: 2026-09-28  

---

## 1. 核心导航与功能模块台账

| 模块序号 | 功能/页面名称 | 旧入口 (Android/Universal) | 数据源 / 底层驱动 | Windows 目标入口 | 正常行为 | 异常/失败行为 | 验收与测试方法 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **01** | **总览 (Dashboard)** | 底部导航栏 / 侧边抽屉 `PageLabel.dashboard` | `coreManager`, `proxyManager`, `statusManager` | 左侧桌面主导航第一项 | 显示系统状态、核心版本、上传下载即时速度、内存、快捷切换模式 (Rule/Global/Direct)、启动/停止按钮 | 核心崩溃时展示红点与错误提示；重试启动 | 验证状态卡片刷新、点击启停能否触发 `BfClashCore.exe` |
| **02** | **配置文件 (Profiles)** | 导航栏 `PageLabel.profiles` | 本地 SQLite (`drift`) + 远程 URL 下载解析 | 左侧桌面主导航第二项 | 展示已导入配置文件列表、支持订阅更新、详情编辑、标准/自定义 Overwrite 覆盖配置 | 下载失败时显示网络错误并保留旧配置；格式错误弹窗拦截 | 新建/更新订阅并查看 Overwrite 规则是否生效 |
| **03** | **代理组与节点 (Proxies)** | 导航栏 `PageLabel.proxies` | Mihomo REST API / 核心 IPC 控制通道 | 左侧桌面主导航第三项 | 分组展示节点、延迟测速、排序、单选切换当前出站节点 | 测速超时标记为 Timeout；节点切换失败通知提示 | 触发全组测速与节点切换，观察流量走向 |
| **04** | **Sub-Store** | 工具页二级入口 `_SubStoreItem` | 本地内嵌 (原仅 Android) / 远程 HTTP API | 桌面主导航独立项 / 工具入口 | 支持配置远程 Sub-Store 链接或启动本地环境，浏览器或内嵌 Web 打开管理订阅 | 链接不合法或无法连接时红色警告；本地后端缺失时友好提示 | 填入远程 Sub-Store 地址并保存，点击打开控制台验证 Query 参数传递 |
| **05** | **请求记录 (Requests)** | 工具或扩展导航 `PageLabel.requests` | Mihomo `/connections` 流式事件监听 | 左侧桌面主导航快捷入口 | 实时显示出站请求、来源进程、目标域名、匹配规则、代理链及消耗流量 | 核心断连时停止流式刷新；超载时按缓存上限滚动丢弃 | 浏览器发起访问，查看请求列表及规则命中准确度 |
| **06** | **活动连接 (Connections)** | 工具或扩展导航 `PageLabel.connections` | Mihomo API 活动连接池 | 左侧桌面主导航快捷入口 | 显示当前未关闭的 TCP/UDP 连接，支持按进程/域名筛选，支持单连接关闭或一键断开全部 | 权限不足或请求失败时弹出通知 | 点击全部关闭，验证存量连接是否立即被 RST |
| **07** | **配置中心 (通用)** | `ConfigView` -> `General` | 本地配置状态 (`clashConfigProvider`) | 配置中心侧边子导航 / 标签页 | 端口 (mixed-port)、允许局域网、IPv6、日志等级、外部控制器密钥配置 | 端口冲突时启动报错并提示修改端口 | 修改端口并热重启核心，检查端口监听 |
| **08** | **配置中心 (网络 TUN)** | `ConfigView` -> `Network` | `BfClashHelperService` (WinTUN 驱动注入) | 配置中心侧边子导航 / 标签页 | 开启/关闭 TUN 模式、选择堆栈 (system/gVisor/mixed)、DNS 劫持、Strict Route | 未提权运行报服务未安装；网卡创建失败回退 | 开启 TUN 模式，验证流量由虚拟网卡接管且 `BfClashHelperService` 正常交互 |
| **09** | **配置中心 (DNS)** | `ConfigView` -> `DNS` | Mihomo DNS 配置模块 | 配置中心侧边子导航 / 标签页 | 配置 Default DNS、NameServer、Fallback、Fake-IP 模式与过滤列表 | 格式非法时拦截保存 | 开启 Fake-IP，验证域名解析出 198.18.x.x 网段 |
| **10** | **配置中心 (规则与脚本)** | `ConfigView` -> `Rules` / `Scripts` | Clash 规则集与 JavaScript/Python 扩展 | 配置中心侧边子导航 / 标签页 | 查看和重排分流规则，编辑自定义脚本 | 语法错误拦截，避免核心崩溃 | 增删自定义规则并观察匹配顺序 |
| **11** | **配置中心 (按需连接/高级)** | `ConfigView` -> `OnDemand` / `Advanced` | 进程过滤表、系统代理绕过名单 | 配置中心侧边子导航 / 标签页 | 配置 UWP 回环代理 (`EnableLoopback.exe`)、应用绕过黑白名单 | UWP 工具拉起被安全软件拦截时报错提示 | 点击唤起 `EnableLoopback.exe` 验证免提权/提权拉起 |
| **12** | **资源中心 (Resources)** | `PageLabel.resources` | GeoIP / GeoSite 静态文件缓存 | 左侧桌面主导航辅助项 | 查看 GeoIP / GeoSite 数据库版本、手动点击在线更新 | 下载失败保持原有旧版文件 | 点击更新，检查文件大小与更新时间戳 |
| **13** | **日志 (Logs)** | `PageLabel.logs` | 核心内存日志流 (`/logs`) + Flutter 本地日志 | 左侧桌面主导航辅助项 | 滚动查看 Info/Warn/Error 日志，支持过滤与导出文件 | 超过行数截断，防止内存泄漏 | 制造一条解析错误，确认 Warn/Error 高亮过滤 |
| **14** | **工具箱 (Tools)** | `PageLabel.tools` | 各子工具聚合 | 左侧桌面主导航收拢项 | 聚合快捷操作：热键设置、UWP 回环工具、免责声明等 | - | 逐项点击验证弹窗或跳转正常 |
| **15** | **应用设置 (App Settings)** | `ApplicationSettingView` | `shared_preferences` / `appSettingProvider` | 左侧桌面底部设置项 | 语言切换、Material You / 自定义主题色、暗黑模式、开机自启、关闭窗口行为 (最小化到托盘/退出) | 写入自启注册表失败时提示管理员权限 | 切换自启动选项，核对注册表 `Run` 项 |
| **16** | **备份与恢复 (WebDAV)** | `BackupAndRestore` 页面 WebDAV 区块 | `DAVClient` (HTTP WebDAV 协议) | 备份与恢复专区 / 设置子页 | 绑定 WebDAV 账户、测试连接、立即上传备份 zip、选择覆盖模式从远程下载并还原配置与数据库 | 凭据错误、401/404 或网络中断友好弹窗报错；不损坏本地数据 | 远程上传备份后，在干净状态下全量恢复，验证配置完整性 |
| **17** | **备份与恢复 (本地文件)** | `BackupAndRestore` 页面 Local 区块 | 桌面文件选择器 `file_picker` (`picker.saveFileWithPath` / `picker.pickerFile`) | 备份与恢复专区 / 设置子页 | 导出为标准 `.bfclash` / `.zip` 备份文件；导入本地备份文件并选择仅恢复配置或全量恢复 | 文件损坏、版本不兼容或 IO 读写异常时中断并提示用户 | 导出本地文件至桌面，清空一条配置后重新导入验证 |

---

## 2. 关键路径专项核对：备份与恢复 (WebDAV vs Local)

### 2.1 WebDAV 链路核对
- **源码对应文件**: `lib/views/backup_and_restore.dart`, `lib/common/dav_client.dart`, `lib/common/webdav.dart`, `lib/providers/actions/backup.dart`
- **数据结构**: `DAVProps(uri, user, password, fileName)`，状态持久化在 `davSettingProvider` (`shared_preferences`)。
- **备份执行逻辑**:
  1. 调用 `backupActionProvider.consumeBackup` 打包本地 SQLite 数据库、profiles 目录与核心配置文件生成临时 zip。
  2. `DAVClient.backup` 将临时文件 PUT 至 WebDAV 服务器指定 `fileName` 路径。
- **恢复执行逻辑**:
  1. `DAVClient.restore` 从远程 GET 备份包到本地 `appPath.backupFilePath`。
  2. 用户选择 `RestoreOption.onlyProfiles` 或 `RestoreOption.all`。
  3. `backupAction.restore` 解压覆盖，按需重载数据库与 Riverpod 状态。
- **Windows 桌面适配点**: Windows 原生网络栈直接支持标准 HTTP/HTTPS WebDAV 通信，无平台层阻碍，需确保弹窗 UI 采用桌面宽屏适配的侧边栏或平铺卡片。

### 2.2 本地文件备份恢复链路核对
- **源码对应文件**: `lib/views/backup_and_restore.dart`, `lib/common/picker.dart`
- **备份执行逻辑**:
  1. `picker.saveFileWithPath(getBackupFileName(), path)` 唤起 Windows 系统的标准“文件保存”原生对话框 (`file_picker` 桌面实现)。
  2. 用户指定本地目录（如桌面、下载文件夹）后，将生成的备份文件安全复制到目标路径。
- **恢复执行逻辑**:
  1. `picker.pickerFile()` 唤起 Windows 系统的原生“文件选择”对话框 (`file_picker`)。
  2. 选定文件安全复制到 `appPath.backupFilePath`。
  3. 弹出 `RestoreOptionsDialog` 供用户选取“仅恢复配置”或“恢复所有数据”。
  4. 解压并应用，无损重建配置与状态。
- **Windows 桌面适配点**: Windows 平台已集成 `file_picker: ^12.0.0`，完全支持 Win32 原生 COM 接口打开/保存对话框。

---

## 3. 正式与测试渠道共存设计规范

1. **二进制与安装包隔离**:
   - 正式版: Binary `BfClash.exe`, Inno AppId `728B3532-C74B-4870-9068-BE70FE12A3E6`, 默认目录 `Program Files\BfClash`。
   - 测试版: Binary `BfClash-Beta.exe`, Inno AppId `A19F870C-739B-4FA0-A39B-67E082DEBF01`, 默认目录 `Program Files\BfClash Beta`。
2. **数据目录隔离**:
   - 正式版: `%APPDATA%\com.bfclash.client\`
   - 测试版: `%APPDATA%\com.bfclash.client.beta\`
3. **后台服务隔离**:
   - 正式版服务名: `BfClashHelperService`
   - 测试版服务名: `BfClashHelperService-Beta`
4. **互斥锁与 IPC 命名管道隔离**:
   - 互斥锁 `Global\BfClash_SingleInstance` vs `Global\BfClashBeta_SingleInstance`
   - IPC 管道 `\\.\pipe\bfclash_ipc` vs `\\.\pipe\bfclash_ipc_beta`
