<div align="center">

<img src="docs/media/banner.svg" alt="c001apk — 让酷安，轻一点。" width="100%">

# c001apk

**轻量、简体中文的非官方酷安客户端**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-607D8B?style=flat-square)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?style=flat-square&logo=flutter&logoColor=white)](docs/DEVELOPMENT.md)
[![Build](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml)
![Platforms](https://img.shields.io/badge/平台-Android-486B78?style=flat-square)
![Status](https://img.shields.io/badge/状态-持续维护中-6E8B74?style=flat-square)

[下载](https://github.com/TG-Twilight/c001apk/releases) · [反馈问题](https://github.com/TG-Twilight/c001apk/issues) · [参与开发](docs/DEVELOPMENT.md)

</div>

## 关于

基于 [c001apk-flutter](https://github.com/bggRGjQaUbCoE/c001apk-flutter) 继续维护，修复 API、完善中文体验，让日常浏览保持轻巧。

<table align="center">
  <thead>
    <tr>
      <th align="center">浏览内容</th>
      <th align="center">找到兴趣</th>
      <th align="center">按你的习惯</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">动态、文章、评论、用户空间</td>
      <td align="center">动态、应用、用户、话题与内容搜索</td>
      <td align="center">明暗主题、字体大小</td>
    </tr>
    <tr>
      <td align="center">图文详情与图片查看</td>
      <td align="center">应用、话题及产品详情</td>
      <td align="center">本地收藏与屏蔽、浏览历史</td>
    </tr>
  </tbody>
</table>

## 界面预览（2026-10-16，1.2.5-release）

<p align="center">
  <img src="docs/media/screenshots/android-home-1.2.5.avif" width="31%" alt="Android 首页：动态列表与主页、关注、我的导航">
  <img src="docs/media/screenshots/android-article-1.2.5.avif" width="31%" alt="Android 图文详情：文章封面与正文">
  <img src="docs/media/screenshots/android-settings-1.2.5.avif" width="31%" alt="Android 分类设置：外观、关注、隐私、存储与账号管理">
</p>
<p align="center"><sub>Android · 首页 / 图文详情 / 分类设置</sub></p>

## 下载安装

正式安装包可从 [Releases](https://github.com/TG-Twilight/c001apk/releases) 获取，也可以参照 [开发指南](docs/DEVELOPMENT.md) 自行构建。

云端构建包可从 [Actions](https://github.com/TG-Twilight/c001apk/actions/workflows/build.yml) 的 Artifacts 下载，平台、签名与手动构建方式见 [云端构建指南](docs/CI.md)。

反复遇到人机验证时，可参照 [从官方酷安导入设备标识](docs/DEVICE_ID_IMPORT.md)。自动识别入口需要包含此功能的新版本，不会自动加入旧发行包。

## 开发进度

- [x] 更新公共 API 请求协议、签名与错误处理。
- [x] 完成现有 Flutter 界面的一轮简体中文汉化。
- [x] 恢复主要游客浏览流程，为部分受限动态、文章提供公开详情回退。
- [x] 基本修复账号登录与状态管理，补齐验证码交互。
- [x] 本地关注与悄悄关注、多账号管理及游客模式切换。
- [x] 主导航与分类设置调整，新增 c001apk 自身更新检测。
- [x] 修复评论完成验证后仍无法加载，更新检测改为每次冷启动检查一次。
- [ ] 继续完善验证码放行与部分账号操作。
- 继续维护现有 Flutter，聚焦 Android，见 [当前维护方向](docs/PROJECT_DIRECTION.md)。

当前聚焦 **Android**（自 2026-11 起项目为 Android-only，桌面与 iOS 平台代码已移除）。Android 包名为 `app.awavenue.c001apk`。新包与旧包独立安装，登录及本地数据不会自动迁移。

> [!NOTE]
> 部分内容仍受登录、验证码和服务端接口限制，验证码放行与部分账号操作仍需继续完善。

## 参与与致谢

欢迎提交 [Issue](https://github.com/TG-Twilight/c001apk/issues) 或 Pull Request。反馈请附平台、版本、复现步骤与脱敏错误信息；开发环境、工程目录及检查命令见 [开发指南](docs/DEVELOPMENT.md)。

感谢 [bggRGjQaUbCoE/c001apk-flutter](https://github.com/bggRGjQaUbCoE/c001apk-flutter) 的开源，以及 [daimiaopeng/coolapk-desktop](https://github.com/daimiaopeng/coolapk-desktop) 的协议调研参考。

感谢 [kongwufang](https://github.com/kongwufang) 通过 [PR #11](https://github.com/TG-Twilight/c001apk/pull/11) 贡献数字联盟设备标识自动获取功能，以及配套的离线测试、实测记录与许可说明。

本项目沿用 [GNU AGPL v3](LICENSE)，第三方来源与 MIT 许可见 [第三方声明](docs/THIRD_PARTY_NOTICES.md)。本项目与酷安官方无隶属关系，酷安名称、商标及服务内容归相应权利人所有。
