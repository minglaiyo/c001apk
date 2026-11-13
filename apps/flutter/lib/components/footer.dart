import 'expressive_loading_indicator.dart';
import 'package:flutter/material.dart';

import '../constants/app_sizes.dart';
import '../logic/state/loading_state.dart';

Widget footerWidget(LoadingState footerState, Function() onReload) {
  switch (footerState) {
    case Empty():
      return Container(
        height: 80,
        alignment: Alignment.center,
        padding: AppSpacing.pageInsets,
        child: const Text('没有更多了'),
      );
    case Error():
      return GestureDetector(
        onTap: onReload,
        child: Container(
          height: 80,
          alignment: Alignment.center,
          padding: AppSpacing.pageInsets,
          child: Text(footerState.errMsg),
        ),
      );
    default:
      return Container(
        height: 80,
        alignment: Alignment.center,
        padding: AppSpacing.pageInsets,
        child: const ExpressiveLoadingIndicator(),
      );
  }
}
