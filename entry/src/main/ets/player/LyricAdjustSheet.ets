/**
 * 歌词调节面板：字号、时间偏移与 6 套歌词主题。
 */
import { SheetShell } from '../components/SheetShell';
import { AppSlider } from '../components/AppSlider';
import { LYRIC_THEMES, LyricThemeConfig, LyricThemeHelper } from '../model/LyricModels';
import { overlayStore } from '../viewmodel/OverlayStore';
import { preferencesRepo } from '../data/PreferencesRepo';
import { themeStore } from '../viewmodel/ThemeStore';
import { Debouncer } from '../common/Utils';

const KEY_LYRIC: string = 'lm_lyric_prefs';

export interface LyricPrefsRaw {
  fontSize?: number;
  offsetMs?: number;
  theme?: string;
}

const lyricSaver: Debouncer = new Debouncer(200);

@ComponentV2
export struct LyricAdjustSheet {
  @Local fontSize: number = 18;
  @Local offsetMs: number = 0;

  aboutToAppear(): void {
    this.fontSize = overlayStore.lyricFontSize;
    this.offsetMs = overlayStore.lyricOffsetMs;
  }

  private persist(): void {
    lyricSaver.run(() => {
      const raw: LyricPrefsRaw = {
        fontSize: overlayStore.lyricFontSize,
        offsetMs: overlayStore.lyricOffsetMs,
        theme: overlayStore.lyricTheme
      };
      preferencesRepo.putString(KEY_LYRIC, JSON.stringify(raw));
    });
  }

  private applyFont(value: number): void {
    this.fontSize = value;
    overlayStore.setLyricFontSize(value);
    this.persist();
  }

  private shiftOffset(delta: number): void {
    const next: number = Math.max(-1000, Math.min(1000, this.offsetMs + delta));
    this.offsetMs = next;
    overlayStore.setLyricOffset(next);
    this.persist();
  }

  @Builder
  themeChip(config: LyricThemeConfig) {
    Column({ space: 6 }) {
      Column()
        .width(44)
        .height(44)
        .borderRadius(22)
        .backgroundColor(config.panelColor)
        .border({
          width: overlayStore.lyricTheme === config.theme ? 2 : 1,
          color: overlayStore.lyricTheme === config.theme ? themeStore.palette.brand : '#33FFFFFF'
        })
      Text(config.name)
        .fontSize(10)
        .fontColor(overlayStore.lyricTheme === config.theme
          ? themeStore.palette.brand : themeStore.palette.sub)
    }
    .onClick(() => {
      overlayStore.setLyricTheme(config.theme);
      this.persist();
    })
  }

  build() {
    SheetShell({
      sheetTitle: '歌词显示',
      sheetSubtitle: `当前样式：${LyricThemeHelper.config(overlayStore.lyricTheme).name}`,
      panelColor: themeStore.palette.card,
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      onClose: () => {
        overlayStore.closeSheet();
      }
    }) {
      Scroll() {
        Column({ space: 16 }) {
          Column({ space: 6 }) {
            Row() {
              Text('字号')
                .fontSize(12.5)
                .fontColor(themeStore.palette.text)
              Blank()
              Text(`${Math.round(this.fontSize)}`)
                .fontSize(12)
                .fontColor(themeStore.palette.brand)
            }
            .width('100%')

            AppSlider({
              sliderValue: this.fontSize,
              minValue: 12,
              maxValue: 28,
              stepValue: 1,
              accent: themeStore.palette.brand,
              onValueChange: (value: number) => {
                this.applyFont(value);
              },
              onValueFinish: (value: number) => {
                this.applyFont(value);
              }
            })

            Row() {
              Text('小')
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
              Blank()
              Text('大')
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Row() {
              Text('时间偏移')
                .fontSize(12.5)
                .fontColor(themeStore.palette.text)
              Blank()
              Text(`${this.offsetMs > 0 ? '+' : ''}${this.offsetMs} ms`)
                .fontSize(12)
                .fontColor(themeStore.palette.brand)
            }
            .width('100%')

            Row({ space: 8 }) {
              Text('-0.5s 提前')
                .fontSize(11)
                .fontColor(themeStore.palette.text)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor('#22FFFFFF')
                .onClick(() => {
                  this.shiftOffset(-500);
                })

              Text('-0.1s')
                .fontSize(11)
                .fontColor(themeStore.palette.text)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor('#22FFFFFF')
                .onClick(() => {
                  this.shiftOffset(-100);
                })

              Text('+0.1s')
                .fontSize(11)
                .fontColor(themeStore.palette.text)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor('#22FFFFFF')
                .onClick(() => {
                  this.shiftOffset(100);
                })

              Text('+0.5s 延后')
                .fontSize(11)
                .fontColor(themeStore.palette.text)
                .padding({ left: 12, right: 12, top: 7, bottom: 7 })
                .borderRadius(14)
                .backgroundColor('#22FFFFFF')
                .onClick(() => {
                  this.shiftOffset(500);
                })
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)

          Column({ space: 10 }) {
            Text('歌词主题')
              .fontSize(12.5)
              .fontColor(themeStore.palette.text)

            Row({ space: 12 }) {
              ForEach(LYRIC_THEMES.slice(0, 3), (config: LyricThemeConfig) => {
                this.themeChip(config)
              }, (config: LyricThemeConfig) => config.theme)
            }
            .width('100%')

            Row({ space: 12 }) {
              ForEach(LYRIC_THEMES.slice(3), (config: LyricThemeConfig) => {
                this.themeChip(config)
              }, (config: LyricThemeConfig) => config.theme)
            }
            .width('100%')
          }
          .alignItems(HorizontalAlign.Start)

          Text('调节会立即应用到歌词视图，并随应用重启保持。')
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
            .margin({ bottom: 10 })
        }
        .width('100%')
        .padding({ top: 4 })
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .constraintSize({ maxHeight: 460 })
    }
  }
}

export class LyricPrefs {
  static async restore(): Promise<void> {
    const text: string = await preferencesRepo.getString(KEY_LYRIC, '');
    if (text.length === 0) {
      return;
    }
    try {
      const raw = JSON.parse(text) as LyricPrefsRaw;
      if (typeof raw.fontSize === 'number') {
        overlayStore.setLyricFontSize(Math.max(12, Math.min(28, raw.fontSize)));
      }
      if (typeof raw.offsetMs === 'number') {
        overlayStore.setLyricOffset(Math.max(-1000, Math.min(1000, raw.offsetMs)));
      }
      if (typeof raw.theme === 'string') {
        const themes: LyricThemeConfig[] = LYRIC_THEMES;
        for (let i = 0; i < themes.length; i++) {
          if (themes[i].theme === raw.theme) {
            overlayStore.setLyricTheme(themes[i].theme);
            break;
          }
        }
      }
    } catch (error) {
      // 忽略损坏的歌词偏好，使用默认值
    }
  }
}

