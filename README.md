# 澜序 Lansway · Android 界面原型

参考 Clash Party 信息结构的独立 Android 界面概念，不是官方客户端。

使用 Node.js 22 或更高版本，运行 `node server.cjs`，打开 http://127.0.0.1:5173 。无构建步骤、无运行依赖。

品牌名称和图标由环境配置控制：将 `.env.example` 复制为 `.env`，按需修改以下字段。

```dotenv
APP_NAME="澜序"
APP_NAME_EN="Lansway"
APP_ICON="/assets/lansway.svg"
APP_THEME="gemini"
APP_COLOR_MODE="dark"
```

`APP_NAME` 是中文显示名称，`APP_NAME_EN` 是英文名称，`APP_ICON` 是应用图标路径。将自定义 SVG、PNG、WebP 等图片放入 `assets/`，再填写对应的 `/assets/文件名.svg` 路径；默认图标为 `assets/lansway.svg`。

`APP_THEME` 控制默认主题，默认 `gemini`；`APP_COLOR_MODE` 控制默认明暗模式，支持 `light`、`dark`、`system`，默认 `dark`，无效值回退到 `dark`。

| `APP_THEME` | 显示名称 |
| --- | --- |
| `gemini` | Gemini · 星夜蓝紫 |
| `slate` | Slate · 雾灰留白 |
| `dracula` | Dracula · 午夜紫调 |
| `rose` | 樱霞 |
| `ember` | 日落 |
| `ocean` | 海盐 |

每套主题都有深浅两种配色，在「设置 → 主题与外观」中即时切换，并自动保存到当前浏览器。已保存的个人外观优先于环境默认；修改环境默认后，可在该页点击「恢复默认」重新采用环境配置。未知主题回退为 Gemini。

配置优先级为：同名系统环境变量 → 项目 `.env` → 默认值。空白配置使用默认值。修改 `.env` 后刷新页面即可生效；修改系统环境变量后，需要重启 `node server.cjs`。`.env` 已被 Git 忽略，`.env.example` 保留为可提交的配置模板。

页面通过 `/brand-config.js` 读取服务器生成的品牌配置，只公开这五个字段；`.env`、服务器源码和项目文档不作为静态文件对外提供。请通过上述 HTTP 地址预览，直接双击 `index.html` 或使用其他静态服务器无法加载这套环境配置。

可通过系统环境变量 `PORT` 更换预览端口，例如在 PowerShell 中先运行 `$env:PORT = '5174'`，再运行 `node server.cjs`。服务仅监听本机 `127.0.0.1`。

包含概览、代理节点、订阅管理、工具箱、偏好设置五个主入口。工具箱包含 Sub-Store、WebDAV、规则、覆写、外部资源、连接、日志与内核设置，并有 DNS、TUN、端口控制及 Android 集成等子页面。

支持模拟连接切换、节点选择、订阅添加、WebDAV 配置 / 备份记录 / 选择范围恢复、Sub-Store 输出加入订阅、配置和覆写文本草稿、规则 / 连接 / 日志筛选。所有网络数据均为演示，没有接入 VPN 服务、代理内核、Sub-Store 或 WebDAV；不存储凭据、不执行脚本。页面刷新后恢复网络示例状态；品牌读取环境配置，主题偏好保留。

完整范围、平台适配和待细化项见 [FEATURE-SCOPE.md](FEATURE-SCOPE.md)。该清单用于后续逐项对齐，不代表当前已实现与 Clash Party 全量功能一致。

桌面展示设计预览，手机浏览器显示全屏移动布局。

应用图标默认使用「序列」。在「设置 → 主题与外观 → 应用图标」可选择六款内置图标，或上传不超过 2 MB 的 PNG、JPG、WebP、SVG 图片。上传图片会等比缩放到 256 × 256 的透明画布，转为 PNG，仅保存在当前浏览器，不上传服务器。个人选择优先于 APP_ICON；「恢复默认图标」重新采用 APP_ICON 配置。此设置改变页面标识和网站图标，未接入 Android 系统桌面图标。
