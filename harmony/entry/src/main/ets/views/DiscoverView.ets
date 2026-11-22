/**
 * 发现页：按音源展示真实榜单、新歌首发、新碟首发与推荐歌单，各区块独立状态。
 */
import { AppConstants, DockMetrics } from '../common/Constants';
import { Artwork } from '../components/Artwork';
import { BadgeView } from '../components/Badge';
import { EmptyState } from '../components/EmptyState';
import { SectionHeader } from '../components/SectionHeader';
import { ServerStatusCard } from '../components/ServerStatusCard';
import { playVisualSong } from '../service/PlaybackLauncher';
import { Album, Playlist, Song } from '../model/MediaModels';
import { DiscoverCollectionKind, DiscoverCollectionParam, DiscoverToplistItem } from '../model/UiModels';
import { DiscoverService, playlistCardCount } from '../service/DiscoverService';
import { Formatters } from '../service/Formatters';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { discoverStore } from '../viewmodel/DiscoverStore';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';

@ComponentV2
export struct DiscoverView {
  @Param onOpenCollection: (param: DiscoverCollectionParam) => void = () => {
  };
  @Local refreshing: boolean = false;
  private scroller: Scroller = new Scroller();
  private homeToken: number = 0;
  private mounted: boolean = false;

  aboutToAppear(): void {
    this.mounted = true;
    this.homeToken = scrollChrome.setHomeTopHandler(() => {
      this.scrollToTop();
    });
    setTimeout(() => {
      if (!this.mounted) {
        return;
      }
      if (scrollChrome.consumePendingHomeTop()) {
        this.scrollToTop();
      }
    }, 80);
  }

  aboutToDisappear(): void {
    this.mounted = false;
    scrollChrome.clearHomeTopHandler(this.homeToken);
  }

  private scrollToTop(): void {
    this.scroller.scrollTo({
      xOffset: 0,
      yOffset: 0,
      animation: { duration: 240, curve: Curve.EaseOut }
    });
  }

  private async onRefresh(): Promise<void> {
    this.refreshing = true;
    await discoverStore.refresh();
    this.refreshing = false;
  }

  private openToplist(item: DiscoverToplistItem): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.TOPLIST,
      item.id, item.source, item.name));
  }

  private openAlbum(album: Album): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.ALBUM,
      album.remoteId.length > 0 ? album.remoteId : album.id, album.platform, album.title));
  }

  private openPlaylist(playlist: Playlist): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.PLAYLIST,
      playlist.id, playlist.platform, playlist.name));
  }

  private playSong(song: Song, list: Song[], index: number): void {
    playVisualSong(list, index);
  }

  private blockSubtitle(block: string): string {
    if (block === 'toplists') {
      return `${discoverStore.toplists.length} 个榜单 · ${discoverStore.sourceLabel}`;
    }
    if (block === 'newSongs') {
      return `${discoverStore.newSongs.length} 首`;
    }
    if (block === 'newAlbums') {
      return `${discoverStore.newAlbums.length} 张`;
    }
    return `${discoverStore.recommend.length} 个`;
  }

  private blockState(block: string): string {
    if (block === 'toplists') {
      return discoverStore.topState;
    }
    if (block === 'newSongs') {
      return discoverStore.newSongsState;
    }
    if (block === 'newAlbums') {
      return discoverStore.newAlbumsState;
    }
    return discoverStore.recommendState;
  }

  private blockError(block: string): string {
    if (block === 'toplists') {
      return discoverStore.topError;
    }
    if (block === 'newSongs') {
      return discoverStore.newSongsError;
    }
    if (block === 'newAlbums') {
      return discoverStore.newAlbumsError;
    }
    return discoverStore.recommendError;
  }

  @Builder
  blockHeader(block: string, title: string, actionText: string, action: () => void) {
    Row() {
      Column({ space: 2 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(this.blockState(block) === 'error' && this.blockError(block).length > 0
          ? this.blockError(block) : this.blockSubtitle(block))
          .fontSize(10.5)
          .fontColor(this.blockState(block) === 'error' ? '#FFB44C' : themeStore.palette.sub)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.blockState(block) === 'error') {
        Text('重试')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor('#22FFFFFF')
          .onClick(() => {
            action();
          })
      } else if (actionText.length > 0) {
        Text(actionText)
          .fontSize(11)
          .fontColor(themeStore.palette.brand)
          .onClick(() => {
            action();
          })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  topCard(item: DiscoverToplistItem) {
    Column({ space: 5 }) {
      Artwork({
        seed: item.seed,
        artworkSize: 96,
        radius: 14,
        title: item.name,
        showRing: true,
        showInitial: false,
        remoteUrl: item.coverUrl
      })
      Text(item.name)
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(96)
    }
    .width(96)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openToplist(item);
    })
  }

  @Builder
  albumCard(album: Album) {
    Column({ space: 5 }) {
      Artwork({
        seed: album.coverSeed,
        artworkSize: 96,
        radius: 14,
        title: album.title,
        showRing: false,
        showInitial: false,
        remoteUrl: album.coverUrl
      })
      Text(album.title)
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(96)
      Text(album.artist)
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(96)
    }
    .width(96)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openAlbum(album);
    })
  }

  @Builder
  playlistCard(playlist: Playlist) {
    Column({ space: 5 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 128,
        radius: 16,
        title: playlist.name,
        showRing: false,
        showInitial: false,
        remoteUrl: playlist.coverUrl
      })
      Text(playlist.name)
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(128)
      Text(`${playlistCardCount(playlist)} 首`)
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
    }
    .width(128)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openPlaylist(playlist);
    })
  }

  @Builder
  notConnected() {
    EmptyState({
      title: '尚未连接柠檬音乐服务器',
      description: '在设置中填写服务器地址并登录后，即可查看榜单与推荐',
      actionText: '去设置',
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      accent: themeStore.palette.brand,
      onAction: () => {
        overlayStore.setTab(3);
      }
    })
  }

  @Builder
  toplistsBlock() {
    Column({ space: 10 }) {
      this.blockHeader('toplists', '权威排行榜', '', () => {
        discoverStore.retryBlock('toplists');
      })

      if (discoverStore.topState === 'loading' && discoverStore.toplists.length === 0) {
        EmptyState({ loading: true, title: '正在加载榜单' })
      } else if (discoverStore.toplists.length > 0) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(discoverStore.toplists, (item: DiscoverToplistItem) => {
              this.topCard(item)
            }, (item: DiscoverToplistItem) => `${item.source}_${item.id}`)
          }
          .padding({ right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      } else if (discoverStore.topState === 'error') {
        Text('榜单不可用，稍后重试')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  newSongsBlock() {
    Column({ space: 8 }) {
      this.blockHeader('newSongs', '新歌首发', '', () => {
        discoverStore.retryBlock('newSongs');
      })

      if (discoverStore.newSongsState === 'loading' && discoverStore.newSongs.length === 0) {
        EmptyState({ loading: true, title: '正在加载新歌' })
      } else if (discoverStore.newSongs.length > 0) {
        Column() {
          ForEach(discoverStore.newSongs.slice(0, 6), (song: Song, index: number) => {
            Row({ space: 10 }) {
              Text(`${index + 1}`)
                .fontSize(11)
                .fontColor(themeStore.palette.sub)
                .width(16)
              Column({ space: 2 }) {
                Text(song.title)
                  .fontSize(13)
                  .fontColor(themeStore.palette.text)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(`${song.artist}${song.album.length > 0 ? ' · ' + song.album : ''}`)
                  .fontSize(10)
                  .fontColor(themeStore.palette.sub)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              BadgeView({ text: ServerEndpoints.platformLabel(song.platform), tone: 'glass' })
              Text(Formatters.duration(song.durationMs))
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
            }
            .width('100%')
            .padding({ top: 7, bottom: 7 })
            .onClick(() => {
              this.playSong(song, discoverStore.newSongs, index);
            })
          }, (song: Song) => song.id)
        }
        .width('100%')
        .padding({ left: 10, right: 10 })
        .borderRadius(16)
        .backgroundColor(themeStore.palette.card)
      } else if (discoverStore.newSongsState === 'error') {
        Text('新歌暂不可用')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  newAlbumsBlock() {
    Column({ space: 10 }) {
      this.blockHeader('newAlbums', '新碟首发', '', () => {
        discoverStore.retryBlock('newAlbums');
      })

      if (discoverStore.newAlbumsState === 'loading' && discoverStore.newAlbums.length === 0) {
        EmptyState({ loading: true, title: '正在加载新碟' })
      } else if (discoverStore.newAlbums.length > 0) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(discoverStore.newAlbums, (album: Album) => {
              this.albumCard(album)
            }, (album: Album) => `${album.platform}_${album.id}`)
          }
          .padding({ right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      } else if (discoverStore.newAlbumsState === 'error') {
        Text('新碟暂不可用')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  recommendBlock() {
    Column({ space: 10 }) {
      this.blockHeader('recommend', '热门推荐歌单', '', () => {
        discoverStore.retryBlock('recommend');
      })

      if (discoverStore.recommendState === 'loading' && discoverStore.recommend.length === 0) {
        EmptyState({ loading: true, title: '正在加载推荐歌单' })
      } else if (discoverStore.recommend.length > 0) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(discoverStore.recommend, (playlist: Playlist) => {
              this.playlistCard(playlist)
            }, (playlist: Playlist) => `${playlist.platform}_${playlist.id}`)
          }
          .padding({ right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      } else if (discoverStore.recommendState === 'error') {
        Text('推荐歌单暂不可用')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Refresh({ refreshing: this.refreshing }) {
      Scroll(this.scroller) {
        Column({ space: 16 }) {
          if (!serverStore.canRead) {
            this.notConnected()
          } else {
            ServerStatusCard({ preferOnlineLabel: true })

            this.toplistsBlock()
            this.newAlbumsBlock()
            this.newSongsBlock()
            this.recommendBlock()


            Text(`最后更新于 ${Formatters.relativeDate(discoverStore.lastLoadedAt)} · 数据来自你的音乐服务器`)
              .fontSize(9.5)
              .fontColor(themeStore.palette.sub)
              .width('100%')
              .padding({ top: 8, bottom: 24 })
          }
        }
        .width('100%')
        .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8, bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed) })
        .constraintSize({ maxWidth: AppConstants.MAX_CONTENT_WIDTH })
        .alignItems(HorizontalAlign.Start)
        .animation({ duration: 220, curve: Curve.EaseOut })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
      .onDidScroll((delta: number, state: ScrollState) => {
        scrollChrome.report(this.scroller.currentOffset().yOffset, delta);
      })
    }
    .onRefreshing(() => {
      this.onRefresh();
    })
    .width('100%')
    .height('100%')
  }
}


