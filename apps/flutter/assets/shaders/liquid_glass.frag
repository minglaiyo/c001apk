// 真·液态玻璃：对模糊后的背景做圆角矩形透镜折射 + RGB 色散 +
// 菲涅尔亮边（顶部受光）+ 低透明度着色。与 ImageFilter.shader 配合：
// 第一个 uniform（vec2）由引擎写为纹理尺寸，第一个 sampler 由引擎绑为
// 滤镜输入（先经 ImageFilter.compose 的内层 blur 磨砂）。
//
// 浮点 uniform 布局（float 索引，引擎占用 0-1）：
//   2  u_radius      圆角半径 px
//   3  u_thickness   边缘折射带宽度 px
//   4  u_edge        折射强度
//   5  u_chroma      色散强度
//   6  u_tintAmount  着色透明度（0-1）
//   7-10 u_tint      着色颜色 rgba
//   11 u_highlight   顶部光晕强度（联动滚动亮度）
//   12 u_time        秒（预留）

#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_radius;
uniform float u_thickness;
uniform float u_edge;
uniform float u_chroma;
uniform float u_tintAmount;
uniform vec4 u_tint;
uniform float u_highlight;
uniform float u_time;

uniform sampler2D u_texture_input;

out vec4 frag_color;

// 圆角矩形 SDF：p 为相对中心坐标，half 为半尺寸，r 为圆角半径。
// d < 0 在内部，|d| 为到边缘的距离。
float sdRoundRect(vec2 p, vec2 half, float r) {
  vec2 q = abs(p) - half + vec2(r);
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
  vec2 pos = FlutterFragCoord().xy;
  float r = max(u_radius, 1.0);
  vec2 half = u_size * 0.5;
  vec2 p = pos - half;
  float d = sdRoundRect(p, half - vec2(0.5), r);

  // 边缘折射带：靠边最强，向内指数衰减。
  float band = exp(-max(0.0, -d) / max(u_thickness, 1.0));

  // 圆角矩形内法线：p 减去其在内缩矩形上的最近点，归一化。
  vec2 innerHalf = half - vec2(r);
  vec2 delta = p - clamp(p, -innerHalf, innerHalf);
  float len = length(delta);
  vec2 normal = len > 0.001 ? delta / len : vec2(0.0);

  // 折射采样：沿法线把 UV 往外推（透镜把边缘内容向内弯折的视觉），
  // RGB 三通道各推不同距离形成色散。
  float k = band * band * u_edge * u_thickness;
  vec2 uv = pos / u_size;
  vec2 offUv = (normal * k) / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
  offUv.y = -offUv.y;
#endif
  vec3 refracted;
  refracted.r = texture(u_texture_input, uv + offUv * (1.0 + u_chroma * 0.012)).r;
  refracted.g = texture(u_texture_input, uv + offUv * (1.0 + u_chroma * 0.024)).g;
  refracted.b = texture(u_texture_input, uv + offUv * (1.0 + u_chroma * 0.038)).b;

  // 着色：只在折射结果上叠加低透明度的主题色。
  vec3 col = mix(refracted, u_tint.rgb, u_tintAmount);

  // 菲涅尔亮边：顶部受光最亮，底部带一点内阴影，形成厚度感。
  float edgeGlow = band * band;
  float topLight = clamp(-normal.y, 0.0, 1.0);
  float bottomShade = clamp(normal.y, 0.0, 1.0);
  col += vec3(1.0) * edgeGlow * (0.30 + 0.55 * topLight) * u_highlight;
  col -= vec3(0.02) * edgeGlow * bottomShade;

  // 顶部大范围柔光（联动滚动亮度），与旧版的顶部高光衔接。
  float sheen = smoothstep(u_size.y * 0.45, 0.0, pos.y) * u_highlight;
  col += vec3(0.06) * sheen;

  // 细微的活感：随时间的极低幅度亮度呼吸（幅度 1%，避免晃眼）。
  col *= 1.0 + 0.01 * sin(u_time * 1.6 + pos.x * 0.01 + pos.y * 0.008);

  frag_color = vec4(col, 1.0);
}
