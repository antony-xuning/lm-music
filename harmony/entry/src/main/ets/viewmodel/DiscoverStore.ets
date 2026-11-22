/**
 * 发现页 Store：按音源缓存 5 分钟的榜单/新歌/新碟/推荐歌单，分区块维护 loading/error。
 */
import { AppConstants } from '../common/Constants';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { Album, Playlist, Song } from '../model/MediaModels';
import { DiscoverToplistItem } from '../model/UiModels';
import {
  AlbumPayload,
  DiscoverService,
  PlaylistPayload,
  SongPayload,
  ToplistPayload
} from '../service/DiscoverService';
import { settingsStore } from './SettingsStore';
import { serverStore } from './ServerStore';

const BLOCK_IDLE: string = 'idle';
const BLOCK_LOADING: string = 'loading';
const BLOCK_OK: string = 'ok';
const BLOCK_ERROR: string = 'error';

class DiscoverCache {
  toplists: DiscoverToplistItem[] = [];
  newSongs: Song[] = [];
  newAlbums: Album[] = [];
  recommend: Playlist[] = [];
  loadedAt: number = 0;
}

@ObservedV2
export class DiscoverStore {
  @Trace source: string = AppConstants.DEFAULT_SOURCE;
  @Trace toplists: DiscoverToplistItem[] = [];
  @Trace newSongs: Song[] = [];
  @Trace newAlbums: Album[] = [];
  @Trace recommend: Playlist[] = [];
  @Trace topState: string = BLOCK_IDLE;
  @Trace newSongsState: string = BLOCK_IDLE;
  @Trace newAlbumsState: string = BLOCK_IDLE;
  @Trace recommendState: string = BLOCK_IDLE;
  @Trace topError: string = '';
  @Trace newSongsError: string = '';
  @Trace newAlbumsError: string = '';
  @Trace recommendError: string = '';
  @Trace refreshing: boolean = false;
  @Trace lastLoadedAt: number = 0;

  private started: boolean = false;
  private caches: Map<string, DiscoverCache> = new Map<string, DiscoverCache>();

  init(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.source = ServerEndpoints.platformCode(settingsStore.prefs.onlineSource);
    this.load(false);
  }

  get sourceLabel(): string {
    return ServerEndpoints.platformLabel(this.source);
  }

  setSource(source: string): void {
    if (this.source === source) {
      return;
    }
    this.source = source;
    const cached: DiscoverCache | undefined = this.caches.get(source);
    if (cached !== undefined) {
      this.applyCache(cached);
    } else {
      this.topState = BLOCK_IDLE;
      this.newSongsState = BLOCK_IDLE;
      this.newAlbumsState = BLOCK_IDLE;
      this.recommendState = BLOCK_IDLE;
      this.load(false);
    }
  }

  private applyCache(cache: DiscoverCache): void {
    this.toplists = cache.toplists;
    this.newSongs = cache.newSongs;
    this.newAlbums = cache.newAlbums;
    this.recommend = cache.recommend;
    this.lastLoadedAt = cache.loadedAt;
    this.topState = cache.toplists.length > 0 ? BLOCK_OK : BLOCK_ERROR;
    this.newSongsState = cache.newSongs.length > 0 ? BLOCK_OK : BLOCK_ERROR;
    this.newAlbumsState = cache.newAlbums.length > 0 ? BLOCK_OK : BLOCK_ERROR;
    this.recommendState = cache.recommend.length > 0 ? BLOCK_OK : BLOCK_ERROR;
  }

  async load(force: boolean): Promise<void> {
    if (!serverStore.canRead) {
      this.topState = BLOCK_ERROR;
      this.newSongsState = BLOCK_ERROR;
      this.newAlbumsState = BLOCK_ERROR;
      this.recommendState = BLOCK_ERROR;
      this.topError = '尚未连接柠檬音乐服务器';
      this.newSongsError = this.topError;
      this.newAlbumsError = this.topError;
      this.recommendError = this.topError;
      return;
    }
    const cached: DiscoverCache | undefined = this.caches.get(this.source);
    if (!force && cached !== undefined && Date.now() - cached.loadedAt < AppConstants.DISCOVER_CACHE_TTL_MS) {
      this.applyCache(cached);
      return;
    }
    this.refreshing = true;
    const cache: DiscoverCache = new DiscoverCache();
    await Promise.all([
      this.loadToplists(cache),
      this.loadNewSongs(cache),
      this.loadNewAlbums(cache),
      this.loadRecommend(cache)
    ]);
    cache.loadedAt = Date.now();
    this.caches.set(this.source, cache);
    this.lastLoadedAt = cache.loadedAt;
    this.refreshing = false;
  }

  private async loadToplists(cache: DiscoverCache): Promise<void> {
    this.topState = BLOCK_LOADING;
    const payload: ToplistPayload = await DiscoverService.toplists(this.source);
    if (payload.ok) {
      cache.toplists = payload.items;
      this.toplists = payload.items;
      this.topState = BLOCK_OK;
      this.topError = '';
    } else {
      this.topState = BLOCK_ERROR;
      this.topError = payload.error;
    }
  }

  private async loadNewSongs(cache: DiscoverCache): Promise<void> {
    this.newSongsState = BLOCK_LOADING;
    const payload: SongPayload = await DiscoverService.newSongs(this.source, 20);
    if (payload.ok) {
      cache.newSongs = payload.items;
      this.newSongs = payload.items;
      this.newSongsState = BLOCK_OK;
      this.newSongsError = '';
    } else {
      this.newSongsState = BLOCK_ERROR;
      this.newSongsError = payload.error;
    }
  }

  private async loadNewAlbums(cache: DiscoverCache): Promise<void> {
    this.newAlbumsState = BLOCK_LOADING;
    const payload: AlbumPayload = await DiscoverService.newAlbums(this.source, 12);
    if (payload.ok) {
      cache.newAlbums = payload.items;
      this.newAlbums = payload.items;
      this.newAlbumsState = BLOCK_OK;
      this.newAlbumsError = '';
    } else {
      this.newAlbumsState = BLOCK_ERROR;
      this.newAlbumsError = payload.error;
    }
  }

  private async loadRecommend(cache: DiscoverCache): Promise<void> {
    this.recommendState = BLOCK_LOADING;
    const payload: PlaylistPayload = await DiscoverService.recommendPlaylists(this.source, 1, 10);
    if (payload.ok) {
      cache.recommend = payload.items;
      this.recommend = payload.items;
      this.recommendState = BLOCK_OK;
      this.recommendError = '';
    } else {
      this.recommendState = BLOCK_ERROR;
      this.recommendError = payload.error;
    }
  }

  async refresh(): Promise<void> {
    this.caches.delete(this.source);
    await this.load(true);
  }

  /** 服务器已可用但上次加载失败（如登录前触发）时自动重试。 */
  reloadIfStale(): void {
    if (!serverStore.canRead) {
      return;
    }
    if (this.topState === BLOCK_ERROR || this.topState === BLOCK_IDLE) {
      this.load(false);
    }
  }

  async retryBlock(block: string): Promise<void> {
    const cache: DiscoverCache | undefined = this.caches.get(this.source);
    const target: DiscoverCache = cache !== undefined ? cache : new DiscoverCache();
    if (block === 'toplists') {
      await this.loadToplists(target);
    } else if (block === 'newSongs') {
      await this.loadNewSongs(target);
    } else if (block === 'newAlbums') {
      await this.loadNewAlbums(target);
    } else {
      await this.loadRecommend(target);
    }
    target.loadedAt = Date.now();
    this.caches.set(this.source, target);
  }

  static get IDLE(): string {
    return BLOCK_IDLE;
  }

  static get LOADING(): string {
    return BLOCK_LOADING;
  }

  static get OK(): string {
    return BLOCK_OK;
  }

  static get ERROR(): string {
    return BLOCK_ERROR;
  }
}

export const discoverStore: DiscoverStore = new DiscoverStore();
