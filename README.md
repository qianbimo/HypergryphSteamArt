# 鹰角游戏 Steam 图片同步

> **[正式 Release 页面](https://github.com/qianbimo/HypergryphSteamArt/releases/latest)** · [下载 v1.0.2 Windows 版](https://github.com/qianbimo/HypergryphSteamArt/releases/download/v1.0.2/HypergryphSteamArt-v1.0.2-win-x64.zip)


**版本 1.0.2 · 便携版 · Windows 10/11 x64 · 国服明日方舟与明日方舟：终末地**

每次 Steam 启动时，从官方启动器接口获取游戏背景，更新 Steam 自定义背景、宽幅封面、竖版封面及游戏 Logo。竖版封面自动裁切成 600×900，在底部叠加游戏 Logo。终末地详情页 Logo 默认使用 35% 显示区域。

## 1. 最快开始

1. 在 Steam 左下角选择“添加游戏 → 添加非 Steam 游戏”，添加明日方舟或终末地的游戏程序。只使用其中一个游戏也可以。
2. **正常退出一次 Steam**，以便客户端把快捷方式保存到磁盘。之后可以重新打开 Steam。
3. 完整解压 ZIP，不要直接在压缩包里运行。双击 **开始使用.cmd**（文件名显示异常时用 `Start.cmd`），输入 **1**。
4. 程序会识别 Steam、账户和游戏目录；有多个同类条目时才要求选择。图片固定保存到当前用户的数据目录，无需选择游戏目录。
5. 首次启用后，在游戏退出时**正常退出并重新启动 Steam 一次**。以后每次启动 Steam 都会自动检查一次。

**便携运行，不安装也不复制程序代码。** 程序、菜单、默认 Logo、解码器和文档均留在解压目录；`%LOCALAPPDATA%\HypergryphSteamArt` 只保存图片、配置、日志和备份。请保留解压目录，不需要修改脚本路径。无需 Python、Node.js、Codex 或额外安装图片组件。ZIP 内已包含 WebP 解码工具。

正常使用不要求管理员权限。Steam 安装在受保护文件夹时，启用即时刷新可能需要额外处理，见第 8 节。不要用其他管理员账户启动，否则会使用另一个 Windows 用户的数据目录。

## 2. 日常使用

始终双击解压目录的 `开始使用.cmd`。菜单直接运行当前目录代码，不会跳转到用户目录的旧副本。

| 菜单 | 作用 |
| --- | --- |
| 1 启用自动更新 | 识别配置，把自动启动入口指向当前解压目录并启动监视器；移动目录或升级后再选一次 |
| 2 立即更新图片 | 手动检查已启用的游戏，不用重启 Steam |
| 3 查看状态 | 查看程序和数据路径、自动启动状态、监视器、Steam 本机接口和最近运行结果 |
| 4 重新识别 | 更换 Steam 账户或游戏移动、重命名、重新入库后，重新生成配置 |
| 5 停用自动更新 | 停止监视器并删除本程序的登录启动项，保留图片与备份 |
| 6 恢复原始图片 | 先退出 Steam；停止更新并恢复本版本首次更新前的自定义图片 |
| 7 卸载后台功能 | 删除自动启动入口，并移除本程序自行创建的 Steam 调试标记；保留图片、配置及备份 |
| 8 完整说明 | 在浏览器中打开离线使用说明 |

后台监视器每 3 秒只查看本机 Steam 进程，**不会每 3 秒联网**。新的 Steam 进程出现后，最多等待 3 分钟让界面及账户就绪，再分别更新一次游戏。Steam 持续运行期间不重复下载。首次启用时 Steam 已在运行，也会检查一次。退出菜单不会关闭后台监视器。

断网或接口失败时记录错误，并保留现有图片。不会反复联网重试；联网后可选菜单 2。一个游戏失败不会阻止另一个游戏更新。Steam 或电脑关闭、休眠期间无法更新。

## 3. 自动识别与支持范围

支持当前中国大陆官方启动器接口。暂未适配海外服、B 服及其他渠道的专属图片。

程序读取 Steam 自己保存的 `shortcuts.vdf`，使用其中真实的 appid。它不创建、删除或修改 Steam 游戏快捷方式，也不修改游戏启动参数。

优先按 `Arknights.exe`、`Endfield.exe`、`EndfieldDirect.exe` 识别游戏，所以常规重命名不影响识别。也识别“明日方舟”“明日方舟：终末地”等标准名称。如果使用脚本、第三方启动器或自定义包装程序，建议保留标准游戏名称；必要时在菜单 4 选择游戏目录。

检测到多个 Steam 账户时优先选择当前登录账户，否则要求选择。一次配置只管理一个 Steam 账户；切换账户后用菜单 4 重新识别。不同 Windows 用户需分别启用，数据相互独立。

## 4. 保存位置与 Logo 回退

全部下载、解码和合成图片固定保存在当前 Windows 用户目录下，按游戏分开：

- 明日方舟：`%LOCALAPPDATA%\HypergryphSteamArt\Arknights\`
- 终末地：`%LOCALAPPDATA%\HypergryphSteamArt\ArknightsEndfield\`

每个目录包含：

| 文件 | 用途 |
| --- | --- |
| latest-original.png / .webp | 最近下载且校验通过的官方原图，后缀随接口变化 |
| latest.jpg | Steam 背景与宽幅封面 |
| latest-cover.jpg | 自动合成的 600×900 竖版封面，底部有游戏 Logo |
| latest-logo.png | 本次使用的游戏 Logo |

程序不再向游戏目录写入图片；不需要游戏目录的写权限。Steam 的最终图片仍写入所选账户的 `userdata/<账户ID>/config/grid/`。

不使用活动标题作为游戏 Logo。优先使用用户配置的 Logo，未配置则查找游戏目录同名 Logo；读取失败时依次回退到解压目录的 `Logo_明日方舟.png` 或 `Logo_明日方舟终末地.png`、游戏目录同名文件及最近缓存。图片缺失、损坏、非 PNG、尺寸太小、完全透明均视为不可用。

所有候选都不可用时，保留 Steam 当前 Logo 和竖版封面，只更新背景与宽幅封面。底部渐变根据 Logo 明暗自动选择，白字配暗色渐变，黑字配浅色渐变。详情页 Logo 的位置设置与竖版封面的 Logo 大小相互独立。

## 5. 备份、恢复与卸载

首次管理某个 Steam 条目之前，保存其原始自定义图片与 Logo 位置元数据到：

`%LOCALAPPDATA%/HypergryphSteamArt/data/originals/<Steam账户ID>/<appid>/`

原图只备份一次，不会被后续同步覆盖；若最初没有自定义图，备份清单会记录“无图片”。菜单 6 会移除本工具管理的对应图片，再恢复备份，原先没有图片时恢复为 Steam 默认。请先正常退出 Steam，否则缓存可能让恢复结果暂时不可见。

卸载建议：先选菜单 6 恢复原图（可选），再选菜单 7；正常重启 Steam 以关闭调试接口。确认不再需要备份后，手动删除解压目录即可移除程序；如需清理图片与备份，再删除 `%LOCALAPPDATA%\HypergryphSteamArt`。旧版曾生成的游戏 `backgroud` 图片不会自动删除，如需清理可手动处理。程序不删除游戏文件。

菜单 7 只移除本程序创建的调试标记；如果安装前已由其他工具启用，会保留它，避免影响其他工具。

## 6. 高级配置

菜单 5 停用后，可编辑 `%LOCALAPPDATA%\HypergryphSteamArt\data\settings.json`；保存为 UTF-8，然后菜单 1 重新启用。常用字段：

| 字段 | 含义 |
| --- | --- |
| steamPath | Steam 安装根目录，含 steam.exe |
| userId | 所选 Steam userdata 目录名，不是登录密码 |
| games[].enabled | true 启用，false 跳过该游戏 |
| games[].appId | 从 shortcuts.vdf 读取的真实 appid，重新入库后需重新识别 |
| games[].gameDirectory | 可选游戏目录，仅用于查找本地 Logo，不影响图片保存位置 |
| games[].logoPath | 可选的自定义透明 PNG 绝对路径；留空使用默认策略 |
| games[].logoSizePercent | 详情页 Logo 宽高显示区域百分比；0 保留原设置，终末地默认 35。此值不是图片像素尺寸 |

JSON 路径中的反斜杠需写为 `\\`，或使用 `/`。不要编辑 schemaVersion、kind 和 debugMarkerOwned。菜单 4 会重新生成游戏列表，可能覆盖手工配置，请先另存配置。

开发者可执行 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File lib/Update.ps1 -Preview`。预览会联网下载并在程序数据目录合成图片，但不会写 Steam 图片和游戏图片目录，也不会调用 Steam 修改图片的接口。

## 7. 状态与排错

| 现象 | 处理 |
| --- | --- |
| 找不到游戏 | 先入库，再正常退出一次 Steam 以保存快捷方式；使用标准名称，菜单 4 重新识别 |
| 只识别到一个游戏 | 只更新识别到的游戏；另一个入库后用菜单 4 |
| Steam 打开但没有立即更新 | 最多等待 3 分钟；菜单 3 查看状态，菜单 2 可手动更新 |
| 背景更新，画面暂时没变化 | 首次启用后需正常重启 Steam；确认本机 8080 接口未被其他程序占用 |
| 图标太大 / 太小 | 修改 logoSizePercent；0 表示保留已有设置，终末地默认 35 |
| 网络 / MD5 校验失败 | 保留原图，检查网络后手动更新。接口可能临时维护或变动 |
| dwebp.exe 缺失 | 重新完整解压官方分发包，不要单独复制脚本；从可信来源取得包并核对 SHA-256 |
| 游戏目录不再出现新图片 | 这是 1.0.1 起的预期行为，请查看 `%LOCALAPPDATA%\HypergryphSteamArt` 中的 Arknights / ArknightsEndfield |
| 换账户 / 重装游戏 / 重新入库 | 菜单 4 重新识别；重新入库可能产生新的 appid |
| 中文入口名称异常 | 双击 ASCII 文件名 Start.cmd；支持中文、空格路径 |
| 退出菜单后进程仍在 | 监视器正常运行；菜单 5 才会停止后台 |
| 更新提示已有实例 | 等待正在进行的更新完成后再操作，不要重复启动 |

日志位置：`%LOCALAPPDATA%\HypergryphSteamArt` 内的 `data/last-update.log`（最近一次启动更新输出）、`data/last-run.json`（启动触发结果）、`data/watcher.log`（监视器异常）、`Arknights/errors.log` / `ArknightsEndfield/errors.log`（单游戏错误）。日志可能包含本机路径和 Steam userdata ID，公开提交前请自行隐藏。

首次联网更新需要官方接口和官方图片 CDN 可用；整个安装包无法保证在所有网络环境下成功访问。Steam 内部接口并非对第三方提供的稳定 API，客户端更新后可能需要适配；失败时仍尝试磁盘写图，必要时重启 Steam 查看。

## 8. 权限与本机接口

即时刷新使用 Steam 的 CEF 本机调试接口，标记文件为 `Steam目录/.cef-enable-remote-debugging`，连接地址为 `127.0.0.1:8080`。无需 Steam 密码、Token 或 SteamGridDB API Key。

Steam 目录无写权限时，程序仍启用监视器并尝试磁盘更新，但不会替你修改系统权限。可在具有该目录写权限的账户下创建空标记文件，或让有权限的人协助；创建后正常重启 Steam。不要关闭系统安全功能，也不要给整个 Steam 目录开放不必要的权限。

该接口允许其他本机程序操作 Steam 界面。不要转发、代理或将 8080 端口暴露到局域网 / 公网。工具只连接本机地址，不创建网络监听器，不上传日志和图片，不收集账号密码。卸载时按第 5 节关闭由本程序启用的接口。

启用时创建当前用户的 Windows“启动”文件夹快捷方式，不注册系统服务、不写全局计划任务、不修改全局 PowerShell 执行策略。cmd 入口只对本次 PowerShell 进程使用 ExecutionPolicy Bypass。

## 9. 从旧版迁移与分发

当前聊天中早期脚本使用名为 `ArknightsSteamBackground` 的计划任务。**先在旧目录运行 Disable-AutoUpdate.cmd 停用旧版，再启用新版**，防止两个监视器重复更新。旧版备份不自动导入；如要保留更早的原图，请先用旧版备份恢复，或自行归档旧目录。

**必须保留解压目录**，自动启动快捷方式指向其中的 `lib/Watch.ps1`。移动前先选菜单 5 停用，移动到新位置后再选菜单 1。升级时先停用旧版，完整解压新版到固定位置，再选菜单 1；已有用户数据和备份自动复用，旧解压目录可删除。

从 1.0.0 / 1.0.1 安装式版本迁移：先从旧菜单选择 5，再从便携版菜单选择 1。旧的 `%LOCALAPPDATA%\HypergryphSteamArt\data`、`Arknights`、`ArknightsEndfield` 会继续使用。旧版复制的 App.ps1、lib、tools、docs、cmd 等代码不会自动删除，确认新版正常工作后可手动清理这些旧代码；**保留 data、Arknights、ArknightsEndfield**，不要删除整个数据根目录。

给其他人只发送发布 ZIP 和同名 SHA-256 校验文件；不要打包 `%LOCALAPPDATA%\HypergryphSteamArt`，其中含账户 ID、路径、图片与个人备份。维护者使用 Build-Release.ps1 生成干净发布包，文件列表采用白名单，不包含测试数据或任何个人记录。

## 10. 原理与第三方组件

背景来自官方启动器当前使用的公开接口：`POST https://launcher.hypergryph.com/api/proxy/web/batch_proxy`，请求 kind 为 get_main_bg_image。校验官方 MD5 后解码、生成 JPEG 及封面，并通过 SteamClient.Apps.SetCustomArtworkForApp 更新类型 0、1、2、3。程序只接受 HTTPS 的官方图片 CDN 域名。

WebP 解码器：Google / WebM libwebp 1.6.0 的 Windows x64 dwebp.exe；来源与许可见 THIRD-PARTY-NOTICES.md、tools 中的 COPYING、PATENTS 文件。其余运行依赖为 Windows PowerShell 5.1、.NET Framework 和系统 System.Drawing。

这是社区工具，未获鹰角或 Valve 官方背书。游戏图片及 Logo 的权利归原权利人；工具代码与附带第三方组件的说明不代表取得游戏图片的商业使用授权。

开发测试可在测试进程中设置 HYPERGRYPH_STEAM_ART_HOME，将数据隔离到临时目录；普通用户无需设置，默认始终使用 LOCALAPPDATA。
