/**
 * 语义色板：深色 / 浅色两套，所有 UI 颜色从这里读取。
 */
export class Palette {
  bg: string;
  card: string;
  cardSoft: string;
  text: string;
  sub: string;
  divider: string;
  brand: string;
  scrim: string;
  onBrand: string;
  chipBg: string;
  headerGlass: string;
  isDark: boolean;

  constructor(bg: string, card: string, cardSoft: string, text: string, sub: string, divider: string,
    brand: string, scrim: string, onBrand: string, chipBg: string, headerGlass: string, isDark: boolean) {
    this.bg = bg;
    this.card = card;
    this.cardSoft = cardSoft;
    this.text = text;
    this.sub = sub;
    this.divider = divider;
    this.brand = brand;
    this.scrim = scrim;
    this.onBrand = onBrand;
    this.chipBg = chipBg;
    this.headerGlass = headerGlass;
    this.isDark = isDark;
  }
}

export const DARK_PALETTE: Palette = new Palette(
  '#101014', '#1C1C20', '#242429', '#F5F5F7', '#A1A1A8', '#2A2A30',
  '#FA2D48', '#000000', '#FFFFFF', '#2A2A30', '#1A1A1FCC', true
);

export const LIGHT_PALETTE: Palette = new Palette(
  '#F2F2F7', '#FFFFFF', '#F7F7FA', '#111113', '#636366', '#E5E5EA',
  '#FA2D48', '#000000', '#FFFFFF', '#ECECF1', '#F7F7FACC', false
);

/** 渐变封面色组（start / end），供 Artwork 与卡片按种子轮换。 */
export class GradientPair {
  start: string;
  end: string;

  constructor(start: string, end: string) {
    this.start = start;
    this.end = end;
  }
}

export const GRADIENTS: GradientPair[] = [
  new GradientPair('#FF6B6B', '#7A1E2B'),
  new GradientPair('#4E8CFF', '#141B4D'),
  new GradientPair('#FFB44C', '#7A3B0A'),
  new GradientPair('#2ED3A6', '#0B3F37'),
  new GradientPair('#A66BFF', '#2C1149'),
  new GradientPair('#FF7AC6', '#4C1233'),
  new GradientPair('#67D4FF', '#0E3350'),
  new GradientPair('#C8E05A', '#3A4413'),
  new GradientPair('#FF9A5A', '#4A1B10'),
  new GradientPair('#8FA4FF', '#1B2050'),
  new GradientPair('#E1E1E8', '#3A3A45'),
  new GradientPair('#3BD1C4', '#11433F')
];

export class GradientHelper {
  static pair(seed: number): GradientPair {
    const total: number = GRADIENTS.length;
    if (total === 0) {
      return new GradientPair('#3A3A45', '#1A1A1F');
    }
    const index: number = Math.abs(Math.floor(seed)) % total;
    return GRADIENTS[index];
  }

  static colors(seed: number): string[] {
    const pair: GradientPair = GradientHelper.pair(seed);
    return [pair.start, pair.end];
  }
}

/** 字号阶梯（随界面缩放系数放大）。 */
export const FONT_SCALE_STEPS: number[] = [0.9, 1.0, 1.1, 1.2];
