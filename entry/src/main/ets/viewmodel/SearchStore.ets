/**
 * 搜索 Store：本地/服务器已同步曲库即时过滤 + 全网在线结果（分页、请求序号、历史）。
 */
import { AppConstants } from '../common/Constants';
import { Debouncer, Utils } from '../common/Utils';
import { preferencesRepo } from '../data/PreferencesRepo';
import { Album, Playlist, Song } from '../model/MediaModels';
import { SearchResult, SearchScope } from '../model/UiModels';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { ListResult, serverApi } from '../service/ServerApi';
import { SearchService } from '../service/SearchService';
import { ServerSchemas } from '../data/ServerSchemas';
import { libraryStore } from './LibraryStore';
import { settingsStore } from './SettingsStore';
import { serverStore } from './ServerStore';

const KEY_HISTORY: string = AppConstants.PREF_KEY_SEARCH_HISTORY;
const HOT_KEYWORDS: string[] = ['周杰伦', '古风', '林俊杰', '轻音乐', '粤语', '旅行'];
const PAGE_SIZE: number = 20;

interface AlbumCardRaw {
  id?: string | number;
  name?: string;
  title?: string;
  artist?: string;
  singer?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  year?: number | string;
  songCount?: number | string;
}

interface PlaylistCardRaw {
  id?: string | number;
  name?: string;
  title?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  songCount?: number | string;
  count?: number | string;
  total?: number | string;
  author?: string;
}

@ObservedV2
export class SearchStore {
  @Trace keyword: string = '';
  @Trace scope: SearchScope = SearchScope.SONG;
  @Trace history: string[] = [];
  @Trace results: SearchResult = new SearchResult();
  @Trace loading: boolean = false;
  @Trace errorText: string = '';
  @Trace page: number = 1;
  @Trace hasMore: boolean = false;
  @Trace onlineCount: number = 0;

  private started: boolean = false;
  private debouncer: Debouncer = new Debouncer(320);
  private seq: number = 0;

  async init(): Promise<void> {
    if (this.started) {
      return;
    }
    this.started = true;
    const text: string = await preferencesRepo.getString(KEY_HISTORY, '');
    if (text.length > 0) {
      try {
        const parsed = JSON.parse(text) as string[];
        if (Array.isArray(parsed)) {
          const list: string[] = [];
          for (let i = 0; i < parsed.length; i++) {
            if (typeof parsed[i] === 'string' && parsed[i].length > 0) {
              list.push(parsed[i]);
            }
          }
          this.history = list.slice(0, AppConstants.MAX_SEARCH_HISTORY);
        }
      } catch (error) {
        this.history = [];
      }
    }
  }

  get hotKeywords(): string[] {
    return HOT_KEYWORDS;
  }

  get sourceLabel(): string {
    return ServerEndpoints.platformLabel(ServerEndpoints.platformCode(settingsStore.prefs.onlineSource));
  }

  setScope(scope: SearchScope): void {
    if (this.scope === scope) {
      return;
    }
    this.scope = scope;
    this.page = 1;
    this.results = new SearchResult();
    if (this.keyword.trim().length > 0) {
      this.runSearch(true);
    }
  }

  setKeyword(keyword: string): void {
    this.keyword = keyword;
    this.debouncer.run(() => {
      this.page = 1;
      this.runSearch(true);
    });
  }

  submit(keyword: string): void {
    this.keyword = keyword;
    this.debouncer.cancel();
    this.page = 1;
    this.runSearch(true);
    const trimmed: string = keyword.trim();
    if (trimmed.length > 0) {
      this.history = Utils.promote(this.history, trimmed, AppConstants.MAX_SEARCH_HISTORY);
      preferencesRepo.putString(KEY_HISTORY, JSON.stringify(this.history));
    }
  }

  loadMore(): void {
    if (this.loading || !this.hasMore) {
      return;
    }
    this.page = this.page + 1;
    this.runSearch(false);
  }

  private applyLocal(keyword: string): void {
    const localAlbums: Album[] = this.collectAlbums();
    const local: SearchResult = SearchService.search(keyword, this.scope, libraryStore.allSongs,
      localAlbums, libraryStore.playlists);
    this.results = local;
  }

  private collectAlbums(): Album[] {
    return libraryStore.albums;
  }

  private async runSearch(reset: boolean): Promise<void> {
    const keyword: string = this.keyword.trim();
    if (keyword.length === 0) {
      this.results = new SearchResult();
      this.errorText = '';
      this.hasMore = false;
      return;
    }
    this.applyLocal(keyword);
    if (!serverStore.canRead) {
      this.errorText = '';
      return;
    }
    const seq: number = Utils.nextSeq();
    this.seq = seq;
    this.loading = true;
    this.errorText = '';
    const source: string = ServerEndpoints.platformCode(settingsStore.prefs.onlineSource);
    const page: number = reset ? 1 : this.page;
    try {
      if (this.scope === SearchScope.SONG) {
        const response: ListResult = await serverApi.searchSongs(keyword, source, page, PAGE_SIZE);
        if (this.seq !== seq) {
          return;
        }
        if (!response.ok) {
          this.errorText = response.message;
          return;
        }
        this.appendSongs(response.items, reset, source);
        this.hasMore = response.items.length >= PAGE_SIZE;
      } else if (this.scope === SearchScope.ALBUM) {
        const response: ListResult = await serverApi.searchAlbums(keyword, source, page, PAGE_SIZE);
        if (this.seq !== seq) {
          return;
        }
        if (!response.ok) {
          this.errorText = response.message;
          return;
        }
        this.appendAlbums(response.items, reset, source);
        this.hasMore = response.items.length >= PAGE_SIZE;
      } else {
        const response: ListResult = await serverApi.searchPlaylists(keyword, source, page, PAGE_SIZE);
        if (this.seq !== seq) {
          return;
        }
        if (!response.ok) {
          this.errorText = response.message;
          return;
        }
        this.appendPlaylists(response.items, reset, source);
        this.hasMore = response.items.length >= PAGE_SIZE;
      }
    } finally {
      if (this.seq === seq) {
        this.loading = false;
      }
    }
  }

  private appendSongs(items: Object[], reset: boolean, source: string): void {
    const existing: Song[] = reset ? this.results.songs.slice() : this.results.songs.slice();
    const ids: Set<string> = new Set<string>();
    for (let i = 0; i < existing.length; i++) {
      ids.add(existing[i].id);
    }
    let added: number = 0;
    for (let i = 0; i < items.length; i++) {
      const song: Song = ServerSchemas.onlineSongFrom(items[i], source);
      if (!ids.has(song.id)) {
        ids.add(song.id);
        existing.push(song);
        added++;
      }
    }
    this.results.songs = existing;
    this.onlineCount = this.onlineCount + added;
    this.results.scope = this.scope;
  }

  private appendAlbums(items: Object[], reset: boolean, source: string): void {
    const list: Album[] = reset ? [] : this.results.albums.slice();
    for (let i = 0; i < items.length; i++) {
      const album: Album = albumCard(items[i], source);
      list.push(album);
    }
    this.results.albums = list;
    this.results.scope = this.scope;
  }

  private appendPlaylists(items: Object[], reset: boolean, source: string): void {
    const list: Playlist[] = reset ? [] : this.results.playlists.slice();
    for (let i = 0; i < items.length; i++) {
      list.push(playlistCard(items[i], source));
    }
    this.results.playlists = list;
    this.results.scope = this.scope;
  }

  clearHistory(): void {
    this.history = [];
    preferencesRepo.putString(KEY_HISTORY, JSON.stringify(this.history));
  }

  clearKeyword(): void {
    this.keyword = '';
    this.results = new SearchResult();
    this.errorText = '';
  }

  retry(): void {
    this.runSearch(true);
  }
}

function albumCard(obj: Object, source: string): Album {
  const raw: AlbumCardRaw = obj as AlbumCardRaw;
  const album: Album = new Album();
  const name: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '未知专辑'));
  album.title = name;
  album.artist = ServerSchemas.str(raw.artist, ServerSchemas.str(raw.singer, ''));
  album.platform = source;
  album.id = ServerSchemas.str(raw.id, Utils.stableId(name));
  album.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
    ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
  album.year = ServerSchemas.num(raw.year, 0);
  album.count = ServerSchemas.num(raw.songCount, 0);
  album.coverSeed = Utils.hashString(name) % 12;
  return album;
}

function playlistCard(obj: Object, source: string): Playlist {
  const raw: PlaylistCardRaw = obj as PlaylistCardRaw;
  const playlist: Playlist = new Playlist();
  const name: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '歌单'));
  playlist.name = name;
  playlist.platform = source;
  playlist.id = ServerSchemas.str(raw.id, Utils.stableId(name));
  playlist.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
    ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
  playlist.isCloud = true;
  playlist.editable = false;
  playlist.readOnly = true;
  playlist.coverSeed = Utils.hashString(name) % 12;
  playlist.remoteSnapshotJson = `${ServerSchemas.num(raw.songCount, ServerSchemas.num(raw.count, ServerSchemas.num(raw.total, 0)))}`;
  return playlist;
}

export const searchStore: SearchStore = new SearchStore();
