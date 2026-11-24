/**
 * 更多操作面板：收藏、加入歌单、下载到服务器、标签编辑（仅服务器文件）。
 */
import { SheetShell } from '../components/SheetShell';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { MediaSource, PlayableItem, Song } from '../model/MediaModels';
import { TagEditorParam } from '../model/UiModels';
import { AppConstants } from '../common/Constants';
import { Formatters } from '../service/Formatters';
import { DownloadOpResult } from '../service/ServerDownloadService';
import { downloadStore } from '../viewmodel/DownloadStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { routeBridge } from '../viewmodel/RouteBridge';
import { settingsStore } from '../viewmodel/SettingsStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct PlayerMoreSheet {
  private currentItem(): PlayableItem | null {
    return playerStore.current;
  }

  private songId(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.songId : '';
  }

  private titleText(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null ? item.title : '未在播放';
  }

  private detailText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return '';
    }
    if (item.songId.length > 0) {
      const song: Song | null = libraryStore.findSong(item.songId);
      if (song !== null) {
        return `${song.album} · ${Formatters.duration(song.durationMs)}${song.sizeBytes > 0 ? ' · ' + Formatters.bytes(song.sizeBytes) : ''}`;
      }
    }
    return item.isPodcast ? '播客单集' : `${item.subtitle} · ${Formatters.duration(item.durationMs)}`;
  }

  private isServerFile(): boolean {
    const item: PlayableItem | null = playerStore.current;
    return item !== null && item.mediaSource === MediaSource.SERVER_FILE && item.filePath.length > 0;
  }

  private async downloadToServer(): Promise<void> {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return;
    }
    const quality: string = settingsStore.prefs.defaultQuality;
    let song: Song | null = item.songId.length > 0 ? libraryStore.findSong(item.songId) : null;
    if (song === null) {
      const synthetic: Song = new Song();
      synthetic.id = item.songId.length > 0 ? item.songId : item.id;
      synthetic.title = item.title;
      synthetic.artist = item.subtitle;
      synthetic.album = '';
      synthetic.durationMs = item.durationMs;
      synthetic.platform = item.platform;
      synthetic.platformSongId = item.platformSongId;
      synthetic.filePath = item.filePath;
      synthetic.source = item.mediaSource;
      song = synthetic;
    }
    const result: DownloadOpResult = await downloadStore.addFromSong(song, quality);
    ConfirmDialog.toast(this.getUIContext(), result.message);
  }

  @Builder
  actionRow(icon: Resource, title: string, subtitle: string, action: () => void) {
    Row({ space: 12 }) {
      Stack() {
        Image(icon)
          .width(17)
          .height(17)
          .fillColor(themeStore.palette.text)
      }
      .width(36)
      .height(36)
      .borderRadius(12)
      .backgroundColor(themeStore.palette.controlBg)

      Column({ space: 2 }) {
        Text(title)
          .fontSize(13)
          .fontColor(themeStore.palette.text)
        Text(subtitle)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_next'))
        .width(14)
        .height(14)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }).opacity(0.8) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      action();
    })
  }

  build() {
    SheetShell({
      sheetTitle: '更多操作',
      sheetSubtitle: this.titleText(),
      panelColor: themeStore.palette.card,
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      onClose: () => {
        overlayStore.closeSheet();
      }
    }) {
      Column({ space: 4 }) {
        Text(this.detailText())
          .fontSize(10.5)
          .fontColor(themeStore.palette.sub)
          .width('100%')
          .padding({ bottom: 8 })

        this.actionRow($r('app.media.ic_heart'), '收藏 / 取消收藏', '同步到服务器收藏', () => {
          const id: string = this.songId();
          if (id.length === 0) {
            ConfirmDialog.toast(this.getUIContext(), '播客单集暂不支持收藏');
            return;
          }
          libraryStore.toggleFavorite(id).then((outcome) => {
            ConfirmDialog.toast(this.getUIContext(), outcome.message);
          });
        })

        this.actionRow($r('app.media.ic_playlist_add'), '加入歌单', '写入服务器上的自建歌单', () => {
          const item: PlayableItem | null = this.currentItem();
          if (item === null) {
            return;
          }
          overlayStore.openAddToPlaylist([item.songId.length > 0 ? item.songId : item.id]);
        })

        this.actionRow($r('app.media.ic_download'), '下载到服务器', '按默认音质提交服务器下载任务', () => {
          this.downloadToServer();
        })

        if (this.isServerFile()) {
          this.actionRow($r('app.media.ic_edit'), '标签编辑', '读取并修改服务器文件标签（需二次确认）', () => {
            const item: PlayableItem | null = this.currentItem();
            if (item === null) {
              return;
            }
            const param: TagEditorParam = TagEditorParam.create(item.songId, item.filePath);
            // 先进入路由页，再收起半模态浮层，避免浮层容器残留在新页面之上。
            routeBridge.open(AppConstants.ROUTE_TAG_EDITOR, param);
            overlayStore.closeSheet();
            overlayStore.closePlayer();
          })
        }

        this.actionRow($r('app.media.ic_copy'), '分享', '复制当前播放信息', () => {
          ConfirmDialog.toast(this.getUIContext(), '已复制播放信息');
        })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
