/**
 * 服务端领域模型：会话、连接状态、在线来源、曲库实体、写回条目、同步状态、
 * 服务器下载任务、播客、音源脚本与标签快照。
 * 仅存放数据结构与轻量工具方法，不发起网络请求。
 */

/** 连接状态机：idle → connecting → online / offline / authExpired / error。 */
export enum ConnectionState {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  ONLINE = 'online',
  OFFLINE = 'offline',
  AUTH_EXPIRED = 'authExpired',
  ERROR = 'error'
}

export class ConnectionStatus {
  state: ConnectionState = ConnectionState.IDLE;
  latencyMs: number = 0;
  errorCode: string = '';
  errorMessage: string = '';
  lastConnectedAt: number = 0;
}

export class ServerSession {
  token: string = '';
  expiresAt: number = 0;
  userId: string = '';
  username: string = '';
  displayName: string = '';
  role: string = '';
  lastVerifiedAt: number = 0;

  get valid(): boolean {
    return this.token.length > 0 && (this.expiresAt <= 0 || this.expiresAt > Date.now());
  }
}

/** 在线来源条目（歌单中的 wy:/kw: 条目或搜索结果）。 */
export class OnlineRef {
  platform: string = '';
  songId: string = '';
  songmid: string = '';
  hash: string = '';
  copyrightId: string = '';
  musicId: string = '';
  rid: string = '';
  picUrl: string = '';
  lyric: string = '';
  qualitys: string[] = [];

  /** 用于构造 play/url 请求体的平台主键。 */
  platformKey(): string {
    if (this.songId.length > 0) {
      return this.songId;
    }
    if (this.songmid.length > 0) {
      return this.songmid;
    }
    if (this.hash.length > 0) {
      return this.hash;
    }
    if (this.copyrightId.length > 0) {
      return this.copyrightId;
    }
    return this.musicId;
  }
}

/** 服务器文件曲目快照（同步中间态；LibraryStore 会转成 Song）。 */
export class ServerTrack {
  id: string = '';
  filePath: string = '';
  trackId: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  albumArtist: string = '';
  year: number = 0;
  genre: string = '';
  durationMs: number = 0;
  format: string = '';
  sizeBytes: number = 0;
  sampleRate: number = 0;
  bitDepth: number = 0;
  mtime: number = 0;
  hasPicture: boolean = false;
  hasLyric: boolean = false;
  addedAt: number = 0;
}

export class ServerAlbum {
  id: string = '';
  name: string = '';
  artist: string = '';
  year: number = 0;
  count: number = 0;
  coverPath: string = '';
  source: string = '';
}

export class ServerArtist {
  id: string = '';
  name: string = '';
  count: number = 0;
  coverPath: string = '';
}

/** 歌单条目：保留服务端原始 key 与快照，支持双向写回。 */
export class PlaylistEntry {
  key: string = '';
  platform: string = '';
  songId: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  localPath: string = '';
  picUrl: string = '';
  lyric: string = '';
  durationMs: number = 0;
  qualitys: string[] = [];
  snapshotJson: string = '';
  hasSnapshot: boolean = false;

  get isOnline(): boolean {
    return this.platform.length > 0 && this.localPath.length === 0;
  }
}

export class ServerPlaylist {
  id: string = '';
  name: string = '';
  coverUrl: string = '';
  trackKeys: string[] = [];
  entries: PlaylistEntry[] = [];
  updatedAt: number = 0;
  isFavorites: boolean = false;
  editable: boolean = true;
}

export class ServerUserData {
  favoritesJson: string = '';
  playlistsJson: string = '';
  favoriteCount: number = 0;
  recentCount: number = 0;
  revision: string = '';
}

export enum SyncPhase {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  TRACKS = 'tracks',
  ALBUMS = 'albums',
  ARTISTS = 'artists',
  PLAYLISTS = 'playlists',
  USERDATA = 'userdata',
  WRITING = 'writing',
  DONE = 'done',
  ERROR = 'error'
}

export class SyncState {
  phase: SyncPhase = SyncPhase.IDLE;
  fetched: number = 0;
  total: number = 0;
  error: string = '';
  lastSuccessAt: number = 0;
}

@ObservedV2
export class ServerDownloadTask {
  @Trace id: string = '';
  @Trace name: string = '';
  @Trace singer: string = '';
  @Trace album: string = '';
  @Trace source: string = '';
  @Trace platformId: string = '';
  @Trace quality: string = '';
  @Trace status: string = 'waiting';
  @Trace progress: number = 0;
  @Trace bytesDone: number = 0;
  @Trace bytesTotal: number = 0;
  @Trace speed: number = 0;
  @Trace filePath: string = '';
  @Trace error: string = '';
  @Trace createdAt: number = 0;
  @Trace updatedAt: number = 0;
}

@ObservedV2
export class PodcastFeed {
  @Trace id: string = '';
  @Trace title: string = '';
  @Trace author: string = '';
  @Trace coverUrl: string = '';
  @Trace description: string = '';
  @Trace episodeCount: number = 0;
  @Trace subscribedAt: number = 0;
}

@ObservedV2
export class PodcastEpisode {
  @Trace id: string = '';
  @Trace feedId: string = '';
  @Trace title: string = '';
  @Trace audioUrl: string = '';
  @Trace durationMs: number = 0;
  @Trace publishedAt: number = 0;
  @Trace description: string = '';
}

@ObservedV2
export class SourcePlatform {
  @Trace id: string = '';
  @Trace label: string = '';
  @Trace enabled: boolean = true;
  @Trace level: string = '';
  @Trace okRatio: number = 0;
  @Trace avgMs: number = 0;
  @Trace lastError: string = '';
  @Trace qualitys: string[] = [];
}

@ObservedV2
export class SourceScript {
  @Trace id: string = '';
  @Trace name: string = '';
  @Trace author: string = '';
  @Trace version: string = '';
  @Trace homepage: string = '';
  @Trace active: boolean = true;
  @Trace health: string = '';
  @Trace platforms: SourcePlatform[] = [];
  @Trace lastProbe: string = '';
}

@ObservedV2
export class TagInfo {
  @Trace filePath: string = '';
  @Trace title: string = '';
  @Trace artist: string = '';
  @Trace album: string = '';
  @Trace albumArtist: string = '';
  @Trace year: number = 0;
  @Trace track: number = 0;
  @Trace genre: string = '';
  @Trace hasPicture: boolean = false;
  @Trace hasLyric: boolean = false;
  @Trace lyric: string = '';
  @Trace format: string = '';
  @Trace durationMs: number = 0;
}

@ObservedV2
export class TagCandidate {
  @Trace source: string = '';
  @Trace title: string = '';
  @Trace artist: string = '';
  @Trace album: string = '';
  @Trace coverUrl: string = '';
  @Trace matchScore: number = 0;
  @Trace rawJson: string = '';
}

export class CoverRef {
  key: string = '';
  cachePath: string = '';
  mtime: number = 0;
  updatedAt: number = 0;
}

/** play/url 解析结果。 */
export class PlayResult {
  url: string = '';
  format: string = '';
  local: boolean = false;
  useAuthHeader: boolean = false;
}

/** 统一接口错误：code 取 HttpClient 的错误分类。 */
export class ApiError {
  code: string = '';
  message: string = '';
  status: number = 0;

  constructor(code: string, message: string, status: number = 0) {
    this.code = code;
    this.message = message;
    this.status = status;
  }
}

export enum ApiErrorCode {
  OFFLINE = 'OFFLINE',
  TIMEOUT = 'TIMEOUT',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  NOT_FOUND = 'NOT_FOUND',
  SERVER_ERROR = 'SERVER_ERROR',
  BAD_RESPONSE = 'BAD_RESPONSE',
  UNSUPPORTED = 'UNSUPPORTED',
  INVALID_INPUT = 'INVALID_INPUT',
  UNKNOWN = 'UNKNOWN'
}

export class ApiErrorHelper {
  static message(code: string): string {
    if (code === ApiErrorCode.OFFLINE) {
      return '无法连接服务器，请检查网络与地址';
    }
    if (code === ApiErrorCode.TIMEOUT) {
      return '请求超时，请稍后重试';
    }
    if (code === ApiErrorCode.UNAUTHORIZED) {
      return '登录已过期，请重新登录';
    }
    if (code === ApiErrorCode.FORBIDDEN) {
      return '没有权限执行该操作';
    }
    if (code === ApiErrorCode.NOT_FOUND) {
      return '服务器不支持该操作';
    }
    if (code === ApiErrorCode.SERVER_ERROR) {
      return '服务器返回错误，请稍后重试';
    }
    if (code === ApiErrorCode.BAD_RESPONSE) {
      return '返回内容不是柠檬音乐服务，请检查地址';
    }
    if (code === ApiErrorCode.UNSUPPORTED) {
      return '服务器不支持该操作';
    }
    if (code === ApiErrorCode.INVALID_INPUT) {
      return '输入有误，请检查后重试';
    }
    return '请求失败，请重试';
  }
}
