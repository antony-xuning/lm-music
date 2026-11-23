/**
 * 发现页（彩色网格版）：首页服务器模式下的内容区。
 * 五张渐变卡片：每日推荐 / 最新专辑 / 权威排行榜 / 播客 / 换一批。
 * 全部列表数据来自 discoverStore、podcastStore（真实服务器接口）。
 */
import { AppConstants, DockMetrics } from '../common/Constants';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { Artwork } from '../components/Artwork';
import { EmptyState } from '../components/EmptyState';
import { playVisualSong } from '../service/PlaybackLauncher';
import { playlistCardCount } from '../service/DiscoverService';
import { Formatters } from '../service/Formatters';
import { Album, Playlist, Song } from '../model/MediaModels';
import { DiscoverCollectionKind, DiscoverCollectionParam, DiscoverToplistItem } from '../model/UiModels';
import { DiscoverStore, discoverStore } from '../viewmodel/DiscoverStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { serverStore } from '../viewmodel/ServerStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct DiscoverGridHome {
  @Param onOpenCollection: (param: DiscoverCollectionParam) => void = () => {
  };
  @Local refreshing: boolean = false;
  @Local batch: number = 0;
  @Local selectionMode: boolean = false;
  @Local selectedIds: string[] = [];
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
    discoverStore.reloadIfStale();
    podcastStore.loadFeeds();
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
    podcastStore.loadFeeds();
    this.refreshing = false;
  }

  /** 每日推荐：从服务器返回的新歌里按批次取 3 首。 */
  private dailySongs(): Song[] {
    const all: Song[] = discoverStore.newSongs;
    const result: Song[] = [];
    if (all.length === 0) {
      return result;
    }
    const size: number = 3;
    const total: number = Math.max(1, Math.ceil(all.length / size));
    const page: number = ((this.batch % total) + total) % total;
    const start: number = page * size;
    for (let i = start; i < all.length && i < start + size; i++) {
      result.push(all[i]);
    }
    return result;
  }

  private latestAlbums(): Album[] {
    const all: Album[] = discoverStore.newAlbums;
    const result: Album[] = [];
    for (let i = 0; i < all.length && i < 3; i++) {
      result.push(all[i]);
    }
    return result;
  }

  private topToplists(): DiscoverToplistItem[] {
    const all: DiscoverToplistItem[] = discoverStore.toplists;
    const result: DiscoverToplistItem[] = [];
    for (let i = 0; i < all.length && i < 2; i++) {
      result.push(all[i]);
    }
    return result;
  }

  private openAlbum(album: Album): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.ALBUM,
      album.remoteId.length > 0 ? album.remoteId : album.id, album.platform, album.title));
  }

  private openToplist(item: DiscoverToplistItem): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.TOPLIST,
      item.id, item.source, item.name));
  }

  private playSong(song: Song): void {
    const list: Song[] = discoverStore.newSongs;
    const index: number = list.indexOf(song);
    playVisualSong(list, index < 0 ? 0 : index);
  }

  private nextBatch(): void {
    this.batch = this.batch + 1;
  }

  private openPlaylist(playlist: Playlist): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.PLAYLIST,
      playlist.id, playlist.platform, playlist.name));
  }

  /** 音源文案：热门推荐歌单的副标题。 */
  private playlistSubtitle(): string {
    return `来自 ${discoverStore.sourceLabel} 亿万乐友精选`;
  }

  private toggleSelection(song: Song): void {
    const index: number = this.selectedIds.indexOf(song.id);
    if (index >= 0) {
      this.selectedIds.splice(index, 1);
    } else {
      this.selectedIds.push(song.id);
    }
  }

  private isSelected(song: Song): boolean {
    return this.selectedIds.indexOf(song.id) >= 0;
  }

  private exitSelection(): void {
    this.selectionMode = false;
    this.selectedIds = [];
  }

  /** 播放选中的新歌（按原列表顺序）。 */
  private playSelected(): void {
    const all: Song[] = discoverStore.newSongs;
    const chosen: Song[] = [];
    for (let i = 0; i < all.length; i++) {
      if (this.selectedIds.indexOf(all[i].id) >= 0) {
        chosen.push(all[i]);
      }
    }
    if (chosen.length === 0) {
      return;
    }
    playVisualSong(chosen, 0);
    this.exitSelection();
  }

  private addSelectedToPlaylist(): void {
    if (this.selectedIds.length === 0) {
      return;
    }
    overlayStore.openAddToPlaylist(this.selectedIds.slice());
    this.exitSelection();
  }

  // ---------------- 卡片内容片段 ----------------

  @Builder
  tag(text: string, color: string) {
    Text(text)
      .fontSize(10)
      .fontColor(color)
      .fontWeight(FontWeight.Medium)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(11)
      .backgroundColor('#33FFFFFF')
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  songRow(song: Song) {
    Row({ space: 9 }) {
      Artwork({
        seed: song.coverSeed,
        artworkSize: 42,
        radius: 8,
        title: song.title,
        showInitial: false,
        showRing: false,
        remoteUrl: song.coverUrl
      })
      Column({ space: 2 }) {
        Text(song.title)
          .fontSize(12.5)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(song.artist)
          .fontSize(10)
          .fontColor('#E0D9F5')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Image($r('app.media.ic_play'))
        .width(16)
        .height(16)
        .fillColor('#FFFFFF')
    }
    .width('100%')
    .height(46)
    .onClick(() => {
      this.playSong(song);
    })
  }

  @Builder
  albumRow(album: Album) {
    Row({ space: 9 }) {
      Artwork({
        seed: album.coverSeed,
        artworkSize: 42,
        radius: 8,
        title: album.title,
        showInitial: false,
        showRing: false,
        remoteUrl: album.coverUrl
      })
      Column({ space: 2 }) {
        Text(album.title)
          .fontSize(12.5)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${album.artist} · ${album.count} 首`)
          .fontSize(10)
          .fontColor('#F2DFC2')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(22)
        .fontColor('#FFE9C9')
    }
    .width('100%')
    .height(46)
    .onClick(() => {
      this.openAlbum(album);
    })
  }

  @Builder
  rankRow(item: DiscoverToplistItem) {
    Row({ space: 9 }) {
      Artwork({
        seed: item.seed,
        artworkSize: 34,
        radius: 7,
        title: item.name,
        showInitial: false,
        showRing: false,
        remoteUrl: item.coverUrl
      })
      Column({ space: 2 }) {
        Text(item.name)
          .fontSize(12.5)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text('刚刚更新')
          .fontSize(10)
          .fontColor('#CFEAE8')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Text('›')
        .fontSize(22)
        .fontColor('#D6F3F0')
    }
    .width('100%')
    .height(42)
    .onClick(() => {
      this.openToplist(item);
    })
  }

  // ---------------- 五张卡片 ----------------

  /** 每日推荐（紫） */
  @Builder
  dailyCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#7B4FD8', 0.0], ['#4B2AA6', 0.55], ['#2C166E', 1.0]] })
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#26FFFFFF')
        .offset({ x: 92, y: -46 })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#18FFFFFF')
        .offset({ x: 46, y: 112 })

      Column({ space: 7 }) {
        Row({ space: 6 }) {
          Text('✦')
            .fontSize(18)
            .fontColor('#FFFFFF')
          Text('每日推荐')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Blank()
          this.tag('半曲半探索', '#F6F1FF')
        }
        .width('100%')

        ForEach(this.dailySongs(), (song: Song) => {
          this.songRow(song)
        }, (song: Song) => song.id + song.title)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
  }

  /** 最新专辑（琥珀） */
  @Builder
  albumCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#E8A317', 0.0], ['#B9700C', 0.55], ['#7A4306', 1.0]] })
      Column()
        .width(150)
        .height(150)
        .borderRadius(75)
        .backgroundColor('#24FFFFFF')
        .offset({ x: 92, y: -46 })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#14FFFFFF')
        .offset({ x: 46, y: 112 })

      Column({ space: 7 }) {
        Row({ space: 6 }) {
          Text('◎')
            .fontSize(19)
            .fontColor('#FFFFFF')
          Text('最新专辑')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Blank()
          this.tag('新碟首发', '#FFF4E2')
        }
        .width('100%')

        ForEach(this.latestAlbums(), (album: Album) => {
          this.albumRow(album)
        }, (album: Album) => album.id + album.title)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
  }

  /** 权威排行榜（青） */
  @Builder
  rankCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#1E9C93', 0.0], ['#147D7A', 0.55], ['#0D4E54', 1.0]] })
      Column()
        .width(140)
        .height(140)
        .borderRadius(70)
        .backgroundColor('#20FFFFFF')
        .offset({ x: 88, y: -40 })

      Column({ space: 10 }) {
        Row({ space: 6 }) {
          Text('▥')
            .fontSize(18)
            .fontColor('#FFFFFF')
          Text('权威排行榜')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Blank()
          this.tag(`${discoverStore.toplists.length} 个榜单`, '#E6FAF8')
        }
        .width('100%')

        ForEach(this.topToplists(), (item: DiscoverToplistItem) => {
          this.rankRow(item)
        }, (item: DiscoverToplistItem) => item.id + item.name)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
  }

  /** 播客（蓝） */
  @Builder
  podcastCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#2E6FD6', 0.0], ['#1C4A9E', 0.6], ['#132F6B', 1.0]] })
      Column()
        .width(120)
        .height(120)
        .borderRadius(60)
        .backgroundColor('#1EFFFFFF')
        .offset({ x: 84, y: -34 })

      Row({ space: 10 }) {
        Column() {
          Image($r('app.media.ic_podcast'))
            .width(18)
            .height(18)
            .fillColor('#FFFFFF')
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('播客')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            this.tag('发现', '#E8F1FF')
          }
          Text(podcastStore.feeds.length > 0
            ? `已订阅 ${podcastStore.feeds.length} 个节目`
            : '添加你的第一个节目')
            .fontSize(11)
            .fontColor('#D6E6FF')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Image($r('app.media.ic_plus'))
          .width(18)
          .height(18)
          .fillColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      overlayStore.openPodcast();
    })
  }

  /** 换一批（绿） */
  @Builder
  batchCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#1FAE93', 0.0], ['#138B78', 0.6], ['#0C5B51', 1.0]] })
      Column()
        .width(110)
        .height(110)
        .borderRadius(55)
        .backgroundColor('#1EFFFFFF')
        .offset({ x: 94, y: -30 })

      Row({ space: 10 }) {
        Column() {
          Image($r('app.media.ic_refresh'))
            .width(18)
            .height(18)
            .fillColor('#FFFFFF')
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text('换一批')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            this.tag(`${discoverStore.newSongs.length}/${discoverStore.newSongs.length}`, '#E4FBF5')
          }
          Text('每日推荐 · 实时曲库')
            .fontSize(11)
            .fontColor('#D2F2EA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        Text('✦')
          .fontSize(19)
          .fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.nextBatch();
    })
  }

  // ---------------- 列表区块 ----------------

  /** 热门推荐歌单卡片。 */
  @Builder
  playlistCard(playlist: Playlist) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.BottomStart }) {
        Artwork({
          seed: playlist.coverSeed,
          artworkSize: 124,
          radius: 14,
          title: playlist.name,
          showInitial: false,
          showRing: false,
          remoteUrl: playlist.coverUrl
        })
        Column()
          .width('100%')
          .height(44)
          .linearGradient({ angle: 180, colors: [['#00000000', 0.0], ['#99000000', 1.0]] })
      }
      .width(124)
      .height(124)
      .clip(true)

      Text(playlist.name)
        .fontSize(11.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.text)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(124)
        .height(34)
      Text(`${playlistCardCount(playlist)} 首`)
        .fontSize(10)
        .fontColor(themeStore.palette.sub)
        .width(124)
    }
    .width(124)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openPlaylist(playlist);
    })
  }

  /** 热门推荐歌单区块。 */
  @Builder
  recommendBlock() {
    Column({ space: 10 }) {
      Column({ space: 2 }) {
        Text('热门推荐歌单')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(this.playlistSubtitle())
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (discoverStore.recommendState === DiscoverStore.LOADING && discoverStore.recommend.length === 0) {
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
      } else if (discoverStore.recommendState === DiscoverStore.ERROR) {
        Text('推荐歌单暂不可用')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /** 新歌首发区块：播放全部 / 多选 / 歌曲行。 */
  @Builder
  newSongsBlock() {
    Column({ space: 10 }) {
      Column({ space: 2 }) {
        Text('新歌首发')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text('今日全网新单，即点即播')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      if (this.selectionMode) {
        Row({ space: 10 }) {
          Text(`已选 ${this.selectedIds.length} 首`)
            .fontSize(12)
            .fontColor(themeStore.palette.text)
          Blank()
          Text('全选')
            .fontSize(11)
            .fontColor(themeStore.palette.text)
            .onClick(() => {
              this.selectedIds = discoverStore.newSongs.map((s: Song) => s.id);
            })
          Text('加入歌单')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.addSelectedToPlaylist();
            })
          Text('播放选中')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor('#33FFFFFF')
            .onClick(() => {
              this.playSelected();
            })
          Text('取消')
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .onClick(() => {
              this.exitSelection();
            })
        }
        .width('100%')
      } else {
        Row({ space: 10 }) {
          Row({ space: 6 }) {
            Image($r('app.media.ic_play'))
              .width(14)
              .height(14)
              .fillColor('#FFFFFF')
            Text(`播放全部 (${discoverStore.newSongs.length})`)
              .fontSize(12)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 16, right: 16, top: 9, bottom: 9 })
          .borderRadius(18)
          .backgroundColor(themeStore.palette.brand)
          .onClick(() => {
            if (discoverStore.newSongs.length > 0) {
              playVisualSong(discoverStore.newSongs, 0);
            }
          })

          Row({ space: 5 }) {
            Image($r('app.media.ic_check'))
              .width(13)
              .height(13)
              .fillColor(themeStore.palette.text)
            Text('多选')
              .fontSize(12)
              .fontColor(themeStore.palette.text)
          }
          .padding({ left: 14, right: 14, top: 9, bottom: 9 })
          .borderRadius(18)
          .border({ width: 1, color: themeStore.palette.divider })
          .onClick(() => {
            this.selectionMode = true;
            this.selectedIds = [];
          })
        }
        .width('100%')
      }

      if (discoverStore.newSongsState === DiscoverStore.LOADING && discoverStore.newSongs.length === 0) {
        EmptyState({ loading: true, title: '正在加载新歌' })
      } else if (discoverStore.newSongs.length > 0) {
        Column() {
          ForEach(discoverStore.newSongs, (song: Song, index: number) => {
            Row({ space: 10 }) {
              if (this.selectionMode) {
                Stack() {
                  Column()
                    .width(20)
                    .height(20)
                    .borderRadius(10)
                    .border({ width: 1.5, color: this.isSelected(song) ? themeStore.palette.brand : '#66FFFFFF' })
                    .backgroundColor(this.isSelected(song) ? themeStore.palette.brand : Color.Transparent)
                  if (this.isSelected(song)) {
                    Image($r('app.media.ic_check'))
                      .width(12)
                      .height(12)
                      .fillColor('#FFFFFF')
                  }
                }
              } else {
                Text(`${index + 1}`)
                  .fontSize(11)
                  .fontColor(themeStore.palette.sub)
                  .width(18)
                  .textAlign(TextAlign.Center)
              }

              Artwork({
                seed: song.coverSeed,
                artworkSize: 46,
                radius: 8,
                title: song.title,
                showInitial: false,
                showRing: false,
                remoteUrl: song.coverUrl
              })

              Column({ space: 3 }) {
                Text(song.title)
                  .fontSize(12.5)
                  .fontColor(themeStore.palette.text)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
                Text(`${song.artist}${song.album.length > 0 ? ' · ' + song.album : ''}`)
                  .fontSize(10)
                  .fontColor(themeStore.palette.sub)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              if (!this.selectionMode) {
                Text(Formatters.duration(song.durationMs))
                  .fontSize(10)
                  .fontColor(themeStore.palette.sub)
                Image($r('app.media.ic_more'))
                  .width(16)
                  .height(16)
                  .fillColor(themeStore.palette.sub)
              }
            }
            .width('100%')
            .padding({ top: 8, bottom: 8, left: 10, right: 10 })
            .onClick(() => {
              if (this.selectionMode) {
                this.toggleSelection(song);
              } else {
                playVisualSong(discoverStore.newSongs, index);
              }
            })
          }, (song: Song) => song.id)
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(themeStore.palette.card)
      } else if (discoverStore.newSongsState === DiscoverStore.ERROR) {
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
  notConnected() {
    Column({ space: 10 }) {
      Text('发现更多好音乐')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(themeStore.palette.text)
      Text('连接柠檬音乐服务器后，即可查看推荐歌曲、新碟与排行榜')
        .fontSize(12)
        .fontColor(themeStore.palette.sub)
        .textAlign(TextAlign.Center)
      Text('去设置')
        .fontSize(12)
        .fontColor('#FFFFFF')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .borderRadius(16)
        .backgroundColor('#FA2D48')
        .onClick(() => {
          overlayStore.setTab(3);
        })
    }
    .width('100%')
    .padding({ top: 60 })
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Refresh({ refreshing: this.refreshing }) {
      Scroll(this.scroller) {
        Column({ space: 12 }) {
          if (!serverStore.canRead) {
            this.notConnected()
          } else {
            Row({ space: 12 }) {
              Column() {
                this.dailyCard()
              }
              .layoutWeight(1)
              .height('100%')

              Column() {
                this.albumCard()
              }
              .layoutWeight(1)
              .height('100%')
            }
            .width('100%')
            .height(208)

            Row({ space: 12 }) {
              Column() {
                this.rankCard()
              }
              .layoutWeight(1)
              .height('100%')

              Column({ space: 12 }) {
                Column() {
                  this.podcastCard()
                }
                .layoutWeight(1)
                .width('100%')

                Column() {
                  this.batchCard()
                }
                .layoutWeight(1)
                .width('100%')
              }
              .layoutWeight(1)
              .height('100%')
            }
            .width('100%')
            .height(158)

            this.recommendBlock()

            this.newSongsBlock()
          }
        }
        .width('100%')
        .padding({
          left: layoutStore.gutter,
          right: layoutStore.gutter,
          top: 4,
          bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed)
        })
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
