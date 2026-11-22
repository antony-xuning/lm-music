/**
 * 歌词模型与歌词主题配置。
 */
export class LyricLine {
  timeMs: number = 0;
  text: string = '';

  constructor(timeMs: number, text: string) {
    this.timeMs = timeMs;
    this.text = text;
  }
}

export class LyricDoc {
  lines: LyricLine[] = [];
  isSynced: boolean = false;
  offsetMs: number = 0;
  source: string = '';

  static empty(): LyricDoc {
    const doc: LyricDoc = new LyricDoc();
    doc.lines = [new LyricLine(0, '暂无歌词')];
    doc.isSynced = false;
    return doc;
  }
}

export enum LyricTheme {
  CLASSIC = 'classic',
  LEMON = 'lemon',
  OCEAN = 'ocean',
  FOREST = 'forest',
  SUNSET = 'sunset',
  MONO = 'mono'
}

export class LyricThemeConfig {
  theme: LyricTheme;
  name: string;
  activeColor: string;
  idleColor: string;
  panelColor: string;

  constructor(theme: LyricTheme, name: string, activeColor: string, idleColor: string, panelColor: string) {
    this.theme = theme;
    this.name = name;
    this.activeColor = activeColor;
    this.idleColor = idleColor;
    this.panelColor = panelColor;
  }
}

export const LYRIC_THEMES: LyricThemeConfig[] = [
  new LyricThemeConfig(LyricTheme.CLASSIC, '经典白', '#FFFFFF', '#8A8A93', '#3A3A45'),
  new LyricThemeConfig(LyricTheme.LEMON, '柠檬红', '#FA2D48', '#8A5A63', '#4A1B24'),
  new LyricThemeConfig(LyricTheme.OCEAN, '海盐蓝', '#6FC9FF', '#5A7890', '#1B3A50'),
  new LyricThemeConfig(LyricTheme.FOREST, '森语绿', '#7CE0A8', '#5C7A66', '#1E3A2C'),
  new LyricThemeConfig(LyricTheme.SUNSET, '落日橙', '#FFB46B', '#8A6A4A', '#4A2E1B'),
  new LyricThemeConfig(LyricTheme.MONO, '极简灰', '#E6E6EC', '#7A7A83', '#33333A')
];

export class LyricThemeHelper {
  static config(theme: LyricTheme): LyricThemeConfig {
    for (let i = 0; i < LYRIC_THEMES.length; i++) {
      if (LYRIC_THEMES[i].theme === theme) {
        return LYRIC_THEMES[i];
      }
    }
    return LYRIC_THEMES[0];
  }

  static next(theme: LyricTheme): LyricTheme {
    for (let i = 0; i < LYRIC_THEMES.length; i++) {
      if (LYRIC_THEMES[i].theme === theme) {
        const index: number = (i + 1) % LYRIC_THEMES.length;
        return LYRIC_THEMES[index].theme;
      }
    }
    return LYRIC_THEMES[0].theme;
  }
}
