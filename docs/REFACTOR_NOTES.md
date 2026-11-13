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
