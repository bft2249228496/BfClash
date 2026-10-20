# 版本号与发布命名规范

> 目的：四类产物（Android 正式 / Android 测试 / Windows 正式 / Windows 测试）在 GitHub Releases 页面和本地安装目录里都能**一眼分辨**，且四者互不干扰、可同机共存。规则尽量做到能被 CI 机器校验，不依赖人记。

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

## 3. 四类产物命名对照表

平台靠**主线号段**区分，永不交叉：Android 走 `0.x`，Windows 走 `1.x`。CHANNEL 由有无 `-stage` 决定。

| 产物 | tag | Release 标题 | 资产名（示意） | `prerelease` |
| --- | --- | --- | --- | --- |
| Android 正式 | `v0.3.0` | `BfClash Android 0.3.0` | `BfClash-0.3.0-android-arm64-v8a.apk` | `false` |
| Android 测试 | `v0.3.1-beta.1` | `BfClash Android Beta 0.3.1-beta.1` | `BfClash-0.3.1-beta.1-android-arm64-v8a.apk` | `true` |
| Windows 正式 | `v1.0.0` | `BfClash Windows 1.0.0` | `BfClash-1.0.0-windows-amd64-setup.exe` | `false` |
| Windows 测试 | `v1.0.1-beta.1861` | `BfClash Windows Beta 1.0.1-beta.1861` | `BfClash-1.0.1-beta.1861-windows-amd64-setup.exe` | `true` |

资产名格式固定为 `BfClash-<版本>-<平台>-<架构>[-setup.exe]`，其中 `<平台>` 只能是 `android` / `windows`，与现有产物命名一致，无需改动构建脚本。

读法：**标题里有没有 `Beta` = 通道；标题里的 `Android`/`Windows` = 平台；tag 有没有 `-beta`/`-rc` = 机器判定依据。** 三者必须一致。

`rc` 是正式版之前的候选，语义上属于**测试通道**（走 Beta 的包名/AppId），不出现在正式通道里。

## 4. 通道隔离（客户端行为，不可放宽）

| 本机版本 | 允许看到的更新 |
| --- | --- |
| `0.3.0`（无后缀） | 仅 `0.x` 线上**无 stage 后缀**的 tag |
| `0.3.1-beta.1` | 仅 `0.x` 线上**带 `beta`/`rc`** 的 tag |
| `1.0.0` | 仅 `1.x` 线上无 stage 后缀的 tag |
| `1.0.1-beta.1861` | 仅 `1.x` 线上带 `beta`/`rc` 的 tag |

推论：测试版用户**不会**被推送正式版，正式版用户**也不会**被推送测试版。想从测试通道切到正式通道，属于手动操作（下载正式版安装包覆盖安装），不在检查更新里自动提示。

判定实现要求：
- **通道**看 semver 的预发布段（`VersionInfo.preRelease != null`）+ release 的 `prerelease` 标志，两者都满足才算测试版。
- **平台**看 release 资产的扩展名（`.apk` = Android，`.exe`/`.zip` = Windows）**加上**版本主线号段，二者一致才接受。
- **不再使用** `tag.contains('beta')` 这类字符串匹配，也不再使用 `GET /releases/latest`（它返回的是全仓库最新正式版，跨平台会误判）。统一用 `GET /releases?per_page=100` 后逐条过滤。

## 5. 同机共存

| 平台 | 正式版身份 | 测试版身份 |
| --- | --- | --- |
| Android | `com.bfclash.client`，显示名 `BfClash` | `com.lansway.client.beta`，显示名 `BfClash Beta` |
| Windows | AppId `728B3532-…`，`BfClash.exe`，数据目录 `com.bfclash.client` | AppId `A19F870C-…`，`BfClash-Beta.exe`，数据目录 `com.bfclash.client.beta`，互斥量 `BfClashBeta_SingleInstance` |

两条通道的身份必须全链路不同：包名/AppId、可执行文件名、单实例互斥量、数据目录、开机自启项、安装目录。**任何一处复用都会导致互相覆盖或抢锁。**

> Android 测试通道的包名刻意沿用旧品牌标识 `com.lansway.client.beta`：存量测试用户以此为升级身份，改成 `com.bfclash.client.beta` 会让他们的下一次更新变成“又装了一个应用”。客户端判定同时接受两个名字，将来若要迁移，需要先发一版过渡包。
>
> 历史遗留问题已修正：`0.2.29-rc.3` 当时按“版本号是否含 `beta`”判定通道，导致 rc 被烤成**正式包名**（`com.bfclash.client`）却走**测试通道**——两者矛盾。现在 `rc` 与 `beta` 一样落进测试通道，用 Beta 包名。这批 rc 存量安装（正式包名）此后不会收到测试通道更新，走正式通道的 `0.3.0` 即可正常升级。

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
