/**
 * 资料库（设计图版）：顶部标题 + 彩色渐变卡片网格 + 自建与云端歌单
 * + 最近添加 + 本地文件夹 + 全部歌曲列表。
 * 所有数量与列表均来自 libraryStore / localScanStore / podcastStore（真实数据）。
 */
import { AppConstants, DockMetrics } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { LibraryNameDialog } from '../components/LibraryAuxPanels';
import { HomeMode } from '../model/LocalScanModels';
import { Album, Playlist, Song } from '../model/MediaModels';
import { LibraryDetailParam, LibraryKind } from '../model/UiModels';
import { Formatters } from '../service/Formatters';
import { ImportResult, ImportService } from '../service/ImportService';
import { playVisualSong } from '../service/PlaybackLauncher';
import { WriteOutcome } from '../viewmodel/LibraryModels';
import { layoutStore } from '../viewmodel/LayoutStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { localScanStore } from '../viewmodel/LocalScanStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { serverStore } from '../viewmodel/ServerStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';

const SCOPE: string = 'LibraryView';

@ComponentV2
export struct LibraryView {
  @Param onOpenDetail: (param: LibraryDetailParam) => void = () => {
  };
  @Local listLimit: number = 20;
  @Local sortMode: number = 0; // 0=加入时间 1=歌名 2=歌手
  @Local selectionMode: boolean = false;
  @Local selectedIds: string[] = [];
  @Local showNameDialog: boolean = false;
  @Local nameInput: string = '';
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    podcastStore.loadFeeds();
  }

  // ---------------- 数据 ----------------

  /** 本地曲目数 = 导入 + 文件夹扫描。 */
  private localCount(): number {
    return libraryStore.localSongs.length + libraryStore.scannedSongs.length;
  }

  /** 全部歌曲：按当前排序方式返回。 */
  private sortedSongs(): Song[] {
    const list: Song[] = libraryStore.allSongs.slice();
    if (this.sortMode === 1) {
      list.sort((a: Song, b: Song) => a.title < b.title ? -1 : 1);
    } else if (this.sortMode === 2) {
      list.sort((a: Song, b: Song) => a.artist < b.artist ? -1 : 1);
    } else {
      list.sort((a: Song, b: Song) => b.addedAt - a.addedAt);
    }
    return list;
  }

  private sortLabel(): string {
    if (this.sortMode === 1) {
      return '按歌名';
    }
    if (this.sortMode === 2) {
      return '按歌手';
    }
    return '按加入时间';
  }

  private serverName(): string {
    if (!serverStore.canRead) {
      return '未连接';
    }
    const name: string = serverStore.activeServer !== null ? serverStore.activeServer.name : '';
    return name.length > 0 ? name : '服务器';
  }

  /** 最近添加：按加入时间排序的前若干专辑。 */
  private recentAlbums(): Album[] {
    const result: Album[] = [];
    const albums: Album[] = libraryStore.albums;
    for (let i = 0; i < albums.length && i < 6; i++) {
      result.push(albums[i]);
    }
    return result;
  }

  // ---------------- 交互 ----------------

  private async onImport(): Promise<void> {
    if (libraryStore.importing) {
      return;
    }
    libraryStore.importing = true;
    let settled: boolean = false;
    setTimeout(() => {
      if (!settled) {
        libraryStore.importing = false;
        ConfirmDialog.toast(this.getUIContext(), '无法打开文件选择器，请重试');
      }
    }, 45000);
    try {
      const result: ImportResult = await ImportService.pickAndImport();
      settled = true;
      if (result.cancelled) {
        return;
      }
      libraryStore.addImportedSongs(result.songs, result.skipped, result.message);
      ConfirmDialog.toast(this.getUIContext(), result.message);
    } catch (error) {
      settled = true;
      Logger.error(SCOPE, 'import failed');
      ConfirmDialog.toast(this.getUIContext(), '导入失败，请重试');
    } finally {
      libraryStore.importing = false;
    }
  }

  private async sync(): Promise<void> {
    const ok: boolean = await syncStore.syncNow(true);
    ConfirmDialog.toast(this.getUIContext(), ok ? '同步完成' : (syncStore.error.length > 0 ? syncStore.error : '同步失败'));
  }

  private switchToLocal(): void {
    localScanStore.setMode(HomeMode.LOCAL);
    overlayStore.setTab(0);
    ConfirmDialog.toast(this.getUIContext(), '已切换到本地曲库');
  }

  private openDetail(kind: LibraryKind, title: string, id: string = ''): void {
    this.onOpenDetail(LibraryDetailParam.create(kind, title, id));
  }

  private playAlbum(album: Album): void {
    const list: Song[] = [];
    for (let i = 0; i < libraryStore.allSongs.length; i++) {
      const song: Song = libraryStore.allSongs[i];
      if (album.songIds.indexOf(song.id) >= 0) {
        list.push(song);
      }
    }
    if (list.length > 0) {
      playVisualSong(list, 0);
    } else {
      ConfirmDialog.toast(this.getUIContext(), '该专辑暂无可播放歌曲');
    }
  }

  private showSongActions(song: Song): void {
    const actions: string[] = ['立即播放', '加入队列', song.isFavorite ? '取消喜欢' : '喜欢', '加入歌单', '查看歌曲信息'];
    ConfirmDialog.actionSheet(this.getUIContext(), song.title, actions).then((index: number) => {
      if (index === 0) {
        playVisualSong([song], 0);
      } else if (index === 1) {
        overlayStore.openAddToPlaylist([song.id]);
      } else if (index === 2) {
        libraryStore.toggleFavorite(song.id).then((outcome) => {
          ConfirmDialog.toast(this.getUIContext(), outcome.message);
        });
      } else if (index === 3) {
        overlayStore.openAddToPlaylist([song.id]);
      } else if (index === 4) {
        ConfirmDialog.toast(this.getUIContext(),
          `${song.format} · ${Formatters.bytes(song.sizeBytes)} · ${song.filePath.length > 0 ? song.filePath : '本地文件'}`);
      }
    });
  }

  private async confirmCreatePlaylist(): Promise<void> {
    const name: string = this.nameInput.trim();
    if (name.length === 0) {
      ConfirmDialog.toast(this.getUIContext(), '请输入歌单名称');
      return;
    }
    const outcome: WriteOutcome = await libraryStore.createPlaylist(name);
    ConfirmDialog.toast(this.getUIContext(), outcome.message);
    if (outcome.ok) {
      this.showNameDialog = false;
      this.nameInput = '';
    }
  }

  // ---------------- 多选 ----------------

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

  private playSelected(): void {
    const chosen: Song[] = [];
    const all: Song[] = this.sortedSongs();
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

  // ---------------- 菜单 ----------------

  @Builder
  sortMenuBuilder() {
    Menu() {
      MenuItem() {
        Text('按加入时间').fontSize(14)
          .fontColor(this.sortMode === 0 ? '#FA2D48' : themeStore.palette.text)
      }.onClick(() => {
        this.sortMode = 0;
      })
      MenuItem() {
        Text('按歌名').fontSize(14)
          .fontColor(this.sortMode === 1 ? '#FA2D48' : themeStore.palette.text)
      }.onClick(() => {
        this.sortMode = 1;
      })
      MenuItem() {
        Text('按歌手').fontSize(14)
          .fontColor(this.sortMode === 2 ? '#FA2D48' : themeStore.palette.text)
      }.onClick(() => {
        this.sortMode = 2;
      })
    }
  }

  @Builder
  serverMenuBuilder() {
    Menu() {
      MenuItem() {
        Text(`当前服务器：${this.serverName()}`).fontSize(14).fontColor(themeStore.palette.text)
      }.onClick(() => {
        overlayStore.setTab(3);
      })
      MenuItem() {
        Text('切换到本地曲库').fontSize(14).fontColor(themeStore.palette.text)
      }.onClick(() => {
        this.switchToLocal();
      })
      MenuItem() {
        Text('服务器设置').fontSize(14).fontColor(themeStore.palette.text)
      }.onClick(() => {
        overlayStore.setTab(3);
      })
    }
  }

  // ---------------- 顶部 ----------------

  @Builder
  roundButton(icon: Resource, action: () => void) {
    Stack() {
      Image(icon).width(18).height(18).fillColor(themeStore.palette.text)
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
    .onClick(() => {
      action();
    })
  }

  @Builder
  header() {
    Column({ space: 4 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('资料库')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(themeStore.palette.text)
          Text(serverStore.canRead ? `已连接 · ${this.serverName()}` : '未连接服务器')
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.roundButton($r('app.media.ic_download'), () => {
          overlayStore.setTab(2);
        })

        Row({ space: 6 }) {
          Image($r('app.media.ic_server')).width(14).height(14).fillColor(themeStore.palette.text)
          Text(this.serverName())
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Image($r('app.media.ic_chevron_down')).width(11).height(11).fillColor(themeStore.palette.sub)
        }
        .height(38)
        .constraintSize({ maxWidth: 120 })
        .padding({ left: 11, right: 9 })
        .borderRadius(19)
        .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
        .bindMenu(this.serverMenuBuilder())
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ---------------- 卡片网格 ----------------

  @Builder
  tag(text: string) {
    Text(text)
      .fontSize(10)
      .fontColor('#FFFFFF')
      .fontWeight(FontWeight.Medium)
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(11)
      .backgroundColor('#33FFFFFF')
      .maxLines(1)
  }

  /** 蓝：nas 云盘音乐 */
  @Builder
  nasCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#3D6FE8', 0.0], ['#2A4FB0', 0.55], ['#1A2F78', 1.0]] })
      Column()
        .width(130)
        .height(130)
        .borderRadius(65)
        .backgroundColor('#24FFFFFF')
        .offset({ x: 76, y: -40 })

      Column({ space: 8 }) {
        Row() {
          this.tag('云盘音乐')
          Blank()
          Image($r('app.media.ic_cloud_sync')).width(15).height(15).fillColor('#FFFFFF')
        }
        .width('100%')

        Text(this.serverName())
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text(`${libraryStore.serverSongs.length} 首 · 已下载 ${this.localCount()} 首`)
          .fontSize(10.5)
          .fontColor('#D6E6FF')

        Blank()

        Row({ space: 8 }) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_refresh')).width(12).height(12).fillColor('#FFFFFF')
            Text(syncStore.busy ? '同步中' : '同步')
              .fontSize(11)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .borderRadius(12)
          .backgroundColor('#33FFFFFF')
          .onClick(() => {
            this.sync();
          })

          Text('切本地')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .borderRadius(12)
            .backgroundColor('#22FFFFFF')
            .onClick(() => {
              this.switchToLocal();
            })
        }
      }
      .width('100%')
      .height('100%')
      .padding(13)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
  }

  /** 专辑封面预览（albumCard 内复用，避免在 Builder 中声明局部变量）。 */
  @Builder
  albumPreview(album: Album) {
    Row({ space: 8 }) {
      Artwork({
        seed: album.coverSeed,
        artworkSize: 38,
        radius: 8,
        title: album.title,
        showInitial: false,
        showRing: false,
        remoteUrl: album.coverUrl
      })
      Column({ space: 2 }) {
        Text(album.title)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${album.artist} · ${album.count} 首`)
          .fontSize(10)
          .fontColor('#EADCFB')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  /** 紫：最新专辑 */
  @Builder
  albumCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#9B4FD8', 0.0], ['#6E2AA6', 0.55], ['#42166E', 1.0]] })
      Column()
        .width(130)
        .height(130)
        .borderRadius(65)
        .backgroundColor('#20FFFFFF')
        .offset({ x: 80, y: -44 })

      Column({ space: 7 }) {
        Row() {
          this.tag(`共 ${libraryStore.albums.length} 首`)
          Blank()
        }
        .width('100%')

        if (libraryStore.albums.length > 0) {
          this.albumPreview(libraryStore.albums[0])
        } else {
          Text('暂无专辑').fontSize(12).fontColor('#EADCFB')
        }

        Blank()

        Row() {
          Text('查看全部专辑').fontSize(11).fontColor('#F6F1FF')
          Blank()
          Text('›').fontSize(20).fontColor('#FFFFFF')
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .padding(13)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.openDetail(LibraryKind.ALBUM, '全部专辑');
    })
  }

  /** 玫红：我喜欢的音乐 */
  @Builder
  favoriteCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 130, colors: [['#E8519B', 0.0], ['#B32B72', 0.55], ['#7A1249', 1.0]] })
      Column()
        .width(140)
        .height(140)
        .borderRadius(70)
        .backgroundColor('#22FFFFFF')
        .offset({ x: 60, y: -48 })

      Column({ space: 8 }) {
        Image($r('app.media.ic_heart_fill')).width(22).height(22).fillColor('#FFFFFF')
        Blank()
        Text('我喜欢的音乐')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${libraryStore.favoriteSongs.length} 首收藏歌曲`)
          .fontSize(10.5)
          .fontColor('#FBDCEB')
        Row() {
          Text('同步来收藏').fontSize(11).fontColor('#FFFFFF')
          Blank()
          Text('›').fontSize(20).fontColor('#FFFFFF')
        }
        .width('100%')
        .onClick(() => {
          this.openDetail(LibraryKind.FAVORITES, '我喜欢的音乐');
        })
      }
      .width('100%')
      .height('100%')
      .padding(13)
    }
    .width('100%')
    .height('100%')
    .borderRadius(20)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.openDetail(LibraryKind.FAVORITES, '我喜欢的音乐');
    })
  }

  /** 琥珀：全部歌曲 */
  @Builder
  allSongsCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#E8A317', 0.0], ['#B9700C', 0.6], ['#7A4306', 1.0]] })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#20FFFFFF')
        .offset({ x: 96, y: -26 })
      Row({ space: 9 }) {
        Column() {
          Image($r('app.media.ic_more')).width(17).height(17).fillColor('#FFFFFF')
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 3 }) {
          Text('全部歌曲').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text(`${libraryStore.allSongs.length} 首所有曲目`)
            .fontSize(10)
            .fontColor('#FFF0D6')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('›').fontSize(21).fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.openDetail(LibraryKind.ALL, '全部歌曲');
    })
  }

  /** 青：已下载 */
  @Builder
  downloadedCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#1FAE93', 0.0], ['#138B78', 0.6], ['#0C5B51', 1.0]] })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#20FFFFFF')
        .offset({ x: 96, y: -26 })
      Row({ space: 9 }) {
        Column() {
          Image($r('app.media.ic_download')).width(17).height(17).fillColor('#FFFFFF')
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 3 }) {
          Text('已下载').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text(`${this.localCount()} 首本地歌曲`)
            .fontSize(10)
            .fontColor('#D2F2EA')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('›').fontSize(21).fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.openDetail(LibraryKind.DOWNLOADED, '已下载');
    })
  }

  /** 紫：播客播单 */
  @Builder
  podcastCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#7B4FD8', 0.0], ['#4B2AA6', 0.6], ['#2C166E', 1.0]] })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#1EFFFFFF')
        .offset({ x: 96, y: -26 })
      Row({ space: 9 }) {
        Column() {
          Image($r('app.media.ic_podcast')).width(17).height(17).fillColor('#FFFFFF')
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 3 }) {
          Text('播客播单').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text(`${podcastStore.feeds.length} 集播客内容`)
            .fontSize(10)
            .fontColor('#E6DBFB')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('›').fontSize(21).fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      overlayStore.openPodcast();
    })
  }

  /** 橙：歌手 */
  @Builder
  artistCard() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 125, colors: [['#F08A2E', 0.0], ['#C46312', 0.6], ['#8A4006', 1.0]] })
      Column()
        .width(96)
        .height(96)
        .borderRadius(48)
        .backgroundColor('#20FFFFFF')
        .offset({ x: 96, y: -26 })
      Row({ space: 9 }) {
        Column() {
          Text('♫').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor('#33FFFFFF')
        .justifyContent(FlexAlign.Center)

        Column({ space: 3 }) {
          Text('歌手').fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text(`${libraryStore.artists.length} 位音乐人`)
            .fontSize(10)
            .fontColor('#FFEACD')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('›').fontSize(21).fontColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .borderRadius(16)
    .clip(true)
    .border({ width: 1, color: '#38FFFFFF' })
    .onClick(() => {
      this.openDetail(LibraryKind.ARTIST, '全部歌手');
    })
  }

  @Builder
  cardGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        Column() { this.nasCard() }.layoutWeight(1).height('100%')
        Column() { this.albumCard() }.layoutWeight(1).height('100%')
      }
      .width('100%')
      .height(146)

      Row({ space: 10 }) {
        Column() { this.favoriteCard() }.layoutWeight(1).height('100%')
        Column({ space: 10 }) {
          Column() { this.allSongsCard() }.layoutWeight(1).width('100%')
          Column() { this.downloadedCard() }.layoutWeight(1).width('100%')
        }
        .layoutWeight(1)
        .height('100%')
      }
      .width('100%')
      .height(146)

      Row({ space: 10 }) {
        Column() { this.podcastCard() }.layoutWeight(1).height('100%')
        Column() { this.artistCard() }.layoutWeight(1).height('100%')
      }
      .width('100%')
      .height(62)
    }
    .width('100%')
  }

  // ---------------- 分区标题 ----------------

  @Builder
  sectionTitle(title: string, countText: string, onMore: () => void, showRefresh: boolean = false) {
    Row({ space: 6 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(themeStore.palette.text)
      Blank()
      if (showRefresh) {
        Image($r('app.media.ic_refresh'))
          .width(14)
          .height(14)
          .fillColor('#FA2D48')
          .onClick(() => {
            this.sync();
          })
      }
      Text(countText)
        .fontSize(11)
        .fontColor('#FA2D48')
        .onClick(() => {
          onMore();
        })
    }
    .width('100%')
  }

  // ---------------- 自建与云端歌单 ----------------

  @Builder
  playlistItem(playlist: Playlist) {
    Column({ space: 6 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 92,
        radius: 12,
        title: playlist.name,
        showInitial: false,
        showRing: false,
        remoteUrl: playlist.coverUrl
      })
      Text(playlist.name)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.text)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(92)
        .height(32)
      Text(`${playlist.entries.length} 首`)
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
        .width(92)
    }
    .width(92)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openDetail(LibraryKind.PLAYLIST, playlist.name, playlist.id);
    })
  }

  @Builder
  newPlaylistCard() {
    Column({ space: 8 }) {
      Stack() {
        Column()
          .width(92)
          .height(92)
          .borderRadius(12)
          .border({ width: 1.5, color: '#FA2D48', style: BorderStyle.Dashed })
          .backgroundColor('#12FA2D48')
        Column() {
          Image($r('app.media.ic_plus')).width(24).height(24).fillColor('#FA2D48')
        }
        .width(92)
        .height(92)
        .justifyContent(FlexAlign.Center)
      }
      .width(92)
      .height(92)

      Text('新建歌单')
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FA2D48')
        .width(92)
        .textAlign(TextAlign.Center)
      Text('创建专属歌单')
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
        .width(92)
        .textAlign(TextAlign.Center)
    }
    .width(92)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.nameInput = '';
      this.showNameDialog = true;
    })
  }

  @Builder
  playlistsBlock() {
    Column({ space: 10 }) {
      this.sectionTitle('自建与云端歌单', `全部 ${libraryStore.playlists.length} 个`, () => {
        this.openDetail(LibraryKind.PLAYLIST, '歌单管理');
      }, true)

      Scroll() {
        Row({ space: 12 }) {
          ForEach(libraryStore.playlists, (playlist: Playlist) => {
            this.playlistItem(playlist)
          }, (playlist: Playlist) => playlist.id)
          this.newPlaylistCard()
        }
        .padding({ right: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ---------------- 最近添加 ----------------

  @Builder
  recentAlbumCard(album: Album) {
    Column({ space: 5 }) {
      Stack({ alignContent: Alignment.BottomEnd }) {
        Artwork({
          seed: album.coverSeed,
          artworkSize: 100,
          radius: 10,
          title: album.title,
          showInitial: false,
          showRing: false,
          remoteUrl: album.coverUrl
        })
        Stack() {
          Image($r('app.media.ic_play')).width(15).height(15).fillColor('#FFFFFF')
        }
        .width(27)
        .height(27)
        .borderRadius(14)
        .backgroundColor('#FA2D48')
        .margin({ right: 6, bottom: 6 })
        .onClick(() => {
          this.playAlbum(album);
        })
      }
      .width(100)
      .height(100)

      Text(album.title)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(100)
      Text(album.artist)
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(100)
    }
    .width(100)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      this.openDetail(LibraryKind.ALBUM, album.title, album.id);
    })
  }

  @Builder
  recentBlock() {
    Column({ space: 10 }) {
      this.sectionTitle('最近添加', `全部 ${libraryStore.allSongs.length} 首`, () => {
        this.openDetail(LibraryKind.ALL, '最近添加');
      })
      if (this.recentAlbums().length > 0) {
        Scroll() {
          Row({ space: 12 }) {
            ForEach(this.recentAlbums(), (album: Album) => {
              this.recentAlbumCard(album)
            }, (album: Album) => album.id)
          }
          .padding({ right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
      } else {
        Text('暂无专辑，连接服务器后自动同步')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ---------------- 本地文件夹 ----------------

  @Builder
  folderBlock() {
    Column({ space: 10 }) {
      this.sectionTitle('本地文件夹', `全部 ${localScanStore.folders.length} 个`, () => {
        this.openDetail(LibraryKind.FOLDER, '本地文件夹');
      })
      if (localScanStore.folders.length > 0) {
        Row({ space: 10 }) {
          Stack() {
            Image($r('app.media.ic_server')).width(22).height(22).fillColor('#FFFFFF')
          }
          .width(44)
          .height(44)
          .borderRadius(12)
          .linearGradient({ angle: 130, colors: [['#FFA53D', 0.0], ['#E8790F', 1.0]] })

          Column({ space: 2 }) {
            Text(localScanStore.folders[0].displayName.length > 0 ? localScanStore.folders[0].displayName : '本地文件夹')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(themeStore.palette.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`${localScanStore.folders[0].fileCount} 个文件`)
              .fontSize(10)
              .fontColor(themeStore.palette.sub)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('›').fontSize(20).fontColor(themeStore.palette.sub)
        }
        .width('100%')
        .padding(12)
        .borderRadius(14)
        .backgroundColor(themeStore.palette.card)
        .onClick(() => {
          this.openDetail(LibraryKind.FOLDER, localScanStore.folders[0].displayName);
        })
      } else {
        Row({ space: 10 }) {
          Stack() {
            Image($r('app.media.ic_plus')).width(20).height(20).fillColor('#FFFFFF')
          }
          .width(44)
          .height(44)
          .borderRadius(12)
          .linearGradient({ angle: 130, colors: [['#FFA53D', 0.0], ['#E8790F', 1.0]] })
          Text('导入本地音乐 / 添加文件夹')
            .fontSize(12)
            .fontColor(themeStore.palette.text)
          Blank()
        }
        .width('100%')
        .padding(12)
        .borderRadius(14)
        .backgroundColor(themeStore.palette.card)
        .onClick(() => {
          this.onImport();
        })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  // ---------------- 全部歌曲 ----------------

  @Builder
  songListItem(song: Song, index: number) {
    Row({ space: 10 }) {
      if (this.selectionMode) {
        Stack() {
          Column()
            .width(20)
            .height(20)
            .borderRadius(10)
            .border({ width: 1.5, color: this.isSelected(song) ? '#FA2D48' : '#66FFFFFF' })
            .backgroundColor(this.isSelected(song) ? '#FA2D48' : Color.Transparent)
          if (this.isSelected(song)) {
            Image($r('app.media.ic_check')).width(12).height(12).fillColor('#FFFFFF')
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
        artworkSize: 44,
        radius: 8,
        title: song.title,
        showInitial: false,
        showRing: false,
        remoteUrl: song.coverUrl
      })

      Column({ space: 3 }) {
        Text(song.title)
          .fontSize(12.5)
          .fontColor('#FA2D48')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`${Formatters.qualityBadge(song.format, song.bitRate)}${song.artist.length > 0 ? ' · ' + song.artist : ''}${song.album.length > 0 ? ' · ' + song.album : ''}`)
          .fontSize(9.5)
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      if (!this.selectionMode) {
        Image($r('app.media.ic_cloud_sync'))
          .width(17)
          .height(17)
          .fillColor('#4A90E2')
      }
    }
    .width('100%')
    .padding({ top: 7, bottom: 7, left: 8, right: 8 })
    .onClick(() => {
      if (this.selectionMode) {
        this.toggleSelection(song);
      } else {
        const all: Song[] = this.sortedSongs();
        const at: number = all.indexOf(song);
        playVisualSong(all, at < 0 ? 0 : at);
      }
    })
  }

  @Builder
  songsBlock() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Text('全部歌曲')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(`${libraryStore.allSongs.length}首`)
          .fontSize(12)
          .fontColor(themeStore.palette.sub)
        Blank()
        Row({ space: 3 }) {
          Text(this.sortLabel())
            .fontSize(11)
            .fontColor('#FA2D48')
          Image($r('app.media.ic_chevron_down'))
            .width(11)
            .height(11)
            .fillColor('#FA2D48')
        }
        .bindMenu(this.sortMenuBuilder())
      }
      .width('100%')

      if (this.selectionMode) {
        Row({ space: 10 }) {
          Text(`已选 ${this.selectedIds.length} 首`).fontSize(12).fontColor(themeStore.palette.text)
          Blank()
          Text('全选')
            .fontSize(11)
            .fontColor(themeStore.palette.text)
            .onClick(() => {
              this.selectedIds = this.sortedSongs().map((s: Song) => s.id);
            })
          Text('加入歌单')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor('#FA2D48')
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
            Image($r('app.media.ic_play')).width(14).height(14).fillColor('#FFFFFF')
            Text(`播放全部 (${libraryStore.allSongs.length})`)
              .fontSize(12)
              .fontColor('#FFFFFF')
          }
          .padding({ left: 16, right: 16, top: 9, bottom: 9 })
          .borderRadius(18)
          .backgroundColor('#FA2D48')
          .onClick(() => {
            if (libraryStore.allSongs.length > 0) {
              playVisualSong(this.sortedSongs(), 0);
            }
          })

          Row({ space: 5 }) {
            Image($r('app.media.ic_check')).width(13).height(13).fillColor(themeStore.palette.text)
            Text('多选').fontSize(12).fontColor(themeStore.palette.text)
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

      if (libraryStore.allSongs.length > 0) {
        Column() {
          ForEach(this.sortedSongs().slice(0, this.listLimit), (song: Song, index: number) => {
            this.songListItem(song, index)
          }, (song: Song) => song.id)
        }
        .width('100%')
        .borderRadius(14)
        .backgroundColor(themeStore.palette.card)

        if (libraryStore.allSongs.length > this.listLimit) {
          Text('展开更多')
            .fontSize(11.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 4 })
            .onClick(() => {
              this.listLimit = Math.min(this.listLimit + 20, libraryStore.allSongs.length);
            })
        }
      } else {
        Text('曲库还是空的，连接服务器或导入本地音乐后即可显示')
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 20, bottom: 20 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Stack() {
      Scroll(this.scroller) {
        Column({ space: 18 }) {
          this.header()
          this.cardGrid()
          this.playlistsBlock()
          this.recentBlock()
          this.folderBlock()
          this.songsBlock()

          Row() {
            Text(`共 ${libraryStore.serverSongs.length} 首服务器曲目与 ${this.localCount()} 首本地音乐`)
              .fontSize(9.5)
              .fontColor(themeStore.palette.sub)
          }
          .padding({ top: 4, bottom: 10 })
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({
          left: layoutStore.gutter,
          right: layoutStore.gutter,
          top: 8,
          bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed)
        })
        .constraintSize({ maxWidth: AppConstants.MAX_CONTENT_WIDTH })
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
      .onDidScroll((delta: number, state: ScrollState) => {
        scrollChrome.report(this.scroller.currentOffset().yOffset, delta);
      })

      if (this.showNameDialog) {
        Column() {
          LibraryNameDialog({
            dialogTitle: '新建歌单',
            nameValue: this.nameInput,
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: '#FA2D48',
            cardColor: themeStore.palette.card,
            blurStyle: themeStore.blurStyle,
            onNameChange: (value: string) => {
              this.nameInput = value;
            },
            onCancel: () => {
              this.showNameDialog = false;
            },
            onConfirm: () => {
              this.confirmCreatePlaylist();
            }
          })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
