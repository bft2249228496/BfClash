# 版本号与发布命名规范

> 目的：五类产物（Android 正式 / RC / 测试 / Windows 正式 / 测试）在 GitHub Releases 页面和本地安装目录里都能**一眼分辨**，且互不干扰、可同机共存。规则尽量做到能被 CI 机器校验，不依赖人记。

## 1. 一句话原则

**tag 只装语义版本，通道写在 semver 的预发布位，平台由版本主线号段区分；平台和通道不靠字符串包含判定。**

## 2. 版本号格式

```
v<MAJOR>.<MINOR>.<PATCH>[-<stage>.<n>]
```

- `stage` 只允许两个值：`beta`、`rc`（`alpha` 预留，暂不使用）。
- `n` 从 1 递增，不补零：`beta.1`、`beta.2` … `beta.10`。
- **禁止**出现在 tag 里的东西：平台名、`windows`、`ci`、`WindowsCI`、GitHub run id、日期、`pre`、`test`、`new`、`final`、`fix`。

三处版本必须一一对应：

| 位置 | 写法 | 示例 |
| --- | --- | --- |
| Git tag | `v<ver>` | `v1.0.1-beta.1861` |
| `pubspec.yaml` → `version` | `<ver>+<build>` | `1.0.1-beta.1861+1861` |
| 应用内 `versionName` | `<ver>` | `1.0.1-beta.1861` |

`<build>` 必须单调递增且全仓库唯一（Android 用递增整数，Windows 用 CI run number）。tag 与 `pubspec` 去除 `+build` 后必须**逐字符相等**，CI 会校验。

## 3. 产物命名对照表

平台靠**主线号段**区分，永不交叉：Android 走 `0.x`，Windows 走 `1.x`。CHANNEL 由有无 `-stage` 决定。

| 产物 | tag | Release 标题 | 资产名（示意） | `prerelease` |
| --- | --- | --- | --- | --- |
| Android 正式 | `v0.3.0` | `BfClash Android 0.3.0` | `BfClash-0.3.0-android-arm64-v8a.apk` | `false` |
| Android RC | `v0.3.0-rc.1` | `BfClash Android 0.3.0-rc.1` | `BfClash-0.3.0-rc.1-android-arm64-v8a.apk` | `true` |
| Android 测试 | `v0.3.1-beta.1` | `BfClash Android Beta 0.3.1-beta.1` | `BfClash-0.3.1-beta.1-android-arm64-v8a.apk` | `true` |
| Windows 正式 | `v1.0.0` | `BfClash Windows 1.0.0` | `BfClash-1.0.0-windows-amd64-setup.exe` | `false` |
| Windows 测试 | `v1.0.1-beta.1861` | `BfClash Windows Beta 1.0.1-beta.1861` | `BfClash-1.0.1-beta.1861-windows-amd64-setup.exe` | `true` |

资产名格式固定为 `BfClash-<版本>-<平台>-<架构>[-setup.exe]`，其中 `<平台>` 只能是 `android` / `windows`，与现有产物命名一致，无需改动构建脚本。

读法：**标题里有没有 `Beta` = 是不是独立测试通道；标题里的 `Android`/`Windows` = 平台；tag 有没有 `-beta`/`-rc` = 机器判定依据。** 三者必须一致。

`rc` 与 `beta` 是两种不同的东西，不能合并处理：

- **`rc`（候选版）**：它验证的就是即将发布的那个正式版，终点是同号正式版。所以它**用正式版的包名/AppId**，正式版发布后可以直接覆盖升级；
- **`beta`（测试通道）**：长期并行的独立产品，包名/AppId 与正式版完全不同，可以和正式版同机共存，只收 beta。

推论：**正式版用户永远看不到 rc**（正式版只接受正式 tag）；**rc 用户能看到正式版和更新的 rc**；**beta 用户只看到 beta**。rc 一旦装上就只是“提前进入正式版主线”，不存在从 rc 掉回 beta 的路径。

## 4. 通道隔离（客户端行为，不可放宽）

| 本机版本 | 允许看到的更新 |
| --- | --- |
| `0.3.0`（无后缀） | 仅 `0.x` 线上无 stage 后缀的 tag |
| `0.3.0-rc.2` | `0.x` 线上**无 stage 后缀**的 tag + 更新的 `-rc.N` |
| `0.3.1-beta.1` | 仅 `0.x` 线上 `-beta.N` 的 tag |
| `1.0.0` | 仅 `1.x` 线上无 stage 后缀的 tag |
| `1.0.1-beta.1861` | 仅 `1.x` 线上 `-beta.N` 的 tag |

推论：beta 用户**不会**被推送正式版，正式版用户**也不会**被推送测试版或 rc；rc 用户则会在正式版发布时被正常提示升级——这是 rc 存在的意义，否则候选版就是死胡同。

判定实现要求：
- **通道**看 tag 的 semver 预发布段：`-beta.N` = beta，`-rc.N` = rc，无后缀 = stable；release 的 `prerelease` 标志必须与此自洽（beta/rc 为 true，stable 为 false），不一致的条目直接跳过。
- **平台**看 release 资产的扩展名（`.apk` = Android，`.exe`/`.zip` = Windows）**加上**版本主线号段，二者一致才接受。
- **不再使用** `tag.contains('beta')` 这类字符串匹配，也不再使用 `GET /releases/latest`（它返回的是全仓库最新正式版，跨平台会误判）。统一用 `GET /releases?per_page=100` 后逐条过滤。

## 5. 同机共存

| 平台 | 正式版身份（stable + rc） | 测试版身份（beta） |
| --- | --- | --- |
| Android | `com.bfclash.client`，显示名 `BfClash` | `com.lansway.client.beta`，显示名 `BfClash Beta` |
| Windows | AppId `728B3532-…`，`BfClash.exe`，数据目录 `com.bfclash.client` | AppId `A19F870C-…`，`BfClash-Beta.exe`，数据目录 `com.bfclash.client.beta`，互斥量 `BfClashBeta_SingleInstance` |

两条通道的身份必须全链路不同：包名/AppId、可执行文件名、单实例互斥量、数据目录、开机自启项、安装目录。**任何一处复用都会导致互相覆盖或抢锁。**

**rc 必须复用正式版身份**，不能因为“它带后缀”就划到测试身份：Android 不允许跨包名升级，把 rc 烤成 `com.lansway.client.beta` 会让随后发布的正式版**装不上去**，rc 用户被永久卡在候选版上。

> Android 测试通道的包名刻意沿用旧品牌标识 `com.lansway.client.beta`：存量测试用户以此为升级身份，改成 `com.bfclash.client.beta` 会让他们的下一次更新变成“又装了一个应用”。客户端判定同时接受两个名字，将来若要迁移，需要先发一版过渡包。
>
> 历史遗留：`0.2.29-rc.3` 是用正式包名构建、却按预发布走测试通道判定的一版，因此它收不到 `0.2.29`。那批安装现在直接装 `v0.3.0` 的正式包即可（同包名、可覆盖、数据保留），之后就回到自动更新轨道。

## 6. CI 校验（发版前强制）

发布 workflow 在构建前校验，任一不满足即失败：

1. tag 匹配 `^v\d+\.\d+\.\d+(-(beta|rc)\.\d+)?$`；
2. Android tag 的 MAJOR 必须为 `0`，Windows 的必须为 `1`；
3. `pubspec.yaml` 的 `version` 去掉 `+build` 后等于 tag 去掉 `v`；
4. tag 带 `-beta`/`-rc` ⇔ release 的 `prerelease = true`；
5. 资产名以 `BfClash-<版本>-<平台>-` 开头，扩展名与平台匹配（Android `.apk`，Windows `.exe`/`.zip`）。

规则 1–3 由 `tool/verify_release_tag.dart` 机器校验，已接进 Android workflow 的 tag 构建：

```bash
dart run tool/verify_release_tag.dart --tag v0.3.0 --platform android
```

规则 4 由 workflow 自动推导（`prerelease` 与 `name` 均由 tag 计算，不再手工填写）。

## 7. 发布操作清单

```bash
# Android 正式版：先改 pubspec 的 version，再打 tag
dart run tool/verify_release_tag.dart --tag v0.3.0 --platform android
git tag v0.3.0 && git push origin v0.3.0      # 触发 Android workflow，自动发布

# Android 测试版
dart run tool/verify_release_tag.dart --tag v0.3.1-beta.1 --platform android
git tag v0.3.1-beta.1 && git push origin v0.3.1-beta.1

# Windows 测试版：tag 用 CI run 号，不再拼 windows-ci
gh release create v1.0.1-beta.<run_id> <资产...> \
  --target <完整40位SHA> --title "BfClash Windows Beta 1.0.1-beta.<run_id>" --prerelease
```

**禁止**：手工在网页上建 tag；用 `-windows-ci.`、`-pre`、`-new` 之类后缀；tag 与 pubspec 各改一处。

## 8. 历史 tag 处置

旧格式 tag（`v0.2.27-windows-ci.*`、`v0.2.29-rc.3`、`v0.9.1-pre.4` 等）**保留不动**，不再新增。新规则从下一个版本开始生效；客户端在过渡期同时兼容旧格式解析，直到旧版本自然淘汰。

Windows 产物的主线号段由 `0.2.x` 迁移到 `1.x`：这是为了让两条产品线永不撞号（`v0.2.29` 已被 Android 占用，Windows 继续用 `0.2.x` 迟早冲突）。旧版 Windows 客户端因无法解析新 tag，需要**手动安装一次**新版本，之后自动更新恢复正常。

### 迁移顺序（有硬约束）

已发布的旧客户端（Android ≤ 0.2.29）检查更新时走 `GET /releases/latest`，**该接口返回全仓库最新的正式 release**。因此：

1. **必须先发 Android 0.3.0，再发任何 Windows 1.x 正式版。** 否则 `/releases/latest` 会返回 Windows 包，老 Android 用户因找不到 `.apk` 资产而被判定「已是最新」，从此收不到更新。
2. Android 0.3.0 之后的新客户端已改用 `GET /releases?per_page=100` 本地过滤，不再受该接口影响。
3. Windows 只发 `beta`（`prerelease=true`）时不会污染 `latest`，可在 Android 0.3.0 之前先行发布。

### 1.0.0 beta 更新迁移

1871、1881 的 Windows 更新器把 tag 构建号与 GitHub run id 比较，无法发现同为 1.0.0 的更新。
修复代码从 1891 起生效，但恢复旧安装必须发布基础版本更高的 1.0.1-beta，不能仅发布新的 1.0.0-beta 并要求用户手动覆盖。
`test/common/windows_update_migration_test.dart` 使用 1871 原始选择器验证过渡版可见性、两种资产选择，以及过渡版到后续同基础版本构建的更新。
Windows 发版验收必须同时检查已发布旧客户端和新客户端，不得仅凭新源码测试通过宣称旧安装可升级。

### Windows 更新可用性验收

更新失败先恢复用户正常使用，再继续诊断；不得以关闭系统安全防护作为更新方案。
Windows ZIP 更新保留同卷原目录，失败时改名恢复原文件对象，不能以重新复制备份代替。
新版必须在界面附着、核心连接和配置初始化完成后确认本次更新的随机标识、版本及 PID，并通过持续存活检查；服务重启、进程创建或解压成功都不能单独作为更新成功。
启动前备份已关闭的用户数据，失败时恢复，保留节点、设置与数据库。
`tool/check_windows_portable_update.ps1` 在临时目录执行成功与失败场景并核对 NTFS 文件身份；`tool/check_windows_update_health.ps1` 验证启动确认不会接受旧版本、旧进程或错误事务。
CI 不能证明智能应用控制放行新构建。候选包仍须在开启安全防护的真实 Windows 上通过启动与更新验收，未验收的版本保留为草稿。
应用被操作系统直接拦截时，应用内代码无法自行修复信任判定；更新器只能检测失败并恢复原版，不能宣称免签名方式保证所有未来二进制放行。
当前事务能处理捕获到的更新与启动失败；断电或更新器被外部强制结束后的自动恢复尚未验收，不得宣称覆盖。

ZIP 组件在独立进程中完成加载检查后，更新器先通知仍在运行的旧版；旧版收到准备成功通知才退出。准备阶段失败或取消不得停止旧版。`dartjni.dll` 可能仅在使用 JNI 时才具备 JVM 依赖，加载检查只豁免该可选文件的缺依赖错误 126，不豁免任何安全策略拒绝或无效映像错误。

新包与当前版本 SHA256 完全相同的原生 EXE/DLL 在暂存目录中使用硬链接保留原文件对象；不同哈希仍使用新包，并遵守系统正常信任检查。Flutter 的 `app.so` 是由引擎加载的 ELF AOT 数据，不得按 Windows DLL 做 LoadLibrary 检查；其可用性由真正的新版初始化确认验证。打包后对正式和 Beta 目录都执行原生加载检查，不能仅用模拟 DLL 测试代替真实 bundle。
