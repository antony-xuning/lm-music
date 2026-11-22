/**
 * 封面主色服务：解码 64×64 缩略图 -> effectKit 取主色 -> 按主题明度校正并缓存。
 * 取色异步进行，失败回退品牌红，不阻塞界面渲染。
 */
import { image } from '@kit.ImageKit';
import { effectKit } from '@kit.ArkGraphics2D';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';

const SCOPE: string = 'ColorService';

/** RGB 分量容器（避免使用未类型化对象字面量）。 */
class RgbColor {
  red: number = 0;
  green: number = 0;
  blue: number = 0;
}

@ObservedV2
export class ColorService {
  @Trace tintHex: string = AppConstants.BRAND_RED;

  private cache: Map<string, string> = new Map<string, string>();
  private lastCover: string = '';
  private lastDark: boolean = false;
  private extractingKey: string = '';

  /** 曲目封面变化时调用（PlayerStore 在封面解析成功后触发）。 */
  setCover(coverUri: string, isDark: boolean): void {
    this.lastDark = isDark;
    if (coverUri === this.lastCover && this.tintHex.length > 0) {
      return;
    }
    this.lastCover = coverUri;
    this.apply(coverUri, isDark);
  }

  /** 主题切换后重新按明度校正。 */
  onThemeChanged(isDark: boolean): void {
    if (this.lastDark === isDark) {
      return;
    }
    this.lastDark = isDark;
    this.apply(this.lastCover, isDark);
  }

  private apply(coverUri: string, isDark: boolean): void {
    if (coverUri.length === 0) {
      this.tintHex = AppConstants.BRAND_RED;
      return;
    }
    const key: string = `${coverUri}|${isDark ? 'd' : 'l'}`;
    const cached: string | undefined = this.cache.get(key);
    if (cached !== undefined) {
      this.tintHex = cached;
      return;
    }
    if (this.extractingKey === key) {
      return;
    }
    this.extractingKey = key;
    this.extract(coverUri, isDark, key);
  }

  private async extract(coverUri: string, isDark: boolean, key: string): Promise<void> {
    let source: image.ImageSource | null = null;
    let pixelMap: image.PixelMap | null = null;
    try {
      source = image.createImageSource(coverUri);
      const options: image.DecodingOptions = {
        desiredSize: { width: 64, height: 64 }
      };
      pixelMap = await source.createPixelMap(options);
      const picker: effectKit.ColorPicker = await effectKit.createColorPicker(pixelMap);
      const color: effectKit.Color = picker.getMainColorSync();
      const corrected: string = this.correct(color.red, color.green, color.blue, isDark);
      this.cache.set(key, corrected);
      this.tintHex = corrected;
      if (this.cache.size > 60) {
        const keys: string[] = [];
        this.cache.forEach((value: string, cacheKey: string) => {
          keys.push(cacheKey);
        });
        if (keys.length > 0) {
          this.cache.delete(keys[0]);
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `color extract failed: ${err.code}`);
      this.tintHex = AppConstants.BRAND_RED;
    } finally {
      this.extractingKey = '';
      if (pixelMap !== null) {
        try {
          pixelMap.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release pixel map failed');
        }
      }
      if (source !== null) {
        try {
          await source.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release image source failed');
        }
      }
    }
  }

  /** 明度校正：浅色主题避免过亮，深色主题避免过暗，保证 Dock 上文字可读。 */
  private correct(red: number, green: number, blue: number, isDark: boolean): string {
    const color: RgbColor = new RgbColor();
    color.red = Math.max(0, Math.min(red, 255));
    color.green = Math.max(0, Math.min(green, 255));
    color.blue = Math.max(0, Math.min(blue, 255));
    let luminance: number = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    if (isDark && luminance < 70) {
      color.red = Math.round(color.red + (255 - color.red) * 0.35);
      color.green = Math.round(color.green + (255 - color.green) * 0.35);
      color.blue = Math.round(color.blue + (255 - color.blue) * 0.35);
    } else if (!isDark && luminance > 190) {
      color.red = Math.round(color.red * 0.72);
      color.green = Math.round(color.green * 0.72);
      color.blue = Math.round(color.blue * 0.72);
    }
    luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue;
    if (luminance < 24) {
      return AppConstants.BRAND_RED;
    }
    return ColorService.toHex(color.red, color.green, color.blue);
  }

  private static toHex(red: number, green: number, blue: number): string {
    return `#${ColorService.channel(red)}${ColorService.channel(green)}${ColorService.channel(blue)}`;
  }

  private static channel(value: number): string {
    const clamped: number = Math.max(0, Math.min(Math.round(value), 255));
    const text: string = clamped.toString(16).toUpperCase();
    return text.length >= 2 ? text : `0${text}`;
  }

  /** 把 #RRGGBB 叠加透明度，例如 alphaRatio 0.1 -> #1Axxxxxx。 */
  static withAlpha(hex: string, alphaRatio: number): string {
    const normalized: string = hex.startsWith('#') ? hex.substring(1) : hex;
    if (normalized.length !== 6) {
      return `#1A${AppConstants.BRAND_RED.substring(1)}`;
    }
    const alpha: number = Math.max(0, Math.min(Math.round(alphaRatio * 255), 255));
    const alphaHex: string = alpha.toString(16).toUpperCase();
    return `#${alphaHex.length >= 2 ? alphaHex : '0' + alphaHex}${normalized.toUpperCase()}`;
  }
}

export const colorService: ColorService = new ColorService();

