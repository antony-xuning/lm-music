/**
 * 首页 · 本地曲库：扫描统计、扫描状态与进度、文件夹管理、最近添加与全部本地曲目。
 */
import { DockMetrics } from '../common/Constants';
import { Artwork } from '../components/Artwork';
import { BadgeView } from '../components/Badge';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SectionHeader } from '../components/SectionHeader';
import { Song } from '../model/MediaModels';
import { LocalFolder, LocalScanHelper, LocalScanPhase, LocalTrack } from '../model/LocalScanModels';
import { playVisualSong } from '../service/PlaybackLauncher';
import { Formatters } from '../service/Formatters';
import { MediaTagService } from '../service/MediaTagService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { localScanStore } from '../viewmodel/LocalScanStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';

@ComponentV2
export struct LocalHomeView {
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

  private playAll(index: number): void {
    const tracks: LocalTrack[] = localScanStore.allTracks;
    const songs: Song[] = localScanStore.songsFrom(tracks);
    playVisualSong(songs, index);
  }

  private playRecent(index: number): void {
    const tracks: LocalTrack[] = localScanStore.recentTracks;
    const songs: Song[] = localScanStore.songsFrom(tracks);
    playVisualSong(songs, index);
  }

  private async addFolder(): Promise<void> {
    await localScanStore.addFolder();
    if (localScanStore.message.length > 0) {
      ConfirmDialog.toast(this.getUIContext(), localScanStore.message);
    }
  }

  private async rescan(): Promise<void> {
    await localScanStore.scanAll();
    if (localScanStore.message.length > 0) {
      ConfirmDialog.toast(this.getUIContext(), localScanStore.message);
    }
  }

  private async removeFolder(folder: LocalFolder): Promise<void> {
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '移除音乐文件夹',
      `将移除「${folder.displayName}」及其曲目索引，不会删除磁盘上的音频文件。`, '移除');
    if (ok) {
      await localScanStore.removeFolder(folder);
      ConfirmDialog.toast(this.getUIContext(), localScanStore.message);
    }
  }

  private progressRatio(): number {
    if (localScanStore.discovered <= 0) {
      return localScanStore.scanning ? 0.08 : 0;
    }
    const ratio: number = localScanStore.scanned / localScanStore.discovered;
    return Math.max(0, Math.min(ratio, 1));
  }

  private scanDetail(): string {
    const parts: string[] = [];
    parts.push(`已扫描 ${localScanStore.scanned}/${localScanStore.discovered}`);
    if (localScanStore.addedCount > 0) {
      parts.push(`新增 ${localScanStore.addedCount}`);
    }
    if (localScanStore.updatedCount > 0) {
      parts.push(`更新 ${localScanStore.updatedCount}`);
    }
    if (localScanStore.removedCount > 0) {
      parts.push(`移除 ${localScanStore.removedCount}`);
    }
    if (localScanStore.errorCount > 0) {
      parts.push(`跳过 ${localScanStore.errorCount}`);
    }
    return parts.join(' · ');
  }

  /** 标题与搜索已由 HomeHeader 统一承载，这里仅保留本地模式说明。 */
  @Builder
  headerBlock() {
    Text('本地文件夹扫描结果，无需服务器即可播放')
      .fontSize(11)
      .fontColor(themeStore.palette.sub)
      .width('100%')
      .padding({ top: 2, bottom: 10 })
  }

  @Builder
  statsBlock() {
    Row({ space: 8 }) {
      this.statCell(`${localScanStore.trackCount}`, '曲目')
      this.statCell(`${localScanStore.folderCount}`, '文件夹')
      this.statCell(LocalScanHelper.formatBytes(localScanStore.totalBytes), '占用')
    }
    .width('100%')
  }

  @Builder
  statCell(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(10)
        .fontColor(themeStore.palette.sub)
    }
    .layoutWeight(1)
    .padding({ top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  scanBlock() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(localScanStore.phaseLabel)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(localScanStore.phase === LocalScanPhase.ERROR ? '#FFB44C' : themeStore.palette.text)
        Blank()
        Text(this.scanDetail())
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')

      Row() {
        Row()
          .height(3)
          .width(`${Math.max(this.progressRatio() * 100, localScanStore.scanning ? 4 : 0)}%`)
          .borderRadius(2)
          .backgroundColor(themeStore.palette.brand)
      }
      .width('100%')
      .height(3)
      .borderRadius(2)
      .backgroundColor('#1F1F26')

      if (localScanStore.scanning && localScanStore.currentFile.length > 0) {
        Text(localScanStore.currentFile)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      if (localScanStore.errorLines.length > 0) {
        Column({ space: 2 }) {
          ForEach(localScanStore.errorLines.slice(0, 3), (line: string, index: number) => {
            Text(line)
              .fontSize(9.5)
              .fontColor('#FFB44C')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }, (line: string, index: number) => `${index}_${line}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  actionBlock() {
    Row({ space: 8 }) {
      Text('添加音乐文件夹')
        .fontSize(12.5)
        .fontColor('#FFFFFF')
        .fontWeight(FontWeight.Medium)
        .padding({ left: 14, right: 14, top: 8, bottom: 8 })
        .borderRadius(17)
        .backgroundColor(themeStore.palette.brand)
        .stateStyles({
          pressed: { .scale({ x: 0.92, y: 0.92 }) },
          normal: { .scale({ x: 1, y: 1 }) }
        })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onClick(() => {
          this.addFolder();
        })

      if (localScanStore.scanning) {
        Text('取消')
          .fontSize(12)
          .fontColor(themeStore.palette.text)
          .padding({ left: 13, right: 13, top: 8, bottom: 8 })
          .borderRadius(17)
          .backgroundColor(themeStore.palette.cardSoft)
          .stateStyles({
            pressed: { .scale({ x: 0.92, y: 0.92 }) },
            normal: { .scale({ x: 1, y: 1 }) }
          })
          .animation({ duration: 120, curve: Curve.EaseOut })
          .onClick(() => {
            localScanStore.cancel();
          })
      } else {
        Text('重新扫描')
          .fontSize(12)
          .fontColor(themeStore.palette.text)
          .padding({ left: 13, right: 13, top: 8, bottom: 8 })
          .borderRadius(17)
          .backgroundColor(themeStore.palette.cardSoft)
          .opacity(localScanStore.folderCount > 0 ? 1 : 0.5)
          .onClick(() => {
            if (localScanStore.folderCount > 0) {
              this.rescan();
            }
          })
      }
      Blank()
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @Builder
  folderRow(folder: LocalFolder) {
    Row({ space: 8 }) {
      Column({ space: 2 }) {
        Text(folder.displayName)
          .fontSize(12.5)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(folder.invalid && folder.error.length > 0
          ? folder.error : `${folder.fileCount} 首 · 最近扫描 ${Formatters.relativeDate(folder.lastScanAt)}`)
          .fontSize(9.5)
          .fontColor(folder.invalid ? '#FFB44C' : themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('扫描')
        .fontSize(10.5)
        .fontColor(themeStore.palette.brand)
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor(themeStore.palette.chipBg)
        .onClick(() => {
          localScanStore.rescanFolder(folder.uri);
        })

      Text('移除')
        .fontSize(10.5)
        .fontColor('#FF7A8A')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor(themeStore.palette.chipBg)
        .onClick(() => {
          this.removeFolder(folder);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  @Builder
  folderBlock() {
    Column({ space: 4 }) {
      SectionHeader({
        title: '音乐文件夹',
        subtitle: `${localScanStore.folderCount} 个文件夹${localScanStore.invalidFolderCount > 0
          ? ` · ${localScanStore.invalidFolderCount} 个待重新授权` : ''}`,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      })
      Column() {
        ForEach(localScanStore.folders, (folder: LocalFolder) => {
          this.folderRow(folder)
        }, (folder: LocalFolder) => folder.uri)
      }
      .width('100%')
      .padding({ left: 10, right: 10 })
      .borderRadius(16)
      .backgroundColor(themeStore.palette.card)
    }
    .width('100%')
    .padding({ bottom: 8 })
  }

  @Builder
  trackRow(track: LocalTrack, index: number, fromRecent: boolean) {
    Row({ space: 10 }) {
      Artwork({
        seed: Math.abs(track.fileName.length * 7 + track.title.length),
        artworkSize: 44,
        radius: 10,
        title: track.title,
        showRing: false,
        remoteUrl: MediaTagService.coverUriOf(track)
      })

      Column({ space: 2 }) {
        Text(track.title)
          .fontSize(themeStore.font(13))
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${track.artist} · ${track.album}`)
          .fontSize(themeStore.font(10))
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      BadgeView({ text: '本地', tone: 'success' })
      Text(Formatters.duration(track.durationMs))
        .fontSize(themeStore.font(10))
        .fontColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      if (fromRecent) {
        this.playRecent(index);
      } else {
        this.playAll(index);
      }
    })
  }

  @Builder
  emptyBlock() {
    EmptyState({
      title: '还没有本地音乐',
      description: '添加一个音乐文件夹开始扫描',
      actionText: '添加音乐文件夹',
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      accent: themeStore.palette.brand,
      onAction: () => {
        this.addFolder();
      }
    })
  }

  @Builder
  sectionRow(title: string, subtitle: string) {
    Column() {
      SectionHeader({
        title: title,
        subtitle: subtitle,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      })
    }
    .width('100%')
    .padding({ top: 12, bottom: 4 })
  }

  build() {
    List({ space: 0, scroller: this.scroller }) {
      ListItem() {
        this.headerBlock()
      }

      ListItem() {
        this.statsBlock()
      }

      if (localScanStore.phase !== LocalScanPhase.IDLE) {
        ListItem() {
          this.scanBlock()
        }
        .padding({ top: 10 })
      }

      ListItem() {
        this.actionBlock()
      }

      if (localScanStore.folderCount > 0) {
        ListItem() {
          this.folderBlock()
        }
      }

      if (localScanStore.trackCount === 0) {
        ListItem() {
          this.emptyBlock()
        }
      } else {
        if (localScanStore.recentTracks.length > 0) {
          ListItem() {
            this.sectionRow('最近添加', `${localScanStore.recentTracks.length} 首`)
          }
          ForEach(localScanStore.recentTracks, (track: LocalTrack, index: number) => {
            ListItem() {
              this.trackRow(track, index, true)
            }
          }, (track: LocalTrack) => `recent_${track.uri}`)
        }

        ListItem() {
          this.sectionRow('全部本地曲目', `${localScanStore.trackCount} 首`)
        }
        ForEach(localScanStore.allTracks, (track: LocalTrack, index: number) => {
          ListItem() {
            this.trackRow(track, index, false)
          }
        }, (track: LocalTrack) => `all_${track.uri}`)
      }

      ListItem() {
        Column()
          .height(1)
          .width('100%')
      }
      .height(1)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .cachedCount(8)
    .onDidScroll((delta: number, state: ScrollState) => {
      scrollChrome.reportFromScroller(this.scroller, delta);
    })
    .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 0,
      bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed) })
    .animation({ duration: 220, curve: Curve.EaseOut })
  }
}

