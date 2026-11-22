/**
 * 服务端接口路径、URL 构造、查询编码与音质/音源映射。
 * 只做纯字符串处理，不发起网络请求。
 */
export class QueryPair {
  key: string;
  value: string;

  constructor(key: string, value: string) {
    this.key = key;
    this.value = value;
  }
}

export class ServerEndpoints {
  // 鉴权
  static readonly HEALTH: string = '/api/health';
  static readonly LOGIN: string = '/api/auth/login';
  static readonly ME: string = '/api/auth/me';

  // 曲库
  static readonly TRACKS: string = '/api/library/tracks';
  static readonly ALBUMS: string = '/api/library/albums';
  static readonly ARTISTS: string = '/api/library/artists';
  static readonly PLAYLISTS: string = '/api/library/playlists';
  static readonly USER_DATA: string = '/api/library/user-data';

  // 播放与标签
  static readonly PLAY_URL: string = '/api/play/url';
  static readonly PLAY_LOCAL: string = '/api/play/local';
  static readonly PLAY_LYRIC: string = '/api/play/lyric';
  static readonly TAG_READ: string = '/api/tag/read';
  static readonly TAG_MATCH: string = '/api/tag/match';
  static readonly TAG_MATCH_APPLY: string = '/api/tag/match-apply';
  static readonly TAG_WRITE: string = '/api/tag/write';
  static readonly TAG_COVER: string = '/api/tag/cover';

  // 发现
  static readonly DISCOVER_TOPLISTS: string = '/api/discover/toplists';
  static readonly DISCOVER_TOPLIST: string = '/api/discover/toplist';
  static readonly DISCOVER_NEW_SONGS: string = '/api/discover/new-songs';
  static readonly DISCOVER_NEW_ALBUMS: string = '/api/discover/new-albums';
  static readonly PLAYLIST_RECOMMEND: string = '/api/playlist/recommend';
  static readonly PLAYLIST_DETAIL: string = '/api/playlist';
  static readonly ALBUM_DETAIL: string = '/api/album';

  // 搜索
  static readonly SEARCH: string = '/api/search';
  static readonly SEARCH_ALBUM: string = '/api/search/album';
  static readonly SEARCH_PLAYLIST: string = '/api/search/playlist';

  // 下载
  static readonly DOWNLOAD_LIST: string = '/api/download/list';
  static readonly DOWNLOAD_ADD: string = '/api/download/add';
  static readonly DOWNLOAD_CLEAR_COMPLETED: string = '/api/download/clear-completed';

  // 播客
  static readonly PODCASTS: string = '/api/podcasts';

  // 音源
  static readonly SOURCE_LIST: string = '/api/source/list';
  static readonly SOURCE_ACTIVATE: string = '/api/source/activate';
  static readonly SOURCE_DEACTIVATE: string = '/api/source/deactivate';
  static readonly SOURCE_IMPORT_URL: string = '/api/source/import-url';
  static readonly SOURCE_IMPORT: string = '/api/source/import';

  static downloadAction(id: string, action: string): string {
    return `/api/download/${encodeURIComponent(id)}/${action}`;
  }

  static downloadDismiss(id: string): string {
    return `/api/download/${encodeURIComponent(id)}/dismiss`;
  }

  static podcastEpisodes(id: string): string {
    return `/api/podcasts/${encodeURIComponent(id)}/episodes`;
  }

  static podcastRefresh(id: string): string {
    return `/api/podcasts/${encodeURIComponent(id)}/refresh`;
  }

  static podcastDelete(id: string): string {
    return `/api/podcasts/${encodeURIComponent(id)}`;
  }

  static sourcePlatform(id: string): string {
    return `/api/source/${encodeURIComponent(id)}/platform`;
  }

  /** 规范化基础地址：去尾部斜杠。 */
  static normalizeBase(raw: string): string {
    let base: string = raw.trim();
    while (base.length > 0 && base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return base;
  }

  /** 校验基础地址：仅允许 http/https，且不含空白。 */
  static validateBase(raw: string): string {
    const base: string = ServerEndpoints.normalizeBase(raw);
    if (base.length === 0) {
      return '服务器地址不能为空';
    }
    if (base.indexOf(' ') >= 0) {
      return '服务器地址不能包含空格';
    }
    const lower: string = base.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      return '服务器地址需以 http:// 或 https:// 开头';
    }
    const hostStart: number = lower.indexOf('://') + 3;
    if (hostStart >= base.length - 1) {
      return '服务器地址缺少主机名';
    }
    return '';
  }

  static join(base: string, path: string): string {
    const normalized: string = ServerEndpoints.normalizeBase(base);
    if (path.startsWith('/')) {
      return `${normalized}${path}`;
    }
    return `${normalized}/${path}`;
  }

  static buildQuery(pairs: QueryPair[]): string {
    if (pairs.length === 0) {
      return '';
    }
    let query: string = '';
    for (let i = 0; i < pairs.length; i++) {
      const pair: QueryPair = pairs[i];
      query += `${i === 0 ? '?' : '&'}${encodeURIComponent(pair.key)}=${encodeURIComponent(pair.value)}`;
    }
    return query;
  }

  /** 相对地址补全为绝对地址。 */
  static absolute(base: string, urlOrPath: string): string {
    const value: string = urlOrPath.trim();
    if (value.length === 0) {
      return '';
    }
    const lower: string = value.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('//')) {
      return `http:${value}`;
    }
    if (value.startsWith('/')) {
      return ServerEndpoints.join(base, value);
    }
    return `${ServerEndpoints.normalizeBase(base)}/${value}`;
  }

  /** 音质偏好映射为服务端音质键。 */
  static qualityKey(level: string): string {
    if (level === 'standard') {
      return '128k';
    }
    if (level === 'high') {
      return '320k';
    }
    if (level === 'hires') {
      return 'flac24bit';
    }
    return 'flac';
  }

  /** 在线音源枚举值（kuwo/netease/…）映射为服务端代码（kw/wy/…）。 */
  static platformCode(onlineSource: string): string {
    if (onlineSource === 'netease') {
      return 'wy';
    }
    if (onlineSource === 'qq') {
      return 'tx';
    }
    if (onlineSource === 'kugou') {
      return 'kg';
    }
    if (onlineSource === 'migu') {
      return 'mg';
    }
    return 'kw';
  }

  static platformLabel(code: string): string {
    if (code === 'wy' || code === 'netease') {
      return '网易云';
    }
    if (code === 'tx' || code === 'qq') {
      return 'QQ';
    }
    if (code === 'kg' || code === 'kugou') {
      return '酷狗';
    }
    if (code === 'mg' || code === 'migu') {
      return '咪咕';
    }
    return '酷我';
  }

  static allPlatforms(): string[] {
    return ['kw', 'wy', 'tx', 'kg', 'mg'];
  }
}
