/**
 * 统一歌曲行：封面 / 标题 / 副标题 / 来源徽章 / 音质 / 时长 / 多选 / 正在播放高亮。
 */
import { MediaSource, MediaSourceHelper, Song } from '../model/MediaModels';
import { Formatters } from '../service/Formatters';
import { playerStore } from '../viewmodel/PlayerStore';
import { SongCover } from './SongCover';

@ComponentV2
export struct SongRow {
  @Param song: Song = new Song();
  @Param index: number = -1;
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

  private isCurrent(): boolean {
    const current = playerStore.current;
    return current !== null && current.songId === this.song.id;
  }

  private badgeColor(): string {
    if (this.song.source === MediaSource.SERVER_FILE) {
      return '#4E8CFF';
    }
    if (this.song.source === MediaSource.ONLINE) {
      return '#FFB44C';
    }
    return this.accent;
  }

  private qualityText(): string {
    if (this.song.qualitys.length > 0) {
      return this.song.qualitys;
    }
    return this.song.format;
  }

  build() {
    Row({ space: 10 }) {
      if (this.selectionMode) {
        Stack() {
          Column()
            .width(20)
            .height(20)
            .borderRadius(10)
            .border({ width: 1.5, color: this.selected ? this.accent : '#66FFFFFF' })
            .backgroundColor(this.selected ? this.accent : Color.Transparent)
          if (this.selected) {
            Image($r('app.media.ic_check'))
              .width(12)
              .height(12)
              .fillColor('#FFFFFF')
          }
        }
        .width(22)
        .height(22)
      } else if (this.index >= 0) {
        Text(`${this.index + 1}`)
          .fontSize(11)
          .fontColor(this.isCurrent() ? this.accent : this.subColor)
          .width(18)
          .textAlign(TextAlign.Center)
      }

      if (this.showCover) {
        SongCover({
          song: this.song,
          artworkSize: 44,
          radius: 10,
          showRing: this.isCurrent(),
          cacheKey: this.song.id + '_' + this.song.mtime
        })
      }

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(this.song.title)
            .fontSize(14.5)
            .fontWeight(this.isCurrent() ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.isCurrent() ? this.accent : this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(MediaSourceHelper.label(this.song.source))
            .fontSize(9)
            .fontColor(this.badgeColor())
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .borderRadius(4)
            .border({ width: 1, color: this.badgeColor() })
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(`${this.song.artist}${this.song.album.length > 0 ? ' · ' + this.song.album : ''}`)
            .fontSize(11.5)
            .fontColor(this.subColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.song.source !== MediaSource.LOCAL) {
            Text(this.qualityText())
              .fontSize(9)
              .fontColor(this.subColor)
              .maxLines(1)
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.showDuration) {
        Text(Formatters.duration(this.song.durationMs))
          .fontSize(11)
          .fontColor(this.subColor)
      }

      if (this.showMore && !this.selectionMode) {
        Image($r('app.media.ic_more'))
          .width(18)
          .height(18)
          .fillColor(this.subColor)
          .padding(4)
          .onClick(() => {
            this.onMore(this.song);
          })
      }
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 2, right: 2 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.selected ? '#14FA2D48' : Color.Transparent)
    .borderRadius(10)
    .onClick(() => {
      if (this.selectionMode) {
        this.onSelect(this.song);
      } else {
        this.onTap(this.song);
      }
    })
  }
}
