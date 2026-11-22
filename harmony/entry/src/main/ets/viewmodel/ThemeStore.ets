/**
 * 主题 Store：模式解析、调色板、界面缩放与毛玻璃强度。
 */
import { Palette, DARK_PALETTE, LIGHT_PALETTE } from '../common/Palette';
import { ThemeMode } from '../model/SettingsModels';
import { colorService } from '../service/ColorService';

@ObservedV2
export class ThemeStore {
  @Trace mode: ThemeMode = ThemeMode.SYSTEM;
  @Trace systemDark: boolean = true;
  @Trace uiScale: number = 1.0;
  @Trace blurAlpha: number = 0.6;

  get isDark(): boolean {
    if (this.mode === ThemeMode.DARK) {
      return true;
    }
    if (this.mode === ThemeMode.LIGHT) {
      return false;
    }
    return this.systemDark;
  }

  get palette(): Palette {
    return this.isDark ? DARK_PALETTE : LIGHT_PALETTE;
  }

  /** 系统材质（沉浸玻璃）亮度跟随系统，与应用主题可能不一致。 */
  get surfaceDark(): boolean {
    return this.systemDark;
  }

  /** 绘制在系统材质上的文字/图标使用的色板，需与材质亮度一致。 */
  get surfacePalette(): Palette {
    return this.systemDark ? DARK_PALETTE : LIGHT_PALETTE;
  }

  get blurStyle(): BlurStyle {
    if (this.blurAlpha < 0.35) {
      return BlurStyle.Thin;
    }
    if (this.blurAlpha < 0.7) {
      return BlurStyle.Regular;
    }
    return BlurStyle.Thick;
  }

  get blurAmount(): number {
    return 8 + this.blurAlpha * 26;
  }

  font(base: number): number {
    return Math.round(base * this.uiScale * 10) / 10;
  }

  space(base: number): number {
    return Math.round(base * Math.min(this.uiScale, 1.15) * 10) / 10;
  }

  private colorModeApplier: ((mode: ThemeMode) => void) | null = null;

  setColorModeApplier(applier: (mode: ThemeMode) => void): void {
    this.colorModeApplier = applier;
  }

  setMode(mode: ThemeMode): void {
    this.mode = mode;
    colorService.onThemeChanged(this.isDark);
    if (this.colorModeApplier !== null) {
      this.colorModeApplier(mode);
    }
  }

  setSystemDark(dark: boolean): void {
    this.systemDark = dark;
    colorService.onThemeChanged(this.isDark);
  }

  setScale(scale: number): void {
    this.uiScale = scale;
  }

  setBlur(alpha: number): void {
    this.blurAlpha = alpha;
  }
}

export const themeStore: ThemeStore = new ThemeStore();

