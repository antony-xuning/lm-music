/**
 * 播放器「歌曲」视图：大封面（优先远程缓存） + 曲目信息 + 来源/音质徽章 + 红心。
 */
import { MediaSource, MediaSourceHelper, PlayableItem, Song } from '../model/MediaModels';
import { Formatters } from '../service/Formatters';
import { Artwork } from '../components/Artwork';
import { BadgeView } from '../components/Badge';
import { libraryStore } from '../viewmodel/LibraryStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct CoverPanel {
  @Param artworkSize: number = 280;
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';

  private titleText(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.title : '未在播放';
  }

  private subtitleText(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.subtitle : '';
  }

  private albumText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return '';
    }
    if (item.songId.length > 0) {
      const song = libraryStore.findSong(item.songId);
      if (song !== null) {
        return song.album;
      }
    }
    return item.isPodcast ? '播客单集' : '';
  }

  private isFavorite(): boolean {
    const item: PlayableItem | null = playerStore.current;
    if (item === null || item.songId.length === 0) {
      return false;
    }
    return libraryStore.isFavorite(item.songId);
  }

  private remoteCover(): string {
    if (playerStore.coverUri.length > 0) {
      return playerStore.coverUri;
    }
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.coverUrl : '';
  }

  private qualityText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return '未知';
    }
    if (item.qualitys.length > 0) {
      return item.qualitys;
    }
    if (item.songId.length > 0) {
      const song = libraryStore.findSong(item.songId);
      if (song !== null) {
        return Formatters.qualityBadge(song.format, song.bitRate);
      }
    }
    return item.isPodcast ? '播客音频' : '在线音源';
  }

  private sizeText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null || item.songId.length === 0) {
      return '';
    }
    const song = libraryStore.findSong(item.songId);
    return song !== null && song.sizeBytes > 0 ? Formatters.bytes(song.sizeBytes) : '';
  }

  private sourceOfItem(): MediaSource {
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.mediaSource : MediaSource.LOCAL;
  }

  private toggleFavorite(): void {
    const item: PlayableItem | null = playerStore.current;
    if (item === null || (item.songId.length === 0 && item.platformSongId.length === 0)) {
      return;
    }
    const song = item.songId.length > 0 ? libraryStore.findSong(item.songId) : null;
    if (song !== null) {
      libraryStore.toggleFavoriteFor(song);
      return;
    }
    libraryStore.toggleFavoriteFor(newSongFrom(item));
  }

  @Builder
  badges() {
    Row({ space: 6 }) {
      BadgeView({ text: MediaSourceHelper.label(this.sourceOfItem()),
        tone: MediaSourceHelper.badgeTone(this.sourceOfItem()) })
      BadgeView({ text: this.qualityText(), tone: 'glass' })
      if (this.sizeText().length > 0) {
        BadgeView({ text: this.sizeText(), tone: 'glass' })
      }
    }
  }

  build() {
    Column({ space: 12 }) {
      Stack() {
        Column()
          .width(this.artworkSize)
          .height(this.artworkSize)
          .borderRadius(this.artworkSize / 2.4)
          .backgroundColor('#1AFFFFFF')
          .shadow({ radius: 40, color: '#66000000', offsetY: 16 })

        Artwork({
          seed: playerStore.current !== null ? playerStore.current.coverSeed : 0,
          artworkSize: this.artworkSize,
          radius: this.artworkSize / 2.4,
          title: this.titleText(),
          showRing: true,
          showInitial: false,
          remoteUrl: this.remoteCover()
        })

        Stack() {
          Image(this.isFavorite() ? $r('app.media.ic_heart_fill') : $r('app.media.ic_heart'))
            .width(18)
            .height(18)
            .fillColor(this.isFavorite() ? this.accent : this.textColor)
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('#33000000')
        .position({ x: this.artworkSize - 50, y: this.artworkSize - 50 })
        .onClick(() => {
          this.toggleFavorite();
        })
      }
      .width(this.artworkSize)
      .height(this.artworkSize)

      Column({ space: 4 }) {
        Text(this.titleText())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)

        Text(`${this.subtitleText()}${this.albumText().length > 0 ? ' · ' + this.albumText() : ''}`)
          .fontSize(12)
          .fontColor(this.subColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Center)

        this.badges()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 6 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

function newSongFrom(item: PlayableItem): Song {
  const song: Song = new Song();
  song.id = item.songId.length > 0 ? item.songId : item.id;
  song.title = item.title;
  song.artist = item.subtitle;
  song.album = '';
  song.durationMs = item.durationMs;
  song.coverUrl = item.coverUrl;
  song.qualitys = item.qualitys;
  song.filePath = item.filePath;
  song.platform = item.platform;
  song.platformSongId = item.platformSongId;
  song.source = item.mediaSource;
  song.serverId = item.serverId;
  song.audioRef = item.audioRef;
  return song;
}