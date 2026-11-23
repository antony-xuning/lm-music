/**
 * 沉浸光感（系统玻璃材质）统一工具。
 *
 * 生效范围遵循 HarmonyOS API 26 约束：系统 ImmersiveMaterial 只在
 * Navigation / NavDestination 标题栏、底部悬浮 TabBar、弹窗类组件、Slider/Toggle/Select 上生效。
 * 因此本工具提供两类能力：
 *   1) 系统材质工厂（title / dock），供上述生效位置调用；
 *   2) backdrop() 玻璃衬底渐变，铺在页面最底层，为上层玻璃材质提供可透出的内容层次，
 *      深浅主题自适应，避免纯色背景下"材质无感"。
 */
import { uiMaterial } from '@kit.ArkUI';
import { themeStore } from '../viewmodel/ThemeStore';

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

  /** 底部悬浮 Dock 沉浸式材质（与标题栏统一质感）。 */
  static dock(): uiMaterial.ImmersiveMaterial {
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
    ['#06F2F2F7', 0.45],
    ['#00F2F2F7', 1.0]
  ];

  /** 当前主题对应的玻璃衬底渐变色标（在 build 中读取以建立响应式依赖）。 */
  static backdrop(): Array<GlassStop> {
    return themeStore.isDark ? ImmersiveGlass.DARK_BACKDROP : ImmersiveGlass.LIGHT_BACKDROP;
  }

  /** 统一的渐变角度。 */
  static readonly ANGLE: number = 135;
}
