/**
 * 发现二级页：榜单曲目 / 新碟曲目 / 推荐歌单曲目（在线来源，可直接试听）。
 */
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SongRow } from '../components/SongRow';
import { Song } from '../model/MediaModels';
import { DiscoverCollectionKind, DiscoverCollectionParam } from '../model/UiModels';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { DiscoverService, SongPayload } from '../service/DiscoverService';
import { playSongsShuffled, playVisualSong, queueSong } from '../service/PlaybackLauncher';
import { DownloadOpResult } from '../service/ServerDownloadService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { downloadStore } from '../viewmodel/DownloadStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

@ComponentV2
export struct DiscoverCollectionPage {
  @Local param: DiscoverCollectionParam = new DiscoverCollectionParam();
  @Local songs: Song[] = [];
  @Local loading: boolean = true;
  @Local errorText: string = '';

  private async load(): Promise<void> {
    this.loading = true;
    this.errorText = '';
    let payload: SongPayload = new SongPayload();
    if (this.param.kind === DiscoverCollectionKind.TOPLIST) {
      payload = await DiscoverService.toplistSongs(this.param.source, this.param.id, 100);
    } else if (this.param.kind === DiscoverCollectionKind.ALBUM) {
      payload = await DiscoverService.albumSongs(this.param.source, this.param.id);
    } else {
      payload = await DiscoverService.playlistSongs(this.param.source, this.param.id);
    }
    this.songs = payload.items;
    this.errorText = payload.ok ? '' : (payload.error.length > 0 ? payload.error : '加载失败');
    this.loading = false;
  }

  private async addToPlaylist(song: Song): Promise<void> {
    let targetId: string = '';
    const playlists = libraryStore.userPlaylists;
    if (playlists.length > 0) {
      targetId = playlists[0].id;
    }
    if (targetId.length === 0) {
      const created = await libraryStore.createPlaylist('我的收藏歌单');
      if (!created.ok) {
        ConfirmDialog.toast(this.getUIContext(), created.message);
        return;
      }
      targetId = created.playlistId;
    }
    const outcome = await libraryStore.addToPlaylist(targetId, [song.id]);
    ConfirmDialog.toast(this.getUIContext(), outcome.message);
  }

  private showActions(song: Song): void {
    const actions: string[] = ['立即播放', '加入试听列表', '收藏', '加入歌单', '下载'];
    ConfirmDialog.actionSheet(this.getUIContext(), song.title, actions).then((index: number) => {
      if (index === 0) {
        playVisualSong([song], 0);
      } else if (index === 1) {
        queueSong(song);
        ConfirmDialog.toast(this.getUIContext(), '已加入试听列表');
      } else if (index === 2) {
        this.toggleFavorite(song);
      } else if (index === 3) {
        this.addToPlaylist(song);
      } else if (index === 4) {
        downloadStore.addFromSong(song, settingsStore.prefs.defaultQuality)
          .then((result: DownloadOpResult) => {
            ConfirmDialog.toast(this.getUIContext(), result.message);
          });
      }
    });
  }

  private async toggleFavorite(song: Song): Promise<void> {
    if (!libraryStore.findSong(song.id)) {
      ConfirmDialog.toast(this.getUIContext(), '在线曲目暂未同步到曲库，收藏前请先同步');
      return;
    }
    const outcome = await libraryStore.toggleFavorite(song.id);
    ConfirmDialog.toast(this.getUIContext(), outcome.message);
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text(this.param.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${ServerEndpoints.platformLabel(this.param.source)} · ${this.songs.length} 首`)
          .fontSize(10.5)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
  }

  @Builder
  actions() {
    Row({ space: 8 }) {
      Row({ space: 5 }) {
        Image($r('app.media.ic_play'))
          .width(12)
          .height(12)
          .fillColor('#FFFFFF')
        Text('播放全部')
          .fontSize(11)
          .fontColor('#FFFFFF')
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(themeStore.palette.brand)
      .onClick(() => {
        playVisualSong(this.songs, 0);
      })

      Row({ space: 5 }) {
        Image($r('app.media.ic_shuffle'))
          .width(12)
          .height(12)
          .fillColor(themeStore.palette.text)
        Text('随机播放')
          .fontSize(11)
          .fontColor(themeStore.palette.text)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(themeStore.palette.controlBg)
      .onClick(() => {
        playSongsShuffled(this.songs);
      })

      Blank()
    }
    .width('100%')
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        this.header()

        if (this.loading) {
          EmptyState({ loading: true, title: '正在加载曲目' })
            .layoutWeight(1)
        } else if (this.errorText.length > 0) {
          EmptyState({
            title: '加载失败',
            description: this.errorText,
            actionText: '重试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              this.load();
            }
          })
            .layoutWeight(1)
        } else if (this.songs.length === 0) {
          EmptyState({
            title: '这里还没有曲目',
            description: '该音源可能暂不可用，稍后重试或切换音源',
            actionText: '重试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              this.load();
            }
          })
            .layoutWeight(1)
        } else {
          this.actions()
          List() {
            // Repeat 虚拟滚动：合集曲目可能上千首，仅渲染可视区+预加载区。
            Repeat<Song>(this.songs)
              .key((song: Song) => song.id)
              .each((ri: RepeatItem<Song>) => {
                ListItem() {
                  SongRow({
                    ri: ri,
                    textColor: themeStore.palette.text,
                    subColor: themeStore.palette.sub,
                    accent: themeStore.palette.brand,
                    onTap: (item: Song) => {
                      playVisualSong(this.songs, ri.index);
                    },
                    onMore: (item: Song) => {
                      this.showActions(item);
                    }
                  })
                }
              })
              .virtualScroll()
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: themeStore.palette.softDivider })
          .scrollBar(BarState.Off)
          .cachedCount(8)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8 })
      .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
    }
    .title(this.param.title)
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .systemMaterial(ImmersiveGlass.title())
    .onReady((ctx: NavDestinationContext) => {
      if (ctx.pathInfo.param !== undefined) {
        const param = ctx.pathInfo.param as DiscoverCollectionParam;
        if (param !== null && param !== undefined) {
          this.param = param;
        }
      }
      this.load();
    })
  }
}

@Builder
export function DiscoverCollectionBuilder() {
  DiscoverCollectionPage()
}
