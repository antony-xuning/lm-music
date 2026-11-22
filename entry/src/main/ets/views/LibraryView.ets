/**
 * 资料库首页：服务器状态、真实数量入口、最近添加、专辑/歌手/歌单与本地导入。
 */
import { AppConstants, DockMetrics } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SectionHeader } from '../components/SectionHeader';
import { ServerStatusCard } from '../components/ServerStatusCard';
import { SongRow } from '../components/SongRow';
import { Artist, PlayableItem, Playlist, Song } from '../model/MediaModels';
import { LibraryDetailParam, LibraryKind } from '../model/UiModels';
import { Formatters } from '../service/Formatters';
import { ImportResult, ImportService } from '../service/ImportService';
import { playVisualSong } from '../service/PlaybackLauncher';
import { layoutStore } from '../viewmodel/LayoutStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { serverStore } from '../viewmodel/ServerStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';

const SCOPE: string = 'LibraryView';

@ComponentV2
export struct LibraryView {
  @Param onOpenDetail: (param: LibraryDetailParam) => void = () => {
  };
  @Local listLimit: number = 6;
  private scroller: Scroller = new Scroller();

  private latestSongs(): Song[] {
    const songs: Song[] = libraryStore.allSongs.slice();
    songs.sort((a: Song, b: Song) => b.addedAt - a.addedAt);
    return songs;
  }

  private async onImport(): Promise<void> {
    if (libraryStore.importing) {
      return;
    }
    libraryStore.importing = true;
    let settled: boolean = false;
    // 系统选择器不可用时避免一直停留在「导入中…」。
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

  private showSongActions(song: Song): void {
    const actions: string[] = ['立即播放', '加入队列', song.isFavorite ? '取消喜欢' : '喜欢', '加入歌单', '查看歌曲信息'];
    ConfirmDialog.actionSheet(this.getUIContext(), song.title, actions).then((index: number) => {
      if (index === 0) {
        playVisualSong([song], 0);
      } else if (index === 1) {
        playerStore.addToQueue([PlayableItem.fromSong(song)]);
        ConfirmDialog.toast(this.getUIContext(), '已加入播放队列');
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

  @Builder
  header() {
    Row({ space: 10 }) {
      Column({ space: 2 }) {
        Text('资料库')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(`${libraryStore.serverSongs.length} 首服务器曲目 · ${libraryStore.localSongs.length} 首本地`)
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Stack() {
        Image($r('app.media.ic_search'))
          .width(17)
          .height(17)
          .fillColor(themeStore.palette.text)
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        overlayStore.openSearch();
      })

      Row({ space: 5 }) {
        Image($r('app.media.ic_plus'))
          .width(13)
          .height(13)
          .fillColor('#FFFFFF')
        Text(libraryStore.importing ? '导入中…' : '导入本地音乐')
          .fontSize(11)
          .fontColor('#FFFFFF')
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(16)
      .backgroundColor(themeStore.palette.brand)
      .onClick(() => {
        this.onImport();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  /** 本地曲目数 = 导入 + 文件夹扫描，供计数与入口展示。 */
  private localCount(): number {
    return libraryStore.localSongs.length + libraryStore.scannedSongs.length;
  }

  /** 入口数量在卡片内部读取 Store，保证同步完成后即时刷新。 */
  private countOf(kind: LibraryKind): number {
    if (kind === LibraryKind.FAVORITES) {
      return libraryStore.favoriteSongs.length;
    }
    if (kind === LibraryKind.RECENT) {
      return libraryStore.recentSongs.length;
    }
    if (kind === LibraryKind.ALL) {
      return libraryStore.allSongs.length;
    }
    if (kind === LibraryKind.FOLDER) {
      return this.localCount();
    }
    if (kind === LibraryKind.ALBUM) {
      return libraryStore.albums.length;
    }
    if (kind === LibraryKind.ARTIST) {
      return libraryStore.artists.length;
    }
    return libraryStore.playlists.length;
  }

  private subtitleOf(kind: LibraryKind): string {
    if (kind === LibraryKind.FAVORITES) {
      return '收藏的曲目';
    }
    if (kind === LibraryKind.RECENT) {
      return '来自服务器';
    }
    if (kind === LibraryKind.ALL) {
      return '服务器 + 本地';
    }
    if (kind === LibraryKind.FOLDER) {
      return '应用沙箱内';
    }
    if (kind === LibraryKind.ALBUM) {
      return '服务器专辑';
    }
    if (kind === LibraryKind.ARTIST) {
      return '服务器歌手';
    }
    return '服务器歌单';
  }

  private detailIdOf(kind: LibraryKind): string {
    return '';
  }

  @Builder
  entryCard(title: string, seed: number, kind: LibraryKind) {
    Row({ space: 10 }) {
      Artwork({ seed: seed, artworkSize: 40, radius: 12, title: title, showRing: true, showInitial: false })
      Column({ space: 2 }) {
        Text(title)
          .fontSize(13.5)
          .fontWeight(FontWeight.Medium)
          .fontColor(themeStore.palette.text)
        Text(this.subtitleOf(kind))
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(`${this.countOf(kind)}`)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 9, bottom: 9 })
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
    .onClick(() => {
      const param: LibraryDetailParam = LibraryDetailParam.create(kind, title, this.detailIdOf(kind));
      this.onOpenDetail(param);
    })
  }

  @Builder
  quickEntries() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column() {
          this.entryCard('我喜欢', 8, LibraryKind.FAVORITES)
        }
        .layoutWeight(1)

        Column() {
          this.entryCard('最近播放', 6, LibraryKind.RECENT)
        }
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        Column() {
          this.entryCard('全部歌曲', 2, LibraryKind.ALL)
        }
        .layoutWeight(1)

        Column() {
          this.entryCard('本地音乐', 5, LibraryKind.FOLDER)
        }
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)

      Row({ space: 8 }) {
        Column() {
          this.entryCard('专辑', 3, LibraryKind.ALBUM)
        }
        .layoutWeight(1)

        Column() {
          this.entryCard('歌手', 7, LibraryKind.ARTIST)
        }
        .layoutWeight(1)
      }
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder
  artistChip(artist: Artist) {
    Column({ space: 6 }) {
      Artwork({
        seed: artist.coverSeed,
        artworkSize: 64,
        radius: 32,
        title: artist.name,
        showRing: false,
        remoteUrl: artist.coverUrl
      })
      Text(artist.name)
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${artist.songCount} 首`)
        .fontSize(9)
        .fontColor(themeStore.palette.sub)
    }
    .width(72)
    .onClick(() => {
      const param: LibraryDetailParam = LibraryDetailParam.create(LibraryKind.ARTIST, artist.name, artist.id);
      this.onOpenDetail(param);
    })
  }

  @Builder
  playlistCard(playlist: Playlist) {
    Column({ space: 6 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 108,
        radius: 16,
        title: playlist.name,
        showRing: true,
        showInitial: false,
        remoteUrl: playlist.coverUrl
      })
      Text(playlist.name)
        .fontSize(11.5)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(`${playlist.entries.length} 首`)
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
    }
    .width(108)
    .alignItems(HorizontalAlign.Start)
    .onClick(() => {
      const param: LibraryDetailParam = LibraryDetailParam.create(LibraryKind.PLAYLIST, playlist.name, playlist.id);
      this.onOpenDetail(param);
    })
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 16 }) {
        this.header()

        if (!serverStore.canRead) {
          EmptyState({
            title: '尚未连接柠檬音乐服务器',
            description: '在设置中填写服务器地址并登录后，自动同步曲库',
            actionText: '去设置',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              overlayStore.setTab(3);
            }
          })
        } else {
          ServerStatusCard()

          Row({ space: 8 }) {
            Text(syncStore.busy ? '正在同步…' : '立即同步')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .borderRadius(13)
              .backgroundColor(themeStore.palette.brand)
              .onClick(() => {
                this.sync();
              })

            if (libraryStore.syncedAt > 0) {
              Text(`离线可用 · 最后同步 ${Formatters.relativeDate(libraryStore.syncedAt)}`)
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
            }
            Blank()
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          this.quickEntries()

          Column({ space: 10 }) {
            SectionHeader({
              title: '最近添加',
              subtitle: `${libraryStore.allSongs.length} 首`,
              actionText: '查看全部',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              actionColor: themeStore.palette.brand,
              onAction: () => {
                this.onOpenDetail(LibraryDetailParam.create(LibraryKind.ALL, '全部歌曲'));
              }
            })

            if (libraryStore.allSongs.length === 0) {
              EmptyState({
                title: '曲库还是空的',
                description: '服务器曲库为空时，可导入本地音乐',
                actionText: '导入本地音乐',
                textColor: themeStore.palette.text,
                subColor: themeStore.palette.sub,
                accent: themeStore.palette.brand,
                onAction: () => {
                  this.onImport();
                }
              })
            } else {
              Column() {
                ForEach(this.latestSongs().slice(0, this.listLimit), (song: Song, index: number) => {
                  SongRow({
                    song: song,
                    index: index,
                    textColor: themeStore.palette.text,
                    subColor: themeStore.palette.sub,
                    accent: themeStore.palette.brand,
                    onTap: (item: Song) => {
                      playVisualSong(this.latestSongs(), index);
                    },
                    onMore: (item: Song) => {
                      this.showSongActions(item);
                    }
                  })
                }, (song: Song) => song.id)
              }
              .width('100%')

              if (libraryStore.allSongs.length > this.listLimit) {
                Text('展开更多')
                  .fontSize(11.5)
                  .fontColor(themeStore.palette.sub)
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 8, bottom: 4 })
                  .onClick(() => {
                    this.listLimit = Math.min(this.listLimit + 10, libraryStore.allSongs.length);
                  })
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)

          if (libraryStore.artists.length > 0) {
            Column({ space: 10 }) {
              SectionHeader({
                title: '歌手',
                subtitle: `${libraryStore.artists.length} 位`,
                actionText: '全部歌手',
                textColor: themeStore.palette.text,
                subColor: themeStore.palette.sub,
                actionColor: themeStore.palette.brand,
                onAction: () => {
                  this.onOpenDetail(LibraryDetailParam.create(LibraryKind.ARTIST, '全部歌手'));
                }
              })

              Scroll() {
                Row({ space: 12 }) {
                  ForEach(libraryStore.artists, (artist: Artist) => {
                    this.artistChip(artist)
                  }, (artist: Artist) => artist.id)
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

          Column({ space: 10 }) {
            SectionHeader({
              title: '我的歌单',
              subtitle: `${libraryStore.playlists.length} 个歌单`,
              actionText: '管理歌单',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              actionColor: themeStore.palette.brand,
              onAction: () => {
                this.onOpenDetail(LibraryDetailParam.create(LibraryKind.PLAYLIST, '歌单管理'));
              }
            })

            if (libraryStore.playlists.length === 0) {
              Text('服务器上还没有歌单，可在歌单管理中新建')
                .fontSize(11)
                .fontColor(themeStore.palette.sub)
                .width('100%')
                .padding({ top: 8, bottom: 8 })
            } else {
              Scroll() {
                Row({ space: 12 }) {
                  ForEach(libraryStore.playlists, (playlist: Playlist) => {
                    this.playlistCard(playlist)
                  }, (playlist: Playlist) => playlist.id)
                }
                .padding({ right: 8 })
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }

        Row() {
          Text(`共 ${libraryStore.serverSongs.length} 首服务器曲目与 ${libraryStore.localSongs.length} 首本地音乐`)
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
        }
        .padding({ top: 8, bottom: 24 })
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
}


