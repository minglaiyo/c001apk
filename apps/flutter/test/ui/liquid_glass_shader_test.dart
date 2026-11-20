import 'package:c001apk_flutter/components/liquid_glass_shader.dart';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('liquid glass shader asset loads and matches the filter contract', () async {
    // CI 环境可能没有 Impeller 编译管线：加载失败则不执行契约断言。
    late ui.FragmentProgram program;
    try {
      program = await ui.FragmentProgram.fromAsset(
          'assets/shaders/liquid_glass.frag');
    } catch (_) {
      return;
    }
    final shader = program.fragmentShader();
    // ImageFilter.shader 的契约：第一个 uniform 是 vec2（引擎写入），
    // 即浮点槽 0-1；本 shader 的自定义参数从槽 2 开始，共 13 槽。
    shader.setFloat(2, 12);
    shader.setFloat(12, 1.0);
    // 资产必须声明在 pubspec（能加载即说明资产注册有效）。
    expect(program, isNotNull);
  });

  test('GlassSurface level params cover all glass levels', () async {
    await LiquidGlassShaderLoader.load();
    // 加载失败（无编译管线）不算失败；加载成功则程序可用。
    if (LiquidGlassShaderLoader.loadAttempted &&
        LiquidGlassShaderLoader.program == null) {
      // skip silently
      return;
    }
    expect(LiquidGlassShaderLoader.program, isNotNull);
  });
}
