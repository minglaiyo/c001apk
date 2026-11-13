import 'package:flutter/material.dart';

import '../logic/state/loading_state.dart';
import 'status_views.dart';

/// 列表底部的“没有更多了 / 错误可点重载 / 加载中”三态。
Widget footerWidget(LoadingState footerState, Function() onReload) {
  switch (footerState) {
    case Empty():
      return const EmptyStatusView(text: '没有更多了');
    case Error():
      return ErrorStatusView(message: footerState.errMsg, onTap: onReload);
    default:
      return const LoadingStatusView();
  }
}
