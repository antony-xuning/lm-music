/**
 * 播放地址解析：优先调用 POST /api/play/url 换取带票据地址（约 10 分钟有效），
 * 服务器本地文件失败时回退 /api/play/local 并使用带 Authorization 的媒体源。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { MediaSource, PlayableItem } from '../model/MediaModels';
import { PlayResult } from '../model/ServerModels';
import { ObjectResult, serverApi } from './ServerApi';
import { serverContext } from './ServerContext';

const SCOPE: string = 'PlayUrlResolver';

class LocalPlayBody {
  source: string = 'local';
  filePath: string = '';
  trackId: string = '';
  quality: string = '';
  type: string = 'audio';

  constructor(filePath: string, trackId: string, quality: string) {
    this.filePath = filePath;
    this.trackId = trackId;
    this.quality = quality;
  }
}

class OnlinePlayBody {
  source: string = '';
  songId: string = '';
  songmid: string = '';
  hash: string = '';
  copyrightId: string = '';
  musicId: string = '';
  quality: string = '';
  type: string = 'audio';

  constructor(item: PlayableItem, quality: string) {
    this.source = item.platform;
    this.songId = item.platformSongId;
    this.songmid = item.platformSongId;
    this.hash = item.platformSongId;
    this.copyrightId = item.platformSongId;
    this.musicId = item.platformSongId;
    this.quality = quality;
  }
}

class LyricBody {
  source: string = '';
  filePath: string = '';
  trackId: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  interval: string = '';
  songId: string = '';
  songmid: string = '';
  hash: string = '';
  copyrightId: string = '';
  quality: string = '';

  constructor(item: PlayableItem, quality: string) {
    this.source = item.mediaSource === MediaSource.SERVER_FILE ? 'local' : item.platform;
    this.filePath = item.filePath;
    this.trackId = item.trackId;
    this.name = item.title;
    this.singer = item.subtitle;
    this.interval = `${Math.floor(item.durationMs / 1000)}`;
    this.songId = item.platformSongId;
    this.songmid = item.platformSongId;
    this.hash = item.platformSongId;
    this.copyrightId = item.platformSongId;
    this.quality = quality;
  }
}

interface PlayUrlRaw {
  ok?: boolean;
  url?: string;
  playUrl?: string;
  local?: boolean;
  format?: string;
  error?: string;
  message?: string;
  data?: Object;
}

class CacheEntry {
  url: string = '';
  format: string = '';
  useAuthHeader: boolean = false;
  expiresAt: number = 0;
}

class PlayUrlResolverImpl {
  private cache: Map<string, CacheEntry> = new Map<string, CacheEntry>();

  static lyricBody(item: PlayableItem, quality: string): string {
    return JSON.stringify(new LyricBody(item, quality));
  }

  /** 供 LyricService 组装 /api/play/lyric 请求体。 */
  bodyForLyric(item: PlayableItem, quality: string): string {
    return JSON.stringify(new LyricBody(item, quality));
  }

  private cacheKey(item: PlayableItem, quality: string): string {
    return `${serverContext.serverId}|${item.mediaSource}|${item.platform}|${item.filePath}|${item.platformSongId}|${quality}`;
  }

  async resolve(item: PlayableItem, quality: string): Promise<PlayResult> {
    const result: PlayResult = new PlayResult();
    if (item.mediaSource === MediaSource.LOCAL) {
      result.url = item.audioRef;
      result.local = true;
      return result;
    }
    if (item.mediaSource === MediaSource.PODCAST) {
      result.url = item.audioRef;
      return result;
    }
    const key: string = this.cacheKey(item, quality);
    const cached: CacheEntry | undefined = this.cache.get(key);
    if (cached !== undefined && cached.expiresAt > Date.now()) {
      result.url = cached.url;
      result.format = cached.format;
      result.useAuthHeader = cached.useAuthHeader;
      return result;
    }
    const body: string = item.mediaSource === MediaSource.SERVER_FILE
      ? JSON.stringify(new LocalPlayBody(item.filePath, item.trackId, quality))
      : JSON.stringify(new OnlinePlayBody(item, quality));
    const response: ObjectResult = await serverApi.playUrl(body);
    if (response.ok && response.value !== null) {
      const resolved: PlayResult | null = parsePlayUrl(response.value);
      if (resolved !== null) {
        resolved.url = ServerEndpoints.absolute(serverContext.baseUrl, resolved.url);
        if (resolved.url.length > 0) {
          result.url = resolved.url;
          result.format = resolved.format;
          result.local = resolved.local;
          this.store(key, result);
          return result;
        }
      }
    }
    Logger.warn(SCOPE, `play/url failed: ${response.code}`);
    if (item.mediaSource === MediaSource.SERVER_FILE) {
      result.url = serverApi.playLocalUrl(item.filePath);
      result.useAuthHeader = true;
      result.local = true;
      return result;
    }
    result.url = '';
    return result;
  }

  private store(key: string, result: PlayResult): void {
    const entry: CacheEntry = new CacheEntry();
    entry.url = result.url;
    entry.format = result.format;
    entry.useAuthHeader = result.useAuthHeader;
    entry.expiresAt = Date.now() + AppConstants.PLAY_URL_TTL_MS;
    this.cache.set(key, entry);
  }

  invalidate(item: PlayableItem, quality: string): void {
    this.cache.delete(this.cacheKey(item, quality));
  }

  clear(): void {
    this.cache.clear();
  }
}

function parsePlayUrl(root: Object): PlayResult | null {
  const env: PlayUrlRaw = root as PlayUrlRaw;
  let source: PlayUrlRaw = env;
  const data: Object | undefined = env.data;
  if (data !== undefined && !Array.isArray(data)) {
    source = data as PlayUrlRaw;
  }
  let url: string = typeof source.url === 'string' ? source.url : '';
  if (url.length === 0 && typeof source.playUrl === 'string') {
    url = source.playUrl;
  }
  if (url.length === 0 && typeof env.url === 'string') {
    url = env.url;
  }
  if (url.length === 0) {
    return null;
  }
  const result: PlayResult = new PlayResult();
  result.url = url;
  result.format = typeof source.format === 'string' ? source.format
    : (typeof env.format === 'string' ? env.format : '');
  result.local = source.local === true || env.local === true;
  return result;
}

export const playUrlResolver: PlayUrlResolverImpl = new PlayUrlResolverImpl();
