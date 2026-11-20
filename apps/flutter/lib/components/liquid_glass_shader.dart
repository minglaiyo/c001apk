import 'dart:async';
import 'dart:ui' as ui;

/// 真·液态玻璃折射 shader 的加载器。
///
/// `assets/shaders/liquid_glass.frag` 与 `ImageFilter.shader` 配合
/// （引擎把模糊后的背景绑到首个 sampler、纹理尺寸写入首个 vec2）。
/// 加载失败（无 Impeller / 资产缺失）时保持 null，GlassSurface 回退到
/// 原来的磨砂 + 渐变假玻璃。
class LiquidGlassShaderLoader {
  LiquidGlassShaderLoader._();

  static ui.FragmentProgram? program;
  static bool loadAttempted = false;

  static Future<void> load() async {
    if (loadAttempted) return;
    loadAttempted = true;
    try {
      program = await ui.FragmentProgram.fromAsset(
          'assets/shaders/liquid_glass.frag');
    } catch (_) {
      program = null;
    }
  }
}
