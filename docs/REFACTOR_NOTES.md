# 2026-11 重构说明

本次重构覆盖 UI 统一性、动效、架构分层、体积与可维护性五个维度，
在 `refactor/ui-arch-optimize` 分支以独立提交推进，全程保持
`flutter analyze` 零告警与 560 项离线回归测试通过。

## 设计 token

- `lib/constants/app_motion.dart`：全局动效时长与曲线
  （页面转场 450ms / 弹层 350ms / 滚动显隐 300ms / 切页 400ms /
  图片查看器 255ms；emphasized、sheetEnter、scrollHide 曲线）。
- `lib/constants/app_sizes.dart`：圆角（卡片 12 / 小控件 8 / 弹层 20 /
  玻璃面板 28）与间距（页面与卡片 10）。
- 取值均为重构前的事实标准，仅做集中化，不改变观感。

## 统一 UI 组件

- `components/app_sheet.dart` `showBottomSheetPage()`：自底滑入弹层的
  唯一入口。替换了 feed 详情 / 应用详情 / 话题 / 楼中楼 / 首页发布
  共 5 处逐字复制的 GetDialogRoute + SlideTransition 块（500ms linear
  统一为 350ms easeOutCubic）。
- `components/confirm_dialog.dart` `showConfirmDialog()`：确认对话框
  唯一入口，确认按钮统一 FilledButton，破坏性操作用错误配色。
  替换 6 处手写 AlertDialog。
- `components/status_views.dart`：EmptyStatusView / ErrorStatusView /
  LoadingStatusView 三件套，footer、commonBody 与 feed / 用户页的
  手写状态块共用同一实现。
- `components/more_panel.dart`：长按操作面板（复制/屏蔽/删除/举报/
  查看回复）由数据驱动，收敛 feed_card / feed_reply_card /
  notification_card 三份复制的 `_MorePanel` + `PanelAction`。
- `components/scroll_hide_animator.dart`：滚动方向驱动的显隐动画器，
  收敛三处 AnimationController + 方向监听样板；rail 布局下监听器
  保持常驻以维持发布按钮显隐联动。

## 动效增强（克制）

- 列表条目首次进入视口 150ms 淡入（`AdaptiveCardList` 内置，
  无位移以保锚点测量稳定，尊重系统“减少动画”）。
- 动态九图 → 图片查看器 Hero 过渡：源侧 tag 为
  `ninegrid:{contentId}:{index}`（contentId 保证同一路由内唯一），
  查看器按 `heroPrefix` 参数配对；查看器内翻页后返回则优雅降级为渐隐。

## 架构分层

- **路由知识单源**：`router/link_resolver.dart` 承接酷安链接 → 应用
  路由的全部映射（原 `Utils.onOpenLink`），消除 utils → pages 的
  依赖倒挂；`router/app_pages.dart` 仍是路由表唯一事实源。
- **utils 拆分**（661 行 → 52 行）：分享/举报 `utils/share_util.dart`、
  HTML 解析 `utils/html_text_util.dart`、下载 `utils/download_util.dart`、
  关注分类 `pages/home/follow_tabs.dart`；删除死代码
  `appSign` / `generateRandomBytes` / `base64EncodeRandomString` 等。
- **CommonController 瘦身**：内容过滤与临时展示拆为
  `content_filter_list_mixin`，删除/点赞/关注/已读拆为
  `feed_write_actions_mixin`（经抽象成员触达宿主列表状态）。
  16 个子类的 API 与调用点零改动。
- **发布流程单实现**：`logic/reply/reply_publisher.dart` 承接图片
  OSS 上传、发布信封校验、验证码挑战与验证后重发；ReplyPage 与
  ReplyDialog 仅保留各自目标形态的参数组装。
- **翻页触发去副作用**：自动翻页由 `AdaptiveCardList.onLoadMore`
  滚动触发（近底部 600px 或内容不足一屏），不再在 footer 的
  build 中发起请求。
- **列表 Content 骨架**：`pages/common/paged_list_content.dart`
  封装 controller 注册/滚动接线/回顶监听/释放样板，coolpic、dyh
  已迁移。

## 体积

- 删除 7 个零使用依赖：connectivity_plus、cupertino_icons、
  android_intent_plus、xml、material_loading_indicator、
  expressive_refresh、file_selector_windows；另替换删除
  modal_bottom_sheet 与 indent；`json_serializable` 移入
  dev_dependencies。
- emoji 资源 256 色量化：1.62MB → 0.74MB（183 个 PNG 文件名与
  尺寸不变，观感逐样本核对无差异）。维护工具位于
  `tools/image_tools/`（独立 Dart 包，不属于应用依赖）。
- 死文件清理：index_switcher.dart、single_line_fitted_box.dart、
  utils.dart 约 250 行死方法、多处注释死代码块。

## 工程质量

- `flutter analyze` 自本次重构起保持零告警；CI（build.yml）的
  analyze 步骤移除 `--no-fatal-infos` 宽容模式。
- analysis_options 在 flutter_lints 之上追加
  prefer_const_declarations / unnecessary_late /
  unnecessary_string_interpolations / unnecessary_parenthesis /
  sort_child_properties_last。
- `pages/noitfication` 目录更名 `pages/notification`。
- main.dart 两套重复 ThemeData 合并为 `buildAppTheme()` 单函数。

## 已知债务（后续迭代）

1. **登录态四份真相**：settings box、GlobalData、AccountStore、
   ApiSessionStore 各存一份登录相关状态，写回依赖手工同步。
   建议后续以 AccountStore 为唯一写路径做收敛（涉及账号全流程，
   回归风险最高，本轮未动）。
2. **页面骨架迁移未完**：feed/topic/search/notification/message/
   history/home_feed 等其余列表 Content 仍为手写样板，
   可按 PagedListContent 模式继续迁移；carousel_page 使用
   GetBuilder 模式，迁移需先统一注册方式。
3. **UI 直调 API 口子**：login_page、reply 输入面板之外的
   event_page / app_update_page / chat_image_uploader 等仍直接调用
   NetworkRepo，可逐个下沉到对应 controller / service。
4. **错误提示三通道**：interceptor 全局 toast、controller catch
   toast 与 LoadingState.error 并存，同一失败可能重复提示；
   建议以 silentError 约定收敛为“UI 渲染 + 主动操作 toast”两类。
5. **低用量依赖**：expandable_page_view、extended_nested_scroll_view、
   sliver_tools 各只有 1 个文件使用，替换有行为风险，暂保留。
6. **Datum 上帝模型与 dynamic 泛化**：`LoadingState<dynamic>` 与
   `as List<Datum>` 强转遍布列表链路，长期应按实体类型细分。

---

# 2026-11-14：功能线合并 + Android-only

## 功能移植

`scroll-hide-floating-nav` 分支（102 提交，v1.6.0+20261030）已合并进主线：
滚动隐藏悬浮导航（底部栏 ScrollHidingAction maintainSize 保几何 + 顶栏整高淡出末帧塌缩）、
可拖动回顶键、首页“更新了 N 条动态”胶囊、可编辑主页标签与话题格子、
完整产品详情页（关注/评分/讨论排序 pill/参数对话框与对比，移植自 AGPL-3.0 的 Costben 解析逻辑）、
投票卡片、玻璃菜单与玻璃档位选择器、云端历史、收藏单管理、图文文章编辑器、
动态编辑记录与跳楼层、动态离线快照、搜索热门与分类联想、剪贴板链接检测、
设置内搜索、缓存自动清理、列表缩略图 CDN 预览（.m.jpg）、拦截器头部拆分与分页语义修正
（Error 不再翻转 isEnd）。功能语义以功能线为准，落点适配主线结构：
统一 MorePanel（新增收藏到发布单动作）、showBottomSheetPage/showConfirmDialog、
design token、openLink 路由单源、CommonController mixin 分层、ScrollHideAnimator。

新增测试 17 个文件约 75 用例；合并后全量 analyze 零告警、测试通过（629 通过 4 跳过，
跳过项为需真机的设备标识用例）。

## Android-only 裁剪

- 删除平台目录 `apps/flutter/{windows,linux,ios,macos,web}` 与仓库根 stray `build.yml`。
- 删除桌面专用文件：desktop_window.dart、web_runtime.dart、local_web_page.dart；
  captcha/webview 页改为 `CookieManager.instance()` 直用（Android 路径完整）。
- 清理 17 处平台分支（main.dart 桌面初始化、SystemNavigator 退出、分享/下载/导出/
  滚动条/菜单的 Windows 分支、isSupportWebview 守卫等），依赖删除
  window_manager、screen_retriever 与 launcher_icons 平台段。
- CI 移除 desktop 与 ios job 及 ios dispatch input，仅保留
  checks / android-debug / android-release（自有证书三 ABI）。
- 签名证书切换为 fork 自有 JKS（alias release，指纹 12F2298C…BCC2），
  workflow 指纹校验同步更新；上游证书 EA385AFC 不再使用。

## 后续注意

- `tool/assemble_private_extensions.dart` 白名单已裁掉 windows/runner 段；
  若私有实现仓库仍下发 windows 文件，assemble 会拒绝（当前 fork 未启用私有装配）。
- 新签名与上游历史签名互不覆盖：装有上游签名包的设备需先卸载再装本 fork 包。

---

# 2026-11-15：上游同步 + 三仓库功能移植（v1.7.0）

## 上游同步（TG-Twilight/c001apk 1.5.1 / 1.5.2）

- **1.5.2 阅读修复**：`reading_presentation.dart` 抽取、详情页宽屏阅读模式
  （窄屏才显示悬浮回复键、标题显示「帖子/文章」、宽屏加「查看作者」）、
  玻璃导航支持 `direction` 竖排（与功能线的 glow/滑动 pill 合成，滑动 pill 仅横向生效）、
  `html_text` / `markdown_body` / `feed_article_body` 修复。
- **设备标识加固**：`szlm_identity_service` 与 `szlm_duid_client` 重写（含配套单测）。
- 1.5.1 的可编辑主页标签与静默过滤与本 fork 功能线实现语义重复，冲突取功能线演进版本。

## 移植自 Costben/c001apk（Compose 端的解析口径）

- **动态价格行情行**（`logic/model/feed/feed_price.dart` + `components/cards/feed_price_row.dart`）：
  到手价（`tsubid=6` / `tsubdata.final_price` + `config_name`）与二手交易价
  （`ershou_info.product_price`，配置名 `configTitle` 或 `ram+rom` 兜底）；
  缺失/为零/非法金额一律隐藏而非读成「免费」；闲鱼外链单独识别。
  `Datum` 增加 `tsubid/tsubdata/ershou_info/extraData/publishStatus` 字段。
- **仅自己可见徽章**：`publishStatus == 2` 时在时间旁展示锁形徽标。

## 移植自 kongwufang/c001apk_next

- **发产品点评**（`pages/feed/reply/rating_panel.dart`）：总体 + 子项 5 星、优缺点、
  已购买；量纲口径照抄官方（`rating_score_1` 原值 1~5，`v4_score_item_n` 星数×2，
  `publish_status` 固定 0），复用 `ReplyPublisher` 的验证码与信封校验链路；
  产品页「发表点评」入口与参数/对比同行。
- **个人主页五标签**（`pages/user/user_tabs.dart`）：动态/点评/图文/问答/酷图，
  `uid` 显式携带；点评与酷图走 `/v6/page/dataList?url=`；页面改为
  NestedScrollView（用户信息进头部、TabBar 固定），「动态」沿用已加载列表。
- **正文折叠与签名展开**（`components/clamped_content.dart`）：列表卡正文 5 行 +
  「查看更多」（用 TextPainter 量纯文本行数后裁切，因正文是 widget 树无 maxLines）；
  个人主页签名折叠 2 行且只有真被截断才出现「展开」（此前 bio 未渲染）。
- **HTTP 请求日志**（`utils/http_log.dart`）：默认关闭的排查开关，按天分文件、
  2MB 轮转、保留 7 天；敏感字段脱敏保留长度；设置 → 浏览与隐私 可开关与清空。

## 未移植（需新依赖或原生能力，记入后续）

- 后台消息轮询与系统通知（需 flutter_local_notifications + workmanager）
- 实况照片播放与导出（需 video_player）
- 视频发布（腾讯云 VOD）、动态分享长图（需 qr 生成）
- 扫码登录（依赖第三方自建服务端）、编辑资料与裁剪页（下一步）
- coolapk-desktop 的 `docs/coolapk-api.md` 实测接口手册（可作为后续协议扩充参考）
