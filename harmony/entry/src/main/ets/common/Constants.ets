/**
 * 全局常量：品牌色、尺寸、网络超时、缓存键、路由名与播放参数。
 * 颜色与尺寸集中在此处与 Palette 中维护，避免 UI 层散落硬编码。
 */
export class AppConstants {
  static readonly APP_NAME: string = '柠檬音乐';
  static readonly APP_VERSION: string = '1.0.0';
  static readonly BUNDLE_NAME: string = 'com.lm.player.harmony';

  // 品牌色
  static readonly BRAND_RED: string = '#FA2D48';
  static readonly BRAND_RED_DIM: string = '#B82338';
  static readonly BRAND_AMBER: string = '#FFB44C';

  // 圆角
  static readonly RADIUS_SM: number = 12;
  static readonly RADIUS_MD: number = 16;
  static readonly RADIUS_LG: number = 20;
  static readonly RADIUS_XL: number = 28;

  // 间距
  static readonly PAGE_PADDING: number = 16;
  static readonly SECTION_GAP: number = 22;
  static readonly ROW_GAP: number = 10;

  // 布局
  static readonly MAX_CONTENT_WIDTH: number = 1180;
  static readonly HEADER_HEIGHT: number = 56;

  // 网络超时（毫秒）
  static readonly CONNECT_TIMEOUT_MS: number = 15000;
  static readonly READ_TIMEOUT_MS: number = 30000;
  static readonly LOGIN_TIMEOUT_MS: number = 20000;
  static readonly RSS_TIMEOUT_MS: number = 60000;
  static readonly COVER_TIMEOUT_MS: number = 30000;
  static readonly RESPONSE_MAX_BYTES: number = 12 * 1024 * 1024;

  // 缓存时效
  static readonly PLAY_URL_TTL_MS: number = 10 * 60 * 1000;
  static readonly DISCOVER_CACHE_TTL_MS: number = 5 * 60 * 1000;
  static readonly SYNC_MIN_INTERVAL_MS: number = 60 * 1000;

  // 同步
  static readonly SYNC_PAGE_SIZE: number = 200;
  static readonly SYNC_META_PAGE_SIZE: number = 500;
  static readonly SYNC_MAX_PAGES: number = 5000;

  // 封面缓存
  static readonly COVER_CACHE_DIR: string = 'covers';
  static readonly COVER_CACHE_MAX_FILES: number = 500;
  static readonly COVER_CONCURRENCY: number = 4;

  // 持久化
  static readonly PREF_STORE_NAME: string = 'lm_store';
  static readonly PREF_KEY_SETTINGS: string = 'lm_settings';
  static readonly PREF_KEY_SERVERS: string = 'lm_servers';
  static readonly PREF_KEY_SEARCH_HISTORY: string = 'lm_search_history';
  static readonly PREF_KEY_HOME_MODE: string = 'lm_home_mode';
  static readonly PREF_KEY_SESSION_PREFIX: string = 'lm_session_';
  static readonly FILE_LIBRARY: string = 'library.json';
  static readonly FILE_PLAYER: string = 'player.json';
  static readonly FILE_DOWNLOADS: string = 'downloads_cache.json';
  static readonly FILE_PODCASTS: string = 'podcasts_progress.json';
  static readonly FILE_LOCAL_INDEX: string = 'local_index.json';
  static readonly FILE_SERVER_PREFIX: string = 'server_';
  static readonly SCHEMA_VERSION: number = 2;
  static readonly LOCAL_INDEX_SCHEMA: number = 1;

  // 本地扫描
  static readonly LOCAL_AUDIO_EXTENSIONS: string[] = ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'opus', 'ape'];
  static readonly SCAN_CONCURRENCY: number = 3;
  static readonly SCAN_PROGRESS_INTERVAL_MS: number = 200;
  static readonly SCAN_MAX_DEPTH: number = 24;
  static readonly LOCAL_COVER_DIR: string = 'local_covers';
  static readonly LOCAL_TRACK_PREFIX: string = 'scan_';
  static readonly USER_FILE_PREFIX: string = 'file://';
  static readonly LOCAL_COVER_QUALITY: number = 70;
  static readonly LOCAL_COVER_MAX_EDGE: number = 512;

  // 路由名
  static readonly ROUTE_LIBRARY_DETAIL: string = 'LibraryDetail';
  static readonly ROUTE_DISCOVER_COLLECTION: string = 'DiscoverCollection';
  static readonly ROUTE_PODCAST_SHOW: string = 'PodcastShow';
  static readonly ROUTE_PODCAST_MANAGE: string = 'PodcastManage';
  static readonly ROUTE_SOURCE_MANAGE: string = 'SourceManage';
  static readonly ROUTE_TAG_EDITOR: string = 'TagEditor';

  // 资源前缀
  static readonly SANDBOX_PREFIX: string = 'sandbox:';
  static readonly HTTP_PREFIX: string = 'http';
  static readonly IMPORT_DIR: string = 'imported';

  // 播放
  static readonly STEP_15S: number = 15000;
  static readonly MAX_RECENT: number = 50;
  static readonly MAX_SEARCH_HISTORY: number = 10;
  static readonly REFRESH_LIMIT: number = 20;

  // 在线音源代码（服务端使用 kw/wy/tx/kg/mg）
  static readonly SOURCE_KUWO: string = 'kw';
  static readonly SOURCE_NETEASE: string = 'wy';
  static readonly SOURCE_QQ: string = 'tx';
  static readonly SOURCE_KUGOU: string = 'kg';
  static readonly SOURCE_MIGU: string = 'mg';
  static readonly DEFAULT_SOURCE: string = 'kw';

  // 服务端地址占位（不包含任何凭据）
  static readonly SERVER_URL_PLACEHOLDER: string = 'http://192.168.1.10:7983';
}

export class StorageKeys {
  static readonly FAVORITES: string = 'favoriteIds';
  static readonly RECENT: string = 'recentIds';
  static readonly PLAYLISTS: string = 'playlists';
}

/**
 * 底部 Dock 尺寸：默认态为「独立迷你播放器胶囊 + 独立页签栏」两层悬浮，
 * 上滑折叠态为「首页圆钮 + 紧凑播放器」单层胶囊。
 *
 * 结构（自底向上，默认态）：页签栏 64 + 间距 8 + 迷你播放器 60；底距 8。
 */
export class DockMetrics {
  /** 页签栏（Tabs 悬浮页签栏）高度。 */
  static readonly TAB_BAR_HEIGHT: number = 64;
  /** 独立迷你播放器胶囊高度。 */
  static readonly PLAYER_HEIGHT: number = 60;
  /** 迷你播放器与页签栏之间的间距。 */
  static readonly GAP: number = 8;
  /** 悬浮组件与屏幕底部（安全区之上）的距离。 */
  static readonly BOTTOM_MARGIN: number = 8;
  /** 折叠态紧凑条高度（首页圆钮与播放器胶囊同高）。 */
  static readonly COLLAPSED_HEIGHT: number = 60;
  /** 折叠态首页圆钮与播放器胶囊之间的间距。 */
  static readonly COLLAPSED_GAP: number = 10;
  /** 可滚动内容最后一项的呼吸空间。 */
  static readonly CONTENT_BREATHING: number = 8;

  /** 迷你播放器底部外边距：底距 + 页签栏 + 间距。 */
  static miniPlayerBottomOffset(): number {
    return DockMetrics.BOTTOM_MARGIN + DockMetrics.TAB_BAR_HEIGHT + DockMetrics.GAP;
  }

  /** 折叠胶囊底部外边距（安全区之上）。 */
  static collapsedBottomOffset(): number {
    return DockMetrics.BOTTOM_MARGIN;
  }

  /** 默认态（双层）内容底部留白：页签栏 + 底距 + 可选播放器 + 呼吸空间。 */
  static defaultInset(hasPlayer: boolean): number {
    const playerPart: number = hasPlayer ? DockMetrics.PLAYER_HEIGHT + DockMetrics.GAP : 0;
    return DockMetrics.TAB_BAR_HEIGHT + DockMetrics.BOTTOM_MARGIN + playerPart +
    DockMetrics.CONTENT_BREATHING;
  }

  /** 折叠态（紧凑胶囊）内容底部留白。 */
  static collapsedInset(): number {
    return DockMetrics.COLLAPSED_HEIGHT + DockMetrics.BOTTOM_MARGIN + DockMetrics.CONTENT_BREATHING;
  }

  /** 统一入口：按「是否有播放」「是否折叠」返回内容底部留白。 */
  static contentBottomInset(hasPlayer: boolean, collapsed: boolean = false): number {
    return collapsed ? DockMetrics.collapsedInset() : DockMetrics.defaultInset(hasPlayer);
  }
}

