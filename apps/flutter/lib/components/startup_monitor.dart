import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../logic/onboarding/onboarding_state.dart';
import 'onboarding_gate.dart';
import 'prompt_navigation.dart';
import 'update_check_tile.dart';

/// 启动时的自动更新检查与引导页衔接（原 AnnouncementMonitor 的更新检查
/// 部分；公告监控已随「c001apk 小助手」功能整体移除）。
class StartupMonitor extends StatefulWidget {
  const StartupMonitor({
    super.key,
    required this.child,
    this.onboarding,
    this.checkUpdates,
  });

  final Widget child;
  final OnboardingState? onboarding;

  /// 测试注入用；null 时走真实的 AppUpdates.check。
  final Future<void> Function()? checkUpdates;

  @override
  State<StartupMonitor> createState() => _StartupMonitorState();
}

class _StartupMonitorState extends State<StartupMonitor> {
  late final OnboardingState? _onboarding;
  bool _startupFinished = false;

  @override
  void initState() {
    super.initState();
    _onboarding = widget.onboarding ?? OnboardingState.current;
    _onboarding?.addListener(_onboardingChanged);
    PromptNavigation.changes.addListener(_navigationChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_startup()));
  }

  Future<void> _startup() async {
    await waitForOnboardingNavigation(_onboarding);
    if (!mounted) return;
    try {
      if (widget.checkUpdates != null) {
        await widget.checkUpdates!();
      } else {
        final context = Get.context;
        if (context != null && context.mounted) {
          await AppUpdates.check(context,
              automatic: true, onboarding: _onboarding);
        }
      }
    } catch (_) {
      // Automatic checks never interrupt launch with diagnostic errors.
    } finally {
      _startupFinished = true;
    }
  }

  void _onboardingChanged() {
    if (_onboarding?.active == false && _startupFinished) {
      unawaited(_afterOnboarding());
    }
  }

  void _navigationChanged() {
    if (_startupFinished && _onboarding?.active != true) {
      unawaited(_afterOnboarding());
    }
  }

  Future<void> _afterOnboarding() async {
    await waitForOnboardingNavigation(_onboarding);
  }

  @override
  void dispose() {
    _onboarding?.removeListener(_onboardingChanged);
    PromptNavigation.changes.removeListener(_navigationChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
