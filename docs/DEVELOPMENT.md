# 开发指南

[返回项目首页](../README.md)

## 项目结构

```text
c001apk/
├── apps/
│   └── flutter/             # Flutter 应用（Android-only）
│       ├── lib/             # 页面、组件、网络层、模型与工具
│       ├── assets/          # 应用资源
│       ├── test/            # 回归测试源码与合成夹具
│       ├── android/         # Flutter Android 工程
│       ├── third_party/     # WebView Android 子包补丁
│       └── pubspec.yaml
├── docs/
│   ├── DEVELOPMENT.md       # 开发与验证说明
│   ├── REFACTOR_NOTES.md    # 2026-11 重构地图与已知债务
│   ├── media/               # README 横幅与界面截图
│   ├── THIRD_PARTY_NOTICES.md
│   └── licenses/            # 第三方许可原文
├── tools/image_tools/       # emoji 资源压缩维护工具（独立 Dart 包）
├── LICENSE
└── README.md
```

项目自 2026-11 起为 **Android-only**：Windows/Linux/macOS/iOS/Web 平台目录与代码已移除。

## 本地开发

### 应用更新检测

设置 → 存储与更新提供“自动检查 c001apk 更新”，默认开启，启动后后台检查，
每次冷启动检测一次，同次运行不重复自动请求；关闭后不再自动请求。该开关与 Android 的
“检查已安装应用更新”独立。存储与更新、关于页均可手动检查，手动操作不受
自动开关、跳过版本或稍后提醒影响。自动检查失败不打扰，手动失败显示中文原因。

更新来源为 `minglaiyo/c001apk` 的 GitHub Latest 正式 Release（About 页与更新检查均指向本 fork，
上游为 `TG-Twilight/c001apk`）；不检测 Actions artifacts、草稿或预发布版本。
按语义版本比较，兼容 `1.1.0-release` / `v1.2.0` / `v1.5.1-own-keystore-8` 等标签，
不比较 Release 时间或 Android ABI 版本码。同一语义版本重新构建不触发更新提示，
发布修订版时应提升语义版本。

弹窗展示版本、发布日期、完整可滚动说明和发布页入口，底部只提供“稍后”
（结束本次提醒，下次冷启动继续检测）、“跳过”（当前版本）、“更新”。自动检测仅在设置中关闭。
Android 按设备支持 ABI 匹配 APK；没有匹配资产时打开该 Release 页面。
下载通过系统浏览器进行，资产链接打开失败会尝试发布页，不自动覆盖安装。

实现位于 `lib/logic/app_update/` 和 `lib/components/update_*.dart`，
使用独立 Dio，不加入酷安拦截器、Cookie、账号 Token 或设备签名。
提醒状态保存在既有 Hive settings 中的独立键，保留原账号、历史及收藏。
`test/update/` 使用合成 Release、可控时间、临时 Hive 和浏览器通道验证，
普通测试不访问 GitHub，也不修改真实用户设置。

当前维护使用 **Flutter 3.47.7 / Dart 3.13.5**，应用保留 Dart 3.5 语言版本。依赖版本以 `apps/flutter/pubspec.lock` 为准，先使用 `flutter pub get --enforce-lockfile` 复现。

从旧 Flutter SDK 首次切换时，先运行新 SDK 的 `flutter clean`，再恢复锁定依赖并构建。

Android 工程使用 Gradle 9.6.1、AGP 9.3.3、Kotlin 2.4.21、compileSdk / targetSdk 37、minSdk 24，使用标准 JDK 17、Android Build Tools 37.0.0 和 NDK r28c（28.2.13676358）。Android 最低系统版本为 Android 7.0。

AGP 9 暂保留 `android.builtInKotlin=false` 和 `android.newDsl=false`，兼容现有 Flutter 插件；尚未迁移内置 Kotlin / 新 DSL。旧插件库的 compileSdk 在 `androidComponents.finalizeDsl` 中提高到至少 37，不改其 targetSdk / minSdk。WebView Android 子包使用 `third_party/flutter_inappwebview_android` 内带许可的 1.1.3 源码补丁，只替换 AGP 9 不再接受的默认 ProGuard 文件名，来源见包内 `C001APK_PATCH.md`。

正常安装 NDK 时由 Flutter 选择上述版本。需要使用已核验的独立 NDK 目录时，仅在构建进程设置 `C001APK_ANDROID_NDK_PATH`。

使用代理时，运行 `flutter test` 的当前进程须让 `localhost,127.0.0.1,::1` 绕过代理（`NO_PROXY`）；否则测试进程的本机 WebSocket 可能返回 HTTP 503，导致测试套件加载失败。临时调整后恢复进程原值，不修改用户级代理配置。

网页登录和人机验证使用应用内 WebView（`flutter_inappwebview`）。使用方式为登录页右上角“网页登录”，在酷安官方网页完成验证及登录后自动返回并保存账号；取消保留原账号。

```powershell
git clone https://github.com/minglaiyo/c001apk.git
cd c001apk/apps/flutter

flutter doctor -v
flutter pub get
flutter analyze
flutter test
```

所有 Flutter 命令均在 `apps/flutter/` 下执行。自 2026-11 重构起 `flutter analyze` 保持零告警（analysis_options 在 flutter_lints 之上追加了 prefer_const_declarations、unnecessary_late 等规则），新增规则前先确认全库满足，提交修改时不要重新引入历史提示。

运行与调试构建：

```powershell
flutter build apk --debug
```

Android 调试 APK 位于 `apps/flutter/build/app/outputs/flutter-apk/app-debug.apk`。

### Release 构建与 Android 签名

从 `apps/flutter/` 执行：

```powershell
flutter build apk --release --split-per-abi
```

分别生成 `build/app/outputs/flutter-apk/` 下的
`app-arm64-v8a-release.apk`、`app-armeabi-v7a-release.apk`、`app-x86_64-release.apk`。

Android 工程统一设置 `packagingOptions.jniLibs.useLegacyPackaging = true`，本地和 GitHub CI 默认压缩 APK 内的原生 `.so` 库，缩小直接下载的安装包；CI 正式包核验同时检查原生库采用 ZIP Deflate 压缩。安装时 Android 会解压原生库，因此 APK 变小不代表安装后占用同幅度下降。此配置不改变三 ABI 分包、签名或 ELF 对齐要求。

发布矩阵：Android `arm64-v8a`、`armeabi-v7a`、`x86_64` 三 ABI 分包。
架构支持和 APK 拆分方式参见 [Flutter 平台支持](https://docs.flutter.dev/reference/supported-platforms)
及 [Android 发布指南](https://docs.flutter.dev/deployment/android#build-an-apk)。

Android 所有构建变体（包括 debug、profile、release 和 instrumentation 测试包）均使用项目证书，缺少 keystore、alias 或密码时构建失败。签名证书有两组：

1. **fork 自有证书**（2026-11-14 生成，CI 当前使用）：JKS 位于维护者本机
   `D:/zhushu/c001apk-release.jks`，别名 `release`，密码记录在仓库外的
   `c001apk-release-cert-info.txt`。CI Secrets 为 `ANDROID_KEYSTORE_BASE64` + `REVIA_KS_PASS`，
   工作流指纹校验值 `12F2298C…BCC2` 与之对应。
2. **上游历史证书**（秋风のとおり道，指纹 `EA385AFC…CB67`）：文件由上游持有，本 fork 不再使用；
   其签名历史包与本 fork 新包互不覆盖。

以下环境变量在本地构建时读取（CI 经 Secrets 注入同名变量）：

| 环境变量 | 用途 |
| --- | --- |
| `KEYSTORE` | JKS 的路径，建议绝对路径 |
| `KEY_ALIAS` | 签名 alias |
| `KEYSTORE_PASSWORD` | keystore 密码 |
| `KEY_PASSWORD` | 私钥密码 |
| `REVIA_KS_PASS` | 两项专用密码变量未分别设置时的统一密码 |

本地也可以复制 [key.properties.example](android/key.properties.example)
为 `android/key.properties`，仅填写 `storeFile` 和 `keyAlias`；这个本地文件已被
Git 忽略。密码通过环境变量提供，勿写进该文件或提交到仓库。
含中文或日文的路径/alias 使用 Properties 的 `\uXXXX` 转义，或通过环境变量传入。
Windows 用户级变量需要注入当前进程，例如：

```powershell
$env:REVIA_KS_PASS = [Environment]::GetEnvironmentVariable('REVIA_KS_PASS', 'User')
try { flutter build apk --release --split-per-abi }
finally { Remove-Item Env:REVIA_KS_PASS }
```

GitHub Actions 配置见 [云端构建指南](CI.md) 与 [Build workflow](../.github/workflows/build.yml)。
普通 push 执行离线检查和项目签名 Android debug 构建；PR 跳过 Android 构建；
手动运行可生成正式签名的 Android 三 ABI APK。
Android 签名使用 Actions Secrets `ANDROID_KEYSTORE_BASE64` 和 `REVIA_KS_PASS`：
runner 临时恢复 JKS，并以 `KEYSTORE`、`KEY_ALIAS` 和密码环境变量传给构建，
核验证书指纹后清理。JKS、密码及其 Base64 不进入 Git 历史、公开附件或构建 artifacts，
临时 JKS 在结束时清理。Base64 只负责二进制转文本，保密依靠 Secrets；具体方式见
[GitHub 官方 Secrets 文档](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)。

Android 当前 applicationId / namespace 为 `app.awavenue.c001apk`，仍使用 Flutter 宿主。
它与旧包 `com.example.c001apk.flutter` 独立安装；旧包的账号、历史、收藏和设置不会自动迁移，新包需要重新登录。
酷安协议中的 `X-App-Id: com.coolapk.market` 保持其协议用途。

模型发生变化后，在 Flutter 工程目录生成代码：

```powershell
dart run build_runner build --delete-conflicting-outputs
```

### 测试

普通 `flutter test` 使用离线回归与合成设备夹具，在线检查默认跳过。测试覆盖请求签名、头部隔离、存储迁移、响应错误、游客详情回退、中文界面、缓存清理，以及功能线的分页语义、拦截器头部拆分、投票解析、产品详情、搜索联想、主页标签配置等。

账号回归还覆盖不完整登录检查、失败资料读取、验证期间切换账号、验证码取消和单次重试、文本写请求编码、私密发布字段，以及网页登录 Cookie 清理。
登录后受限详情可读取公开正文，界面会说明账号点赞状态尚未取得；Android 提供应用内人机验证与网页登录页面。完成验证不保证服务端解除其他风控。

服务端下发空 `captchaField` 时，验证结果使用 `validate` Cookie；非空的合法字段继续按原请求参数传递。
只有服务端接受验证重试后，才将验证状态保存在现有应用私有设置中；绑定当前账号、设备及 API 会话，最多保留 24 小时。
API 返回的 `SESSID` 按域、路径和有效期保存，未指定有效期时本地最多保留 7 天；账号切换会清除会话及验证状态。
这些 Cookie 仅用于两个官方 HTTPS API 主机，不发送到公开分享页、网页登录或外部主机，也不写入日志。
冷启动会尝试复用仍有效的状态，失效或服务端重新挑战时需再次验证；首次安装仍可能遇到服务端验证，不能保证永久免验证。
验证后的原请求最多重试一次；并发或晚到的旧挑战不会反复打开验证界面，也不会清除新账号的状态。

设备标识默认自动获取，协议、触发与限流见 [自动获取设备标识](SZLM_AUTO.md)。启动时已有标识就只复用、
不联网；没有标识或出现人机验证后，才在下次请求前注册一次，自动换号有冷却与次数上限。
手动获取与导入仍作为兜底保留，见 [图文说明](DEVICE_ID_IMPORT.md)：导入器只接受包含唯一
`ShuzlmID` 行的文本，不把普通 OAID、AndroidID 或 UUID 当作数盟 ID；解析错误不回显原始内容。
两条路径最终都走 `GStorage.applySzlmId`，只更新 Hive 的 `szlmId` 和 `xAppDevice` 首字段，
其余八个设备字段及账号、本地数据保持不变。取号失败一律保留旧标识，不自动清空、不弹提示、
不把报文或响应写进日志与错误信息。
协议字段保存不再轮换安装 ID/MAC。新建或手动重置时，Android 经原生通道仅读取厂商、品牌、
型号、构建号、系统版本与 SDK 等级。
既有参数不做自动迁移，安装随机 ID 和已获取标识均保留。自动方案不等于 SDK 独立接入或长期免验证；
真实 ID 与完整剪贴板内容不得进入测试夹具、诊断日志和公开截图。

需要主动检查游客只读接口时，可单独执行：

```powershell
$env:COOLAPK_LIVE_PROBE = '1'
flutter test test/live/api_probe_test.dart
Remove-Item Env:COOLAPK_LIVE_PROBE
```

游客动态、文章详情检查使用 `COOLAPK_GUEST_DETAIL_PROBE=1` 和 `test/live/guest_detail_test.dart`。在线检查的脱敏结构结果写入 Flutter 工程下忽略的 `.local/reports/`；验证码或业务拒绝会如实导致检查失败。

若代理配置影响本机测试连接，可在当前 PowerShell 会话设置 `$env:NO_PROXY = 'localhost,127.0.0.1,::1'` 后重试。

## 分享与 Android 链接

动态、文章、用户、应用、话题和数码页的文本分享统一包含四行：标题、Coolapk1s 链接、
Coolapk 链接、`分享自c001apk`。无标题动态使用正文摘要或“动态”。菜单中的“复制”仍复制单条链接。

Android 支持 `coolmarket://`，以及 `coolapk.com`、`www.coolapk.com`、`m.coolapk.com`、
`coolapk1s.com`、`www.coolapk1s.com` 的 HTTP/HTTPS 链接。可在系统“应用信息 → 默认打开 →
要在此应用中打开的链接”中选择相应域名；不同系统的名称可能略有差异。第三方域名的自动验证
需要网站提供关联声明，应用不能自行保证通过，参见 [Android App Links 说明](https://developer.android.com/training/app-links/verify-android-applinks)。

外部链接通过原生队列在主页首帧后交给应用链接解析器，冷启动和运行中使用同一流程。
Android 的 Flutter 默认深链处理保持关闭，避免完整外部 URI 被直接当作 GetX 页面路由；
参见 [Flutter 深链配置](https://docs.flutter.dev/cookbook/navigation/set-up-app-links)。

## 账号管理与设置

主导航为“主页、关注、我的”，宽窗口侧栏同步显示。“关注”展示关注流，原主页顶部不再保留“关注”。主页与关注右上角仅保留搜索，独立设置从“我的”右上角进入。设置按“外观与字号、关注与内容、浏览与隐私、存储与更新、协议与设备”分类；窄窗口进入分类子页，宽窗口并排显示分类与内容。设置项支持应用内搜索。

“我的”通过“私信与信息”进入会话列表，酷安小秘书作为独立会话与普通私信并列，点击后查看原系统通知流；个人页底部不再直接展开通知。

长按普通会话可置顶、取消置顶或确认删除。聊天的图片、动态入口始终保留；发送文字或选择图片后立即显示气泡，上传和发送进度显示在消息旁，失败保留在当前聊天页并支持手动重试。网络中断等无法确认结果时会提示先检查记录，避免重复发送；离开聊天页不会持久保存待发或失败消息。

动态可从“我的动态、本地收藏、链接”选择，确认后发送规范的酷安动态链接；本客户端将独立动态链接显示为可点击卡片。当前未使用官方专用动态卡片的扩展发送字段。表情面板分“常用、牛牛、酷币”，正文与输入面板均支持官方 32 个牛牛表情。回复工具栏支持发布图文文章（编辑器复用 OSS 上传链路）。

“我的”和设置页均提供“账号管理”。首次升级自动保存已有有效登录；添加账号成功后保留此前登录，点击已保存账号即可切换。“使用游客模式”保留已保存的账号，方便恢复；移除账号会清除该账号在本机保存的登录，移除当前账号后进入游客模式。登录失效的账号会提示重新登录。

账号切换会关闭旧账号的详情等页面，重新加载主页、关注和我的，并丢弃旧请求的晚到响应。历史、本地收藏、屏蔽设置和本地关注继续由本机共用。会话信息沿用本机 Hive 存储，账号密码不保存。云端历史（服务端浏览记录）入口在本地历史页。

界面标题、设置标题与说明参考 PiliPlus 的文字层级；“外观与字号 → 字体大小”可调节应用字号，并与系统文字缩放叠加。

## 本地关注与悄悄关注

游客可在用户主页点击“本地关注”，在底栏“关注”查看名单中用户的动态。登录后，在“设置 → 关注与内容”中开启“悄悄关注”，长按用户主页的关注按钮添加或取消；短按仍操作账号关注。“关注”页左上角标题为下拉按钮，可选择账号的用户、话题、数码、应用、全部关注，或切换到本机悄悄关注。默认显示用户关注，明确区分关注作者与关注话题；选择保存在本机，切换分类时重新从第一页加载。设置中不再提供重复的账号关注筛选入口。

设置提供名单管理入口。名单只保存在当前设备，不会自动同步到账号；登录、退出或关闭悄悄关注开关不会清空名单。当前支持用户，暂不包含话题、数码和应用。本地关注不需要登录，读取动态仍需要网络，并受接口权限、验证码或风控限制。

## 参与维护

欢迎提交 [Issue](https://github.com/minglaiyo/c001apk/issues) 或 Pull Request。反馈问题时请提供设备与系统版本、应用版本、复现步骤与脱敏错误信息，避免附带密码、Cookie、用户 Token 或私信内容。

API 修改请区分网络错误、HTTP 状态、业务拒绝、验证码和模型解析错误，并保留离线回归。修改存储时保留用户历史、收藏与设置；修改模型时使用生成器更新 `*.g.dart`。
