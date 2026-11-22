/**
 * UI 侧模型：发现页条目、资源库入口、搜索范围与结果、路由参数、下拉选项。
 */
import { Album, Playlist, Song } from './MediaModels';

export enum LibraryKind {
  ALL = 'all',
  FAVORITES = 'favorites',
  DOWNLOADED = 'downloaded',
  RECENT = 'recent',
  ALBUM = 'album',
  ARTIST = 'artist',
  PLAYLIST = 'playlist',
  FOLDER = 'local'
}

export class LibraryDetailParam {
  kind: LibraryKind = LibraryKind.ALL;
  id: string = '';
  title: string = '全部歌曲';
  subtitle: string = '';
  platform: string = '';

  static create(kind: LibraryKind, title: string, id: string = ''): LibraryDetailParam {
    const param: LibraryDetailParam = new LibraryDetailParam();
    param.kind = kind;
    param.title = title;
    param.id = id;
    return param;
  }
}

export enum SearchScope {
  SONG = 'song',
  ALBUM = 'album',
  PLAYLIST = 'playlist'
}

@ObservedV2
export class SearchResult {
  @Trace scope: SearchScope = SearchScope.SONG;
  @Trace keyword: string = '';
  @Trace songs: Song[] = [];
  @Trace albums: Album[] = [];
  @Trace playlists: Playlist[] = [];

  get total(): number {
    return this.songs.length + this.albums.length + this.playlists.length;
  }

  get isEmpty(): boolean {
    return this.total === 0;
  }
}

export class SelectOptionItem {
  value: string = '';
  label: string = '';

  constructor(value: string, label: string) {
    this.value = value;
    this.label = label;
  }
}

export class LibraryEntry {
  title: string = '';
  subtitle: string = '';
  icon: Resource | null = null;
  kind: LibraryKind = LibraryKind.ALL;
  id: string = '';
  count: number = 0;
}

export class PodcastShowParam {
  showId: string = '';

  static create(showId: string): PodcastShowParam {
    const param: PodcastShowParam = new PodcastShowParam();
    param.showId = showId;
    return param;
  }
}

// ---------- 发现页 ----------

export class DiscoverToplistItem {
  id: string = '';
  name: string = '';
  coverUrl: string = '';
  updateTime: string = '';
  source: string = '';
  count: number = 0;
  seed: number = 0;
}

export class DiscoverTrackItem {
  id: string = '';
  name: string = '';
  subtitle: string = '';
  album: string = '';
  coverUrl: string = '';
  source: string = '';
  platformId: string = '';
  durationMs: number = 0;
  qualitys: string = '';
  seed: number = 0;
}

export enum DiscoverCollectionKind {
  TOPLIST = 'toplist',
  ALBUM = 'album',
  PLAYLIST = 'playlist',
  SEARCH_ALBUM = 'searchAlbum',
  SEARCH_PLAYLIST = 'searchPlaylist'
}

export class DiscoverCollectionParam {
  kind: DiscoverCollectionKind = DiscoverCollectionKind.TOPLIST;
  id: string = '';
  source: string = '';
  title: string = '';

  static create(kind: DiscoverCollectionKind, id: string, source: string, title: string): DiscoverCollectionParam {
    const param: DiscoverCollectionParam = new DiscoverCollectionParam();
    param.kind = kind;
    param.id = id;
    param.source = source;
    param.title = title;
    return param;
  }
}

export class TagEditorParam {
  songId: string = '';
  filePath: string = '';

  static create(songId: string, filePath: string): TagEditorParam {
    const param: TagEditorParam = new TagEditorParam();
    param.songId = songId;
    param.filePath = filePath;
    return param;
  }
}
