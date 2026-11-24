/**
 * 歌词视图：逐行解析、当前行高亮居中滚动、点击行跳转。
 */
import { LyricDoc, LyricLine, LyricThemeConfig, LyricThemeHelper } from '../model/LyricModels';
import { PlayableItem } from '../model/MediaModels';
import { LyricParser } from '../service/LyricParser';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';

@ComponentV2
export struct LyricsPanel {
  @Param idleColor: string = '#8A8A93';
  @Local doc: LyricDoc = LyricDoc.empty();
  @Local activeIndex: number = -1;
  @Local currentTrackId: string = '';

  private scroller: Scroller = new Scroller();
  private timerId: number = -1;

  aboutToAppear(): void {
    this.reloadIfNeeded();
    this.timerId = setInterval(() => {
      this.tick();
    }, 280);
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private lyricText(): string {
    return playerStore.lyricText;
  }

  private reloadIfNeeded(): void {
    const item: PlayableItem | null = playerStore.current;
    const trackId: string = item !== null ? item.id : '';
    if (trackId === this.currentTrackId && this.doc.lines.length > 0) {
      return;
    }
    this.currentTrackId = trackId;
    this.doc = LyricParser.parse(this.lyricText());
    this.activeIndex = -1;
    setTimeout(() => {
      this.tick();
    }, 60);
  }

  private tick(): void {
    this.reloadIfNeeded();
    const index: number = LyricParser.activeIndex(this.doc, playerStore.positionMs, overlayStore.lyricOffsetMs);
    if (index !== this.activeIndex) {
      this.activeIndex = index;
      if (index >= 0) {
        this.scroller.scrollToIndex(index + 1, true, ScrollAlign.CENTER);
      }
    }
  }

  private theme(): LyricThemeConfig {
    return LyricThemeHelper.config(overlayStore.lyricTheme);
  }

  @Builder
  lyricLine(line: LyricLine, index: number) {
    Row() {
      Text(line.text)
        .fontSize(this.activeIndex === index ? overlayStore.lyricFontSize + 2 : overlayStore.lyricFontSize)
        .fontWeight(this.activeIndex === index ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.activeIndex === index ? this.theme().activeColor : this.idleColor)
        .opacity(this.activeIndex === index ? 1 : 0.72)
        .textAlign(TextAlign.Center)
        .width('100%')
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    }
    .width('100%')
    .onClick(() => {
      playerStore.seek(Math.max(line.timeMs - overlayStore.lyricOffsetMs, 0));
    })
  }

  build() {
    if (!this.doc.isSynced) {
      Column({ space: 10 }) {
        Text('暂无歌词')
          .fontSize(15)
          .fontColor(this.theme().activeColor)
        Text('服务器未返回这首曲目的歌词，或歌词没有时间轴')
          .fontSize(11)
          .fontColor(this.idleColor)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      List({ scroller: this.scroller }) {
        ListItem() {
          Column().height(120)
        }

        ForEach(this.doc.lines, (line: LyricLine, index: number) => {
          ListItem() {
            this.lyricLine(line, index)
          }
        }, (line: LyricLine) => `${line.timeMs}_${line.text}`)

        ListItem() {
          Column().height(160)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .cachedCount(6)
      .lanes(1)
      .fadingEdge(true)
    }
  }
}
