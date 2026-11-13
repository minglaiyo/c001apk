import 'package:flutter/material.dart';

import '../router/page_transitions.dart';

/// 由 [colorScheme] 装配应用主题（明暗共用同一组件定制）。
///
/// [dynamicSurfaceTint] 表示当前 scheme 来自系统动态取色，
/// 导航栏表面随取色联动；静态种子色时改用 surfaceContainer。
ThemeData buildAppTheme(
  ColorScheme colorScheme, {
  required bool dynamicSurfaceTint,
}) {
  return applyAppTypography(ThemeData(
    colorScheme: colorScheme,
    useMaterial3: true,
    navigationBarTheme: NavigationBarThemeData(
      surfaceTintColor: dynamicSurfaceTint
          ? colorScheme.surfaceTint
          : colorScheme.surfaceContainer,
    ),
    snackBarTheme: SnackBarThemeData(
      actionTextColor: colorScheme.primary,
      backgroundColor: colorScheme.secondaryContainer,
      closeIconColor: colorScheme.secondary,
      contentTextStyle: TextStyle(color: colorScheme.secondary),
      elevation: 20,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: AppPredictiveBackPageTransitionsBuilder(),
      },
    ),
    popupMenuTheme: PopupMenuThemeData(
      surfaceTintColor: colorScheme.surfaceTint,
    ),
    cardTheme: CardThemeData(
      surfaceTintColor: colorScheme.surfaceTint,
      shadowColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      surfaceTintColor: colorScheme.surfaceTint,
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: colorScheme.onInverseSurface,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      refreshBackgroundColor: colorScheme.onSecondary,
    ),
  ));
}

/// Typography follows the reference app's compact page titles and setting
/// descriptions while retaining Material's normal body sizes and touch targets.
ThemeData applyAppTypography(ThemeData theme) => theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        centerTitle: false,
        scrolledUnderElevation: 0,
        titleTextStyle:
            TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
      ),
      listTileTheme: theme.listTileTheme.copyWith(
        titleTextStyle:
            TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
        subtitleTextStyle: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.outline,
            fontWeight: FontWeight.normal),
      ),
      dialogTheme: theme.dialogTheme.copyWith(
        titleTextStyle:
            TextStyle(fontSize: 18, color: theme.colorScheme.onSurface),
      ),
    );

class AppTextScaler extends TextScaler {
  const AppTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
  @override
  bool operator ==(Object other) =>
      other is AppTextScaler &&
      other.system == system &&
      other.factor == factor;
  @override
  int get hashCode => Object.hash(system, factor);
}
