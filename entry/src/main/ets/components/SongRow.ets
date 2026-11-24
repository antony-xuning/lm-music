/**
 * 统一歌曲行：封面 / 标题 / 副标题 / 来源徽章 / 音质 / 时长 / 多选 / 正在播放高亮。
 * 支持 Repeat 虚拟滚动：传入 ri（RepeatItem 整体）时以 ri.item/ri.index 为准；
 * 若只拆开传 item/index 会丢失状态联动导致渲染异常，因此必须整体传入 ri。
 */
import { MediaSource, MediaSourceHelper, Song } from '../model/MediaModels';
import { Formatters } from '../service/Formatters';
import { playerStore } from '../viewmodel/PlayerStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { SongCover } from './SongCover';

@ComponentV2
export struct SongRow {
  @Param song: Song = new Song();
  @Param index: number = -1;
  /** Repeat 虚拟滚动数据项：与 song/index 互斥使用。 */
  @Param ri: RepeatItem<Song> | null = null;
  @Param showCover: boolean = true;
  @Param showDuration: boolean = true;
  @Param showMore: boolean = true;
  @Param selected: boolean = false;
  @Param selectionMode: boolean = false;
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Event onTap: (song: Song) => void = () => {
  };
  @Event onMore: (song: Song) => void = () => {
  };
  @Event onSelect: (song: Song) => void = () => {
  };

  private rowSong(): Song {
    return this.ri !== null ? this.ri.item : this.song;
  }

  private rowIndex(): number {
    return this.ri !== null ? this.ri.index : this.index;
  }

  private isCurrent(): boolean {
    const current = playerStore.current;
    return current !== null && current.songId === this.rowSong().id;
  }

  private badgeColor(): string {
    if (this.rowSong().source === MediaSource.SERVER_FILE) {
      return '#4E8CFF';
    }
    if (this.rowSong().source === MediaSource.ONLINE) {
      return '#FFB44C';
    }
    return this.accent;
  }

  private qualityText(): string {
    if (this.rowSong().qualitys.length > 0) {
      return this.rowSong().qualitys;
    }
    return this.rowSong().format;
  }

  build() {
    Row({ space: 10 }) {
      if (this.selectionMode) {
        Stack() {
          Column()
            .width(20)
            .height(20)
            .borderRadius(10)
            .border({ width: 1.5, color: this.selected ? this.accent : themeStore.palette.softBorder })
            .backgroundColor(this.selected ? this.accent : Color.Transparent)
            .animation({ duration: 150, curve: Curve.EaseOut })
          if (this.selected) {
            Image($r('app.media.ic_check'))
              .width(12)
              .height(12)
              .fillColor('#FFFFFF')
              .transition(TransitionEffect.OPACITY.animation({ duration: 150, curve: Curve.EaseOut })
                .combine(TransitionEffect.scale({ x: 0.4, y: 0.4 })))
          }
        }
        .width(22)
        .height(22)
      } else if (this.rowIndex() >= 0) {
        Text(`${this.rowIndex() + 1}`)
          .fontSize(themeStore.font(11))
          .fontColor(this.isCurrent() ? this.accent : this.subColor)
          .width(18)
          .textAlign(TextAlign.Center)
      }

      if (this.showCover) {
        SongCover({
          song: this.rowSong(),
          artworkSize: 44,
          radius: 10,
          showRing: this.isCurrent(),
          cacheKey: this.rowSong().id + '_' + this.rowSong().mtime
        })
      }

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(this.rowSong().title)
            .fontSize(themeStore.font(14.5))
            .fontWeight(this.isCurrent() ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.isCurrent() ? this.accent : this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(MediaSourceHelper.label(this.rowSong().source))
            .fontSize(themeStore.font(9))
            .fontColor(this.badgeColor())
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(4)
            .border({ width: 1, color: this.badgeColor() })
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(`${this.rowSong().artist}${this.rowSong().album.length > 0 ? ' · ' + this.rowSong().album : ''}`)
            .fontSize(themeStore.font(11.5))
            .fontColor(this.subColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.rowSong().source !== MediaSource.LOCAL) {
            Text(this.qualityText())
              .fontSize(themeStore.font(9))
              .fontColor(this.subColor)
              .maxLines(1)
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.showDuration) {
        Text(Formatters.duration(this.rowSong().durationMs))
          .fontSize(themeStore.font(11))
          .fontColor(this.subColor)
      }

      if (this.showMore && !this.selectionMode) {
        Image($r('app.media.ic_more'))
          .width(18)
          .height(18)
          .fillColor(this.subColor)
          .padding(4)
          .stateStyles({
            pressed: { .scale({ x: 0.82, y: 0.82 }).opacity(0.6) },
            normal: { .scale({ x: 1, y: 1 }).opacity(1) }
          })
          .animation({ duration: 120, curve: Curve.EaseOut })
          .onClick(() => {
            this.onMore(this.rowSong());
          })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 2, right: 2 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.selected ? '#14FA2D48' : Color.Transparent)
    .borderRadius(10)
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      if (this.selectionMode) {
        this.onSelect(this.rowSong());
      } else {
        this.onTap(this.rowSong());
      }
    })
  }
}
