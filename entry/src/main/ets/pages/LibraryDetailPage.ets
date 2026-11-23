/**
 * 资料库二级页：歌曲/专辑/歌手/歌单/收藏/最近/本地列表，含排序、过滤、多选与歌单管理。
 */
import { AppConstants, DockMetrics } from '../common/Constants';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { Artwork } from '../components/Artwork';
import { EmptyState } from '../components/EmptyState';
import { LibraryNameDialog, LibrarySelectionBar } from '../components/LibraryAuxPanels';
import { SongRow } from '../components/SongRow';
import { Album, Artist, MediaSource, Playlist, Song } from '../model/MediaModels';
import { LibraryDetailParam, LibraryKind, TagEditorParam } from '../model/UiModels';
import { Formatters } from '../service/Formatters';
import { playSongsShuffled, playVisualSong, queueSong } from '../service/PlaybackLauncher';
import { layoutStore } from '../viewmodel/LayoutStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { downloadStore } from '../viewmodel/DownloadStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { WriteOutcome } from '../viewmodel/LibraryModels';
import { LibraryViewState } from '../viewmodel/LibraryViewState';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { routeBridge } from '../viewmodel/RouteBridge';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

@ComponentV2
export struct LibraryDetailPage {
  @Local param: LibraryDetailParam = new LibraryDetailParam();
  @Local sortIndex: number = 0;
  @Local keyword: string = '';
  @Local selectionMode: boolean = false;
  @Local selectedIds: string[] = [];
  @Local showNameDialog: boolean = false;
  @Local nameInput: string = '';
  @Local renameTargetId: string = '';
  @Local busy: boolean = false;

  private navStack: NavPathStack = new NavPathStack();

  private stateKey(): string {
    return `${this.param.kind}_${this.param.id}_${this.param.title}`;
  }

  private seed(): number {
    return Math.abs(this.param.title.length * 7 + this.param.id.length) % 12;
  }

  private albumMode(): boolean {
    return this.param.kind === LibraryKind.ALBUM && this.param.id.length === 0;
  }

  private artistMode(): boolean {
    return this.param.kind === LibraryKind.ARTIST && this.param.id.length === 0;
  }

  private playlistManageMode(): boolean {
    return this.param.kind === LibraryKind.PLAYLIST && this.param.id.length === 0;
  }

  private baseSongs(): Song[] {
    if (this.param.kind === LibraryKind.FAVORITES) {
      return libraryStore.favoriteSongs;
    }
    if (this.param.kind === LibraryKind.RECENT) {
      return libraryStore.recentSongs;
    }
    if (this.param.kind === LibraryKind.DOWNLOADED) {
      return libraryStore.downloadedSongs;
    }
    if (this.param.kind === LibraryKind.ALBUM) {
      return libraryStore.albumSongs(this.param.id);
    }
    if (this.param.kind === LibraryKind.ARTIST) {
      return libraryStore.artistSongs(this.param.id, this.param.title);
    }
    if (this.param.kind === LibraryKind.PLAYLIST) {
      return libraryStore.playlistSongs(this.param.id);
    }
    if (this.param.kind === LibraryKind.FOLDER) {
      return libraryStore.localSongs.concat(libraryStore.scannedSongs);
    }
    return libraryStore.allSongs;
  }

  private displaySongs(): Song[] {
    const source: Song[] = this.baseSongs();
    const keyword: string = this.keyword.trim().toLowerCase();
    const filtered: Song[] = [];
    for (let i = 0; i < source.length; i++) {
      const song: Song = source[i];
      if (keyword.length === 0
        || song.title.toLowerCase().indexOf(keyword) >= 0
        || song.artist.toLowerCase().indexOf(keyword) >= 0
        || song.album.toLowerCase().indexOf(keyword) >= 0) {
        filtered.push(song);
      }
    }
    const sorted: Song[] = filtered.slice();
    if (this.sortIndex === 1) {
      sorted.sort((a: Song, b: Song) => a.title.localeCompare(b.title));
    } else if (this.sortIndex === 2) {
      sorted.sort((a: Song, b: Song) => a.durationMs - b.durationMs);
    } else {
      sorted.sort((a: Song, b: Song) => b.addedAt - a.addedAt);
    }
    return sorted;
  }

  private isSelected(id: string): boolean {
    return this.selectedIds.indexOf(id) >= 0;
  }

  private toggleSelect(id: string): void {
    if (this.isSelected(id)) {
      const next: string[] = [];
      for (let i = 0; i < this.selectedIds.length; i++) {
        if (this.selectedIds[i] !== id) {
          next.push(this.selectedIds[i]);
        }
      }
      this.selectedIds = next;
    } else {
      this.selectedIds = this.selectedIds.concat([id]);
    }
  }

  private selectAll(): void {
    const songs: Song[] = this.displaySongs();
    const ids: string[] = [];
    for (let i = 0; i < songs.length; i++) {
      ids.push(songs[i].id);
    }
    this.selectedIds = ids;
  }

  private invertSelection(): void {
    const songs: Song[] = this.displaySongs();
    const ids: string[] = [];
    for (let i = 0; i < songs.length; i++) {
      if (!this.isSelected(songs[i].id)) {
        ids.push(songs[i].id);
      }
    }
    this.selectedIds = ids;
  }

  private selectedBytes(): number {
    let total: number = 0;
    const songs: Song[] = this.displaySongs();
    for (let i = 0; i < songs.length; i++) {
      if (this.isSelected(songs[i].id)) {
        total += songs[i].sizeBytes;
      }
    }
    return total;
  }

  private async removeSelected(): Promise<void> {
    if (this.selectedIds.length === 0 || this.busy) {
      return;
    }
    const ids: string[] = this.selectedIds.slice();
    if (this.param.kind === LibraryKind.PLAYLIST && this.param.id.length > 0) {
      const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '从歌单移除',
        `确定要从「${this.param.title}」移除 ${ids.length} 首歌曲吗？`, '移除');
      if (!ok) {
        return;
      }
      this.busy = true;
      const outcome: WriteOutcome = await libraryStore.removeFromPlaylist(this.param.id, ids);
      this.busy = false;
      ConfirmDialog.toast(this.getUIContext(), outcome.message);
      if (outcome.ok) {
        this.selectedIds = [];
        this.selectionMode = false;
      }
      return;
    }
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '删除本地曲目',
      `将移除 ${ids.length} 首本地曲目记录：导入曲目会删除沙箱文件，文件夹扫描曲目仅移除索引。`, '删除');
    if (!ok) {
      return;
    }
    const localIds: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      const song: Song | null = libraryStore.findSong(ids[i]);
      if (song !== null && song.isLocal) {
        localIds.push(song.id);
      }
    }
    if (localIds.length === 0) {
      ConfirmDialog.toast(this.getUIContext(), '服务器曲目不能删除本地文件');
      return;
    }
    const removed: number = libraryStore.removeLocalSongs(localIds);
    this.selectedIds = [];
    this.selectionMode = false;
    ConfirmDialog.toast(this.getUIContext(), `已删除 ${removed} 首本地曲目`);
  }

  private openNameDialog(playlistId: string, name: string): void {
    this.renameTargetId = playlistId;
    this.nameInput = name;
    this.showNameDialog = true;
  }

  private async confirmName(): Promise<void> {
    const name: string = this.nameInput.trim();
    if (name.length === 0) {
      ConfirmDialog.toast(this.getUIContext(), '请输入歌单名称');
      return;
    }
    this.busy = true;
    let outcome: WriteOutcome = new WriteOutcome();
    if (this.renameTargetId.length > 0) {
      outcome = await libraryStore.renamePlaylist(this.renameTargetId, name);
    } else {
      outcome = await libraryStore.createPlaylist(name);
    }
    this.busy = false;
    ConfirmDialog.toast(this.getUIContext(), outcome.message);
    if (outcome.ok) {
      this.showNameDialog = false;
      this.nameInput = '';
      this.renameTargetId = '';
    }
  }

  private async deletePlaylist(playlist: Playlist): Promise<void> {
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '删除歌单',
      `确定删除「${playlist.name}」？该操作会同步到服务器。`, '删除');
    if (!ok) {
      return;
    }
    this.busy = true;
    const outcome: WriteOutcome = await libraryStore.deletePlaylist(playlist.id);
    this.busy = false;
    ConfirmDialog.toast(this.getUIContext(), outcome.message);
  }

  private pushDetail(param: LibraryDetailParam): void {
    this.navStack.pushPathByName(AppConstants.ROUTE_LIBRARY_DETAIL, param);
  }

  @Builder
  summaryCard() {
    Row({ space: 12 }) {
      Artwork({
        seed: this.seed(),
        artworkSize: 76,
        radius: 18,
        title: this.param.title,
        showRing: true,
        showInitial: !this.artistMode() && !this.playlistManageMode() && !this.albumMode()
      })

      Column({ space: 4 }) {
        Text(this.param.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.summaryText())
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
          .maxLines(2)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .borderRadius(20)
    .backgroundColor(themeStore.palette.card)
  }

  private summaryText(): string {
    if (this.artistMode()) {
      return `${libraryStore.artists.length} 位歌手 · 点击进入查看曲目`;
    }
    if (this.albumMode()) {
      return `${libraryStore.albums.length} 张专辑 · 点击进入查看曲目`;
    }
    if (this.playlistManageMode()) {
      return `${libraryStore.playlists.length} 个歌单 · 可新建/重命名/删除`;
    }
    return `${this.displaySongs().length} 首 · 共 ${Formatters.bytes(this.totalBytes())}`;
  }

  private totalBytes(): number {
    const songs: Song[] = this.displaySongs();
    let total: number = 0;
    for (let i = 0; i < songs.length; i++) {
      total += songs[i].sizeBytes;
    }
    return total;
  }

  @Builder
  actionsRow() {
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
        playVisualSong(this.displaySongs(), 0);
      })

      Row({ space: 5 }) {
        Image($r('app.media.ic_shuffle'))
          .width(12)
          .height(12)
          .fillColor(themeStore.palette.text)
        Text('随机')
          .fontSize(11)
          .fontColor(themeStore.palette.text)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        playSongsShuffled(this.displaySongs());
      })

      Row({ space: 5 }) {
        Image($r('app.media.ic_check'))
          .width(12)
          .height(12)
          .fillColor(themeStore.palette.text)
        Text(this.selectionMode ? '退出多选' : '多选')
          .fontSize(11)
          .fontColor(themeStore.palette.text)
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        this.selectionMode = !this.selectionMode;
        if (!this.selectionMode) {
          this.selectedIds = [];
        }
      })

      Blank()
    }
    .width('100%')
  }

  @Builder
  searchAndSort() {
    Row({ space: 8 }) {
      TextInput({ text: this.keyword, placeholder: '搜索歌名 / 歌手 / 专辑' })
        .fontSize(12)
        .fontColor(themeStore.palette.text)
        .placeholderColor(themeStore.palette.sub)
        .backgroundColor('#22FFFFFF')
        .borderRadius(14)
        .height(36)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.keyword = value;
          LibraryViewState.setKeyword(this.stateKey(), value);
        })

      Text(this.sortLabel())
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          this.sortIndex = (this.sortIndex + 1) % 3;
          LibraryViewState.setSort(this.stateKey(), this.sortIndex);
        })
    }
    .width('100%')
  }

  private sortLabel(): string {
    if (this.sortIndex === 1) {
      return '按标题';
    }
    if (this.sortIndex === 2) {
      return '按时长';
    }
    return '按日期';
  }

  @Builder
  artistRow(artist: Artist) {
    Row({ space: 10 }) {
      Artwork({
        seed: artist.coverSeed,
        artworkSize: 44,
        radius: 22,
        title: artist.name,
        showRing: false,
        remoteUrl: artist.coverUrl
      })
      Column({ space: 2 }) {
        Text(artist.name)
          .fontSize(13.5)
          .fontColor(themeStore.palette.text)
        Text(`${artist.songCount} 首`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_next'))
        .width(15)
        .height(15)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.pushDetail(LibraryDetailParam.create(LibraryKind.ARTIST, artist.name, artist.id));
    })
  }

  @Builder
  albumRow(album: Album) {
    Row({ space: 10 }) {
      Artwork({
        seed: album.coverSeed,
        artworkSize: 44,
        radius: 12,
        title: album.title,
        showRing: false,
        showInitial: false,
        remoteUrl: album.coverUrl
      })
      Column({ space: 2 }) {
        Text(album.title)
          .fontSize(13.5)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${album.artist}${album.year > 0 ? ' · ' + album.year : ''}`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_next'))
        .width(15)
        .height(15)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.pushDetail(LibraryDetailParam.create(LibraryKind.ALBUM, album.title, album.id));
    })
  }

  @Builder
  playlistManageRow(playlist: Playlist) {
    Row({ space: 10 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 44,
        radius: 12,
        title: playlist.name,
        showRing: false,
        showInitial: false,
        remoteUrl: playlist.coverUrl
      })
      Column({ space: 2 }) {
        Text(playlist.name)
          .fontSize(13.5)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${playlist.entries.length} 首`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Stack() {
        Image($r('app.media.ic_edit'))
          .width(14)
          .height(14)
          .fillColor(themeStore.palette.sub)
      }
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        this.openNameDialog(playlist.id, playlist.name);
      })

      Stack() {
        Image($r('app.media.ic_trash'))
          .width(14)
          .height(14)
          .fillColor('#FA2D48')
      }
      .width(30)
      .height(30)
      .borderRadius(15)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        this.deletePlaylist(playlist);
      })

      Image($r('app.media.ic_next'))
        .width(15)
        .height(15)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.pushDetail(LibraryDetailParam.create(LibraryKind.PLAYLIST, playlist.name, playlist.id));
    })
  }

  @Builder
  listModes() {
    Column({ space: 10 }) {
      if (this.playlistManageMode()) {
        Row() {
          Text(this.busy ? '处理中…' : '新建歌单')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(14)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.openNameDialog('', '');
            })
          Blank()
        }
        .width('100%')
      }

      Scroll() {
        Column() {
          if (this.artistMode()) {
            ForEach(libraryStore.artists, (artist: Artist) => {
              this.artistRow(artist)
            }, (artist: Artist) => artist.id)
          } else if (this.albumMode()) {
            ForEach(libraryStore.albums, (album: Album) => {
              this.albumRow(album)
            }, (album: Album) => album.id)
          } else {
            ForEach(libraryStore.playlists, (playlist: Playlist) => {
              this.playlistManageRow(playlist)
            }, (playlist: Playlist) => playlist.id)
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .layoutWeight(1)
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 10 }) {
          this.summaryCard()

          if (this.isListMode()) {
            this.listModes()
          } else {
            this.actionsRow()
            this.searchAndSort()

            if (this.displaySongs().length === 0) {
              EmptyState({
                title: this.emptyTitle(),
                description: '同步服务器曲库后即可在此浏览',
                textColor: themeStore.palette.text,
                subColor: themeStore.palette.sub,
                accent: themeStore.palette.brand
              })
                .layoutWeight(1)
            } else {
              List() {
                ForEach(this.displaySongs(), (song: Song, index: number) => {
                  ListItem() {
                    SongRow({
                      song: song,
                      index: index,
                      selectionMode: this.selectionMode,
                      selected: this.isSelected(song.id),
                      textColor: themeStore.palette.text,
                      subColor: themeStore.palette.sub,
                      accent: themeStore.palette.brand,
                      onTap: (item: Song) => {
                        playVisualSong(this.displaySongs(), index);
                      },
                      onSelect: (item: Song) => {
                        this.toggleSelect(item.id);
                      },
                      onMore: (item: Song) => {
                        this.showSongMenu(item);
                      }
                    })
                  }
                }, (song: Song) => song.id)
              }
              .width('100%')
              .layoutWeight(1)
              .divider({ strokeWidth: 0.5, color: '#14FFFFFF' })
              .scrollBar(BarState.Off)
              .cachedCount(8)
              .padding({ bottom: DockMetrics.contentBottomInset(playerStore.current !== null) })
            }
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8 })

        if (this.selectionMode && !this.isListMode()) {
          LibrarySelectionBar({
            selectedCount: this.selectedIds.length,
            selectedBytes: this.selectedBytes(),
            playlistMode: this.param.kind === LibraryKind.PLAYLIST,
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            blurStyle: themeStore.blurStyle,
            onSelectAll: () => {
              this.selectAll();
            },
            onInvert: () => {
              this.invertSelection();
            },
            onAddToPlaylist: () => {
              if (this.selectedIds.length > 0) {
                overlayStore.openAddToPlaylist(this.selectedIds);
              }
            },
            onRemove: () => {
              this.removeSelected();
            }
          })
        }

        if (this.showNameDialog) {
          Column() {
            LibraryNameDialog({
              dialogTitle: this.renameTargetId.length > 0 ? '重命名歌单' : '新建歌单',
              nameValue: this.nameInput,
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand,
              cardColor: themeStore.palette.card,
              blurStyle: themeStore.blurStyle,
              onNameChange: (value: string) => {
                this.nameInput = value;
              },
              onCancel: () => {
                this.showNameDialog = false;
              },
              onConfirm: () => {
                this.confirmName();
              }
            })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor('#88000000')
        }
      }
      .width('100%')
      .height('100%')
      .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
    }
    .title(this.param.title)
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .systemMaterial(ImmersiveGlass.title())
    .onReady((ctx: NavDestinationContext) => {
      this.navStack = ctx.pathStack;
      if (ctx.pathInfo.param !== undefined) {
        const param = ctx.pathInfo.param as LibraryDetailParam;
        if (param !== null && param !== undefined) {
          this.param = param;
        }
      }
      this.sortIndex = LibraryViewState.sortOf(this.stateKey());
      this.keyword = LibraryViewState.keywordOf(this.stateKey());
    })
  }

  private isListMode(): boolean {
    return this.artistMode() || this.albumMode() || this.playlistManageMode();
  }

  private showSongMenu(song: Song): void {
    const actions: string[] = [];
    actions.push('立即播放');
    actions.push('加入队列');
    actions.push(song.isFavorite ? '取消喜欢' : '喜欢');
    actions.push('加入歌单');
    if (!song.isLocal) {
      actions.push('下载到服务器');
    }
    if (song.isLocal) {
      actions.push('删除本地文件');
    }
    if (song.source === MediaSource.SERVER_FILE) {
      actions.push('标签编辑');
    }
    ConfirmDialog.actionSheet(this.getUIContext(), song.title, actions).then((index: number) => {
      if (index === 0) {
        playVisualSong([song], 0);
      } else if (index === 1) {
        queueSong(song);
        ConfirmDialog.toast(this.getUIContext(), '已加入播放队列');
      } else if (index === 2) {
        libraryStore.toggleFavorite(song.id).then((outcome) => {
          ConfirmDialog.toast(this.getUIContext(), outcome.message);
        });
      } else if (index === 3) {
        overlayStore.openAddToPlaylist([song.id]);
      } else if (index === 4) {
        if (song.isLocal) {
          this.confirmDeleteLocal(song);
        } else {
          downloadStore.addFromSong(song, settingsStore.prefs.defaultQuality).then((result) => {
            ConfirmDialog.toast(this.getUIContext(), result.message);
          });
        }
      } else if (index === 5 && song.source === MediaSource.SERVER_FILE) {
        routeBridge.open(AppConstants.ROUTE_TAG_EDITOR, TagEditorParam.create(song.id, song.filePath));
      }
    });
  }

  private confirmDeleteLocal(song: Song): void {
    const scanned: boolean = song.audioRef.startsWith('file://');
    const detail: string = scanned
      ? `将把「${song.title}」从本地曲库索引移除，不会删除原音频文件。`
      : `将删除「${song.title}」及其沙箱文件。`;
    ConfirmDialog.confirm(this.getUIContext(), '删除本地曲目', detail, '删除').then((ok: boolean) => {
      if (ok) {
        libraryStore.removeLocalSongs([song.id]);
        ConfirmDialog.toast(this.getUIContext(), '已删除本地曲目');
      }
    });
  }

  private emptyTitle(): string {
    if (this.param.kind === LibraryKind.FAVORITES) {
      return '还没有喜欢的歌曲';
    }
    if (this.param.kind === LibraryKind.RECENT) {
      return '还没有播放记录';
    }
    if (this.param.kind === LibraryKind.FOLDER) {
      return '还没有导入本地音乐';
    }
    return '这里还没有歌曲';
  }
}

@Builder
export function LibraryDetailBuilder() {
  LibraryDetailPage()
}




