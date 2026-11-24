/**
 * 沉浸光感（系统玻璃材质）统一工具。
 *
 * 生效范围遵循 HarmonyOS API 26 约束：系统 ImmersiveMaterial 只在
 * Navigation / NavDestination 标题栏、弹窗类组件、Slider/Toggle/Select 上生效。
 * 底部悬浮 Dock 真机上使用系统材质会偏黄且无法与迷你播放器一致，已改用下方
 * barTint/barBase/barEdge/barSheen 确定性玻璃配方。
 * 因此本工具提供两类能力：
 *   1) 系统材质工厂（title），供上述生效位置调用；
 *   2) backdrop() 玻璃衬底渐变，铺在页面最底层，为上层玻璃材质提供可透出的内容层次，
 *      深浅主题自适应，避免纯色背景下"材质无感"。
 */
import { uiMaterial } from '@kit.ArkUI';
import { themeStore } from '../viewmodel/ThemeStore';
import { colorService, ColorService } from '../service/ColorService';

/** 渐变色标：颜色 + 位置。 */
export type GlassStop = [ResourceColor, number];

export class ImmersiveGlass {
  /** 标题栏沉浸式材质：薄、带按压光感、跟随主题赋色。 */
  static title(): uiMaterial.ImmersiveMaterial {
    return new uiMaterial.ImmersiveMaterial({
      style: uiMaterial.ImmersiveStyle.THIN,
      materialColor: themeStore.palette.headerGlass,
      interactive: true
    });
  }

  /** 玻璃衬底渐变（深色）：顶部品牌微光 -> 主题底色 -> 底部全透明透出底色。 */
  private static readonly DARK_BACKDROP: Array<GlassStop> = [
    ['#16FA2D48', 0.0],
    ['#0A101014', 0.45],
    ['#00101014', 1.0]
  ];

  /** 玻璃衬底渐变（浅色）。 */
  private static readonly LIGHT_BACKDROP: Array<GlassStop> = [
    ['#10FA2D48', 0.0],
    ['#06FFFFFF', 0.45],
    ['#00FFFFFF', 1.0]
  ];

  /** 当前主题对应的玻璃衬底渐变色标（在 build 中读取以建立响应式依赖）。 */
  static backdrop(): Array<GlassStop> {
    return themeStore.isDark ? ImmersiveGlass.DARK_BACKDROP : ImmersiveGlass.LIGHT_BACKDROP;
  }

  /** 统一的渐变角度。 */
  static readonly ANGLE: number = 135;

  // ---------------- 悬浮玻璃条（迷你播放器 / 折叠胶囊 / 播放器 Dock 副本） ----------------
  // 华为音乐式"全玻璃透感 + 折射"配方：
  //   backgroundEffect(适度模糊+轻增饱和) → 垂直折射渐变(顶部受光、中部通透、底部微沉)
  //   → 顶部横向扫光高光 → 1px 亮边描边 → 浮起阴影。四层叠加出折射质感。

  /** 折射渐变（垂直，angle 180）：顶部受光、中部通透、底部微沉。alpha 压低以保证通透。 */
  static barTint(): Array<GlassStop> {
    if (themeStore.isDark) {
      return [
        ['#26FFFFFF', 0.0],
        ['#08FFFFFF', 0.32],
        ['#03FFFFFF', 0.68],
        ['#14FFFFFF', 1.0]
      ];
    }
    return [
      ['#66FFFFFF', 0.0],
      ['#26FFFFFF', 0.32],
      ['#14FFFFFF', 0.68],
      ['#4DFFFFFF', 1.0]
    ];
  }

  /** 玻璃条基色：极低 alpha 只定色调，通透度交给 backgroundEffect。 */
  static barBase(): string {
    return themeStore.isDark ? '#0C10101A' : '#40FFFFFF';
  }

  /** 玻璃条边缘：1px 亮边，模拟玻璃倒角的受光面。 */
  static barEdge(): string {
    return themeStore.isDark ? '#3DFFFFFF' : '#8CFFFFFF';
  }

  /** 顶部扫光：横向渐变高光，营造玻璃折角的镜面反光。 */
  static barSheen(): Array<GlassStop> {
    return [
      ['#00FFFFFF', 0.0],
      ['#80FFFFFF', 0.5],
      ['#00FFFFFF', 1.0]
    ];
  }

  /** 玻璃条浮起阴影颜色。 */
  static barShadow(): string {
    return themeStore.isDark ? '#44000000' : '#2E000000';
  }

  /** 玻璃小圆钮（播放键等）的底色：亮玻璃珠。 */
  static beadBg(): string {
    return themeStore.isDark ? '#33FFFFFF' : '#8CFFFFFF';
  }

  /** 玻璃小圆钮的边缘高光。 */
  static beadEdge(): string {
    return themeStore.isDark ? '#55FFFFFF' : '#B3FFFFFF';
  }

  // ---------------- 沉浸光感（封面主色环境光） ----------------
  // 以当前曲目封面主色为光源：胶囊内画径向光晕（光源在封面/页签中心），
  // 胶囊外以同色柔光替代纯黑投影，"音乐照亮底栏"且随换曲实时变色。

  /** 环境光径向渐变色标：中心最亮、向边缘衰减到透明；深色主题稍强以保证可见。 */
  static ambientStops(): Array<GlassStop> {
    const tint: string = colorService.tintHex;
    if (themeStore.isDark) {
      return [
        [ColorService.withAlpha(tint, 0.32), 0.0],
        [ColorService.withAlpha(tint, 0.12), 0.55],
        [ColorService.withAlpha(tint, 0.0), 1.0]
      ];
    }
    return [
      [ColorService.withAlpha(tint, 0.20), 0.0],
      [ColorService.withAlpha(tint, 0.07), 0.55],
      [ColorService.withAlpha(tint, 0.0), 1.0]
    ];
  }

  /** 玻璃条外发光：跟随封面主色的柔光投影；浮起深度由 offsetY/radius 保留。 */
  static ambientGlow(): string {
    const tint: string = colorService.tintHex;
    return themeStore.isDark
      ? ColorService.withAlpha(tint, 0.42)
      : ColorService.withAlpha(tint, 0.30);
  }
}
