# GitHub Actions 云端构建

[返回开发指南](DEVELOPMENT.md) · [查看 Actions](https://github.com/minglaiyo/c001apk/actions/workflows/build.yml)

配置入口为 [Build workflow](../.github/workflows/build.yml)。当前本地配置固定 Flutter 3.47.7 / Dart 3.13.5，
Android 使用 Temurin JDK 17，所有 Flutter 命令从 `apps/flutter/` 执行。
依赖安装使用 `--enforce-lockfile`，不在云端自动升级依赖；Action 引用固定到完整提交 SHA。

Android 正式构建保留 Flutter 默认的构建前准备，不使用 `--no-pub`：当前 SDK 会在此阶段按 release 模式重新生成原生插件注册，排除 `flutter_native_splash` 等仅开发期使用的插件。前置依赖安装仍强制锁文件，构建后再次检查 `pubspec.lock` 未变；不要手工修改生成的注册文件或将生成工具改为运行时依赖。

Android 安装 API 37（SDK Manager 包名为 `platforms;android-37.0`）、Build Tools 37.0.0、NDK 28.2.13676358，Gradle / AGP / Kotlin 版本及兼容开关见 [开发指南](DEVELOPMENT.md)。本项目自 2026-11 起为 Android-only：Windows/Linux 桌面与 iOS 构建已从 workflow 移除，相关平台目录已删除。

## 运行方式

- 推送 `main` 或提交 PR，且改动 Flutter 工程或 workflow 时，自动执行离线检查和构建。
- 在 Actions → Build → Run workflow 手动运行，默认 `android_release=true`，生成正式签名 Android APK。
- Android debug 与 release 均要求项目签名 Secrets（`ANDROID_KEYSTORE_BASE64` + `REVIA_KS_PASS`），缺少时失败，不回退开发证书。PR 跳过 Android APK 构建。

静态分析零告警（error/warning/info 均阻断）。
普通测试只使用离线合成夹具，在线检查默认跳过。CI 不操作真实账号。

| 任务 | Runner | 产物 |
| --- | --- | --- |
| 离线分析/测试 | `ubuntu-22.04` | 检查日志 |
| Android debug | `ubuntu-22.04` | 三 ABI 项目证书 APK，保留 7 天；PR 不构建 |
| Android release | `ubuntu-22.04` | `arm64-v8a` / `armeabi-v7a` / `x86_64` 正式签名 APK，分别上传 |

每次运行先按 UTC+8 日期生成 `YYYYMMDD` 构建号，所有平台共用同一日期；
通过 `dart tool/update_build_date.dart` 在 runner 更新 `pubspec.yaml`，保留语义版本。
内置版本、关于页与 release 文件名使用更新后的同一版本，跨日完成的任务也不会各自换日期。
此步骤仅修改 runner 工作区，不自动提交回仓库。本地构建可在 `apps/flutter/` 运行同一命令刷新日期。
正式 APK 提供 SHA-256 文件校验清单，release artifacts 保留 14 天。
从运行详情的 Artifacts 下载；此 workflow 不创建 GitHub Release。
