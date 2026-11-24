/**
 * 全网搜索覆盖层：范围切换、历史与热门、在线+本地结果、试听、收藏、加入歌单与下钻。
 */
import { Artwork } from '../components/Artwork';
import { BadgeView } from '../components/Badge';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SongRow } from '../components/SongRow';
import { Album, Playlist, Song } from '../model/MediaModels';
import { DiscoverCollectionKind, DiscoverCollectionParam, SearchScope } from '../model/UiModels';
import { playlistCardCount } from '../service/DiscoverService';
import { playVisualSong, queueSong } from '../service/PlaybackLauncher';
import { DownloadOpResult } from '../service/ServerDownloadService';
import { SearchService } from '../service/SearchService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { downloadStore } from '../viewmodel/DownloadStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { searchStore } from '../viewmodel/SearchStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

@ComponentV2
export struct SearchView {
  @Param onOpenCollection: (param: DiscoverCollectionParam) => void = () => {
  };
  @Local favoriteBusyId: string = '';

  private async toggleFavorite(song: Song): Promise<void> {
    if (this.favoriteBusyId.length > 0) {
      return;
    }
    this.favoriteBusyId = song.id;
    try {
      const outcome = await libraryStore.toggleFavoriteFor(song);
      ConfirmDialog.toast(this.getUIContext(), outcome.message);
    } finally {
      this.favoriteBusyId = '';
    }
  }

  private openAlbum(album: Album): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.SEARCH_ALBUM,
      album.id, album.platform, album.title));
  }

  private openPlaylist(playlist: Playlist): void {
    this.onOpenCollection(DiscoverCollectionParam.create(DiscoverCollectionKind.SEARCH_PLAYLIST,
      playlist.id, playlist.platform, playlist.name));
  }

  private showSongActions(song: Song): void {
    const actions: string[] = ['立即播放', '加入试听列表', '收藏 / 取消收藏', '加入歌单', '下载'];
    ConfirmDialog.actionSheet(this.getUIContext(), song.title, actions).then((index: number) => {
      if (index === 0) {
        playVisualSong([song], 0);
      } else if (index === 1) {
        queueSong(song);
        ConfirmDialog.toast(this.getUIContext(), '已加入试听列表');
      } else if (index === 2) {
        this.toggleFavorite(song);
      } else if (index === 3) {
        overlayStore.openAddToPlaylist([song.id]);
      } else if (index === 4) {
        downloadStore.addFromSong(song, settingsStore.prefs.defaultQuality)
          .then((result: DownloadOpResult) => {
            ConfirmDialog.toast(this.getUIContext(), result.message);
          });
      }
    });
  }

  @Builder
  scopeChip(scope: SearchScope) {
    Text(SearchService.scopeLabel(scope))
      .fontSize(11)
      .fontColor(searchStore.scope === scope ? '#FFFFFF' : themeStore.palette.sub)
      .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .borderRadius(13)
      .backgroundColor(searchStore.scope === scope ? themeStore.palette.brand : '#1F1F26')
      .stateStyles({
        pressed: { .scale({ x: 0.92, y: 0.92 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        searchStore.setScope(scope);
      })
  }

  @Builder
  keywordChip(keyword: string) {
    Text(keyword)
      .fontSize(11)
      .fontColor(themeStore.palette.text)
      .padding({ left: 11, right: 11, top: 6, bottom: 6 })
      .borderRadius(13)
      .backgroundColor('#1F1F26')
      .stateStyles({
        pressed: { .scale({ x: 0.92, y: 0.92 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        searchStore.submit(keyword);
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
        showInitial: false,
        remoteUrl: album.coverUrl
      })
      Column({ space: 3 }) {
        Text(album.title)
          .fontSize(13)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${album.artist}${album.count > 0 ? ' · ' + album.count + ' 首' : ''}`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      BadgeView({ text: album.platform.toUpperCase(), tone: 'glass' })
      Image($r('app.media.ic_next'))
        .width(14)
        .height(14)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      this.openAlbum(album);
    })
  }

  @Builder
  playlistRow(playlist: Playlist) {
    Row({ space: 10 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 44,
        radius: 12,
        title: playlist.name,
        showInitial: false,
        remoteUrl: playlist.coverUrl
      })
      Column({ space: 3 }) {
        Text(playlist.name)
          .fontSize(13)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${playlistCardCount(playlist)} 首`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      BadgeView({ text: playlist.platform.toUpperCase(), tone: 'glass' })
      Image($r('app.media.ic_next'))
        .width(14)
        .height(14)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      this.openPlaylist(playlist);
    })
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Row({ space: 6 }) {
        Image($r('app.media.ic_search'))
          .width(15)
          .height(15)
          .fillColor(themeStore.palette.sub)
        TextInput({ text: searchStore.keyword, placeholder: '搜索歌曲、专辑与歌单' })
          .fontSize(12.5)
          .fontColor(themeStore.palette.text)
          .placeholderColor(themeStore.palette.sub)
          .backgroundColor(Color.Transparent)
          .height(38)
          .layoutWeight(1)
          .defaultFocus(true)
          .onChange((value: string) => {
            searchStore.setKeyword(value);
          })
          .onSubmit(() => {
            searchStore.submit(searchStore.keyword);
          })
      }
      .padding({ left: 12, right: 8 })
      .borderRadius(16)
      .backgroundColor(themeStore.palette.controlBg)
      .layoutWeight(1)

      Text('取消')
        .fontSize(12)
        .fontColor(themeStore.palette.sub)
        .onClick(() => {
          overlayStore.closeSearch();
        })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  idleState() {
    Column({ space: 14 }) {
      if (searchStore.history.length > 0) {
        Column({ space: 8 }) {
          Row() {
            Text('历史搜索')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(themeStore.palette.text)
            Blank()
            Text('清空')
              .fontSize(10.5)
              .fontColor(themeStore.palette.sub)
              .onClick(() => {
                searchStore.clearHistory();
              })
          }
          .width('100%')

          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(searchStore.history, (keyword: string) => {
              Column() {
                this.keywordChip(keyword)
              }
              .margin({ right: 8, bottom: 8 })
            }, (keyword: string) => keyword)
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }

      Column({ space: 8 }) {
        Text('热门搜索')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(themeStore.palette.text)
          .width('100%')
          .textAlign(TextAlign.Start)

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(searchStore.hotKeywords, (keyword: string) => {
            Column() {
              this.keywordChip(keyword)
            }
            .margin({ right: 8, bottom: 8 })
          }, (keyword: string) => keyword)
        }
        .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  resultsView() {
    Scroll() {
      Column({ space: 10 }) {
        if (searchStore.errorText.length > 0) {
          EmptyState({
            title: '搜索失败',
            description: searchStore.errorText,
            actionText: '重试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              searchStore.retry();
            }
          })
        } else if (searchStore.loading && searchStore.results.isEmpty) {
          EmptyState({ loading: true, title: '正在搜索' })
        } else if (searchStore.results.isEmpty && !searchStore.loading) {
          EmptyState({
            title: '没有找到相关内容',
            description: '换个关键词或切换搜索范围试试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand
          })
        }

        if (searchStore.scope === SearchScope.SONG && searchStore.results.songs.length > 0) {
          Row() {
            Text(`歌曲 · ${searchStore.results.songs.length}`)
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
            Blank()
            Text('全部播放')
              .fontSize(10.5)
              .fontColor(themeStore.palette.brand)
              .onClick(() => {
                playVisualSong(searchStore.results.songs, 0);
              })
          }
          .width('100%')

          List() {
            // Repeat 虚拟滚动：搜索结果可通过"加载更多"持续增长，仅渲染可视区+预加载区。
            Repeat<Song>(searchStore.results.songs)
              .key((song: Song) => song.id)
              .each((ri: RepeatItem<Song>) => {
                ListItem() {
                  SongRow({
                    ri: ri,
                    textColor: themeStore.palette.text,
                    subColor: themeStore.palette.sub,
                    accent: themeStore.palette.brand,
                    onTap: (item: Song) => {
                      playVisualSong(searchStore.results.songs, ri.index);
                    },
                    onMore: (item: Song) => {
                      this.showSongActions(item);
                    }
                  })
                }
              })
              .virtualScroll()
          }
          .width('100%')
          .constraintSize({ maxHeight: 640 })
          .padding({ left: 8, right: 8 })
          .borderRadius(16)
          .backgroundColor(themeStore.palette.card)
          .scrollBar(BarState.Off)
          .cachedCount(8)
          // 内层列表位于外层 Scroll 中：先滚内层到底，再交给外层继续滚动。
          .nestedScroll({
            scrollForward: NestedScrollMode.SELF_FIRST,
            scrollBackward: NestedScrollMode.SELF_FIRST
          })
        }

        if (searchStore.scope === SearchScope.ALBUM && searchStore.results.albums.length > 0) {
          Text(`专辑 · ${searchStore.results.albums.length}`)
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .width('100%')
          Column() {
            ForEach(searchStore.results.albums, (album: Album) => {
              this.albumRow(album)
            }, (album: Album) => `${album.platform}_${album.id}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .borderRadius(16)
          .backgroundColor(themeStore.palette.card)
        }

        if (searchStore.scope === SearchScope.PLAYLIST && searchStore.results.playlists.length > 0) {
          Text(`歌单 · ${searchStore.results.playlists.length}`)
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .width('100%')
          Column() {
            ForEach(searchStore.results.playlists, (playlist: Playlist) => {
              this.playlistRow(playlist)
            }, (playlist: Playlist) => `${playlist.platform}_${playlist.id}`)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
          .borderRadius(16)
          .backgroundColor(themeStore.palette.card)
        }

        if (searchStore.hasMore) {
          Text(searchStore.loading ? '加载中…' : '加载更多')
            .fontSize(11.5)
            .fontColor(themeStore.palette.brand)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 12, bottom: 12 })
            .onClick(() => {
              searchStore.loadMore();
            })
        }

        Row({ space: 6 }) {
          BadgeView({ text: `${searchStore.results.total} 条结果`, tone: 'glass' })
          BadgeView({ text: searchStore.sourceLabel, tone: 'brand' })
          if (!serverStore.canRead) {
            BadgeView({ text: '仅本地曲库', tone: 'warn' })
          }
        }
        .width('100%')
        .padding({ top: 6, bottom: 30 })
      }
      .width('100%')
      .padding({ bottom: 24 })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  build() {
    Column({ space: 12 }) {
      this.header()

      Row({ space: 8 }) {
        ForEach(SearchService.scopes(), (scope: SearchScope) => {
          this.scopeChip(scope)
        }, (scope: SearchScope) => scope)
        Blank()
      }
      .width('100%')

      if (searchStore.keyword.trim().length === 0) {
        Scroll() {
          Column() {
            this.idleState()
          }
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      } else {
        this.resultsView()
      }
    }
    .width('100%')
    .height('100%')
    .padding({
      left: layoutStore.gutter,
      right: layoutStore.gutter,
      top: 14,
      bottom: 10
    })
    .backgroundColor(themeStore.palette.bg)
    .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
  }
}
